# AFFiNE + Traefik + Let's Encrypt on Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/affine-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/affine-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Contents

- [Why this stack?](#why-this-stack)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Features](#features)
- [Supply chain trust](#supply-chain-trust)
- [Production checklist](#production-checklist)
- [Backups](#backups)
- [Testing](#testing)
- [Security Notes](#security-notes)
- [About the maintainer](#about-the-maintainer)

This repository deploys AFFiNE (the open-source knowledge base: docs + whiteboards + databases) behind Traefik with automatic Let's Encrypt TLS, backed by PostgreSQL and Redis, with a migration job, scheduled backups (database + application data), and companion restore scripts. One `docker compose up` away from a self-hosted workspace at `https://your-domain`.

📙 Full narrative installation guide on the blog: [heyvaldemar.com/install-affine-using-docker-compose/](https://www.heyvaldemar.com/install-affine-using-docker-compose/).

## Why this stack?

| Need | This stack | Manual install | AFFiNE's own compose | Other examples |
|------|-----------|----------------|----------------------|----------------|
| Ready to deploy in <10 min | ✅ | ❌ | ✅ | Often |
| TLS via Let's Encrypt, auto-renewed | ✅ Traefik ACME built-in | Manual | ❌ bring your own | Rare |
| Postgres + Redis wired with healthchecks | ✅ | Manual | ✅ | Varies |
| Migration job ordered before the server | ✅ | Manual | ✅ | Rare |
| Scheduled DB + data backups + pruning | ✅ | Manual cron | ❌ | Rare |
| Image pinned by `sha256` digest | ✅ `stable@digest` | N/A | ❌ floating `stable` | Rare |
| Weekly pin-freshness check in CI | ✅ | N/A | ❌ | Rare |
| CI-verified deployment on every push | ✅ | N/A | ❌ | Rare |
| Credentials via env (never committed) | ✅ | N/A | ✅ | Often committed plaintext |

Five moving parts (Traefik + AFFiNE + migration job + Postgres + Redis, plus the backups sidecar). No Kubernetes prerequisites, no manual certificate management.

## Prerequisites

- **A Linux server** with a public IP. Tested on Ubuntu 22.04 LTS+ and Debian 12+.
- **Docker Engine 24+ and Docker Compose 2.20+.**
- **A domain you control,** with two `A` records pointing at your server's public IP: one for AFFiNE, one for the Traefik dashboard. DNS must propagate before deploy.
- **Ports 80 and 443 open** on the server's firewall.
- **~1.5 GB free RAM** for the running stack, plus disk for workspace data and backups.

## Getting started

```bash
# 1. Clone
git clone https://github.com/heyvaldemar/affine-traefik-letsencrypt-docker-compose
cd affine-traefik-letsencrypt-docker-compose

# 2. Create the two Docker networks the stack expects
docker network create traefik-network
docker network create affine-network

# 3. Copy the environment template and fill in required values
cp .env.example .env
$EDITOR .env
# ^ Required: AFFINE_DB_PASSWORD, AFFINE_REDIS_PASSWORD, AFFINE_HOSTNAME,
#   AFFINE_URL, TRAEFIK_HOSTNAME, TRAEFIK_ACME_EMAIL, TRAEFIK_BASIC_AUTH.

# 4. Deploy
docker compose -f affine-traefik-letsencrypt-docker-compose.yml -p affine up -d
```

The migration job prepares the database, then the server starts. Within a couple of minutes `https://${AFFINE_HOSTNAME}` serves AFFiNE with a fresh Let's Encrypt certificate. The first registered account becomes the workspace owner; create yours before sharing the URL.

### What success looks like

```bash
# All services healthy:
docker compose -f affine-traefik-letsencrypt-docker-compose.yml -p affine ps

# Front page answers:
curl -fskL -o /dev/null -w "%{http_code}\n" "https://${AFFINE_HOSTNAME}/"
# Expected: 200

# Traefik issued a certificate:
docker compose -p affine logs traefik | grep -i "adding certificate"

# First backup lands after BACKUP_INIT_SLEEP (default 30m):
docker compose -p affine logs backups | tail -3
```

### Common first-deploy issues

- **Cert issuance fails.** DNS hasn't propagated or port 80 isn't reachable from the internet.
- **`docker compose up` fails with `set in .env`.** A required variable is empty; the error names it.
- **`network affine-network not found`.** Step 2 was skipped.
- **Server restarts on first boot.** It waits for the migration job; check `docker compose -p affine logs affine_migration` if it persists.

### Apply `.env` or compose-file changes

```bash
docker compose -f affine-traefik-letsencrypt-docker-compose.yml -p affine up -d --force-recreate
```

## Features

- **AFFiNE stable**: docs, edgeless whiteboards, databases; local-first sync with the server.
- **PostgreSQL + Redis** with healthchecks and start-order dependencies; a dedicated migration job runs schema upgrades before the server starts.
- **Traefik v3** with automatic HTTP→HTTPS redirect and Let's Encrypt TLS-ALPN certificate issuance.
- **Basic-auth protected Traefik dashboard** on a separate hostname.
- **Scheduled backups** of the database (`pg_dump | gzip`) and workspace data (`tar.gz`) with retention pruning, plus restore scripts for both.
- **Optional SMTP** for invites/notifications, empty by default.
- **Credentials required at deploy time**: compose fails fast if `.env` is incomplete.

## Supply chain trust

This repository is a deployment template, not a custom Docker image. It orchestrates four upstream images:

- [`traefik`](https://hub.docker.com/_/traefik): reverse proxy, Docker Hub official image
- [`ghcr.io/toeverything/affine`](https://github.com/toeverything/AFFiNE/pkgs/container/affine): AFFiNE upstream
- [`postgres`](https://hub.docker.com/_/postgres) / [`redis`](https://hub.docker.com/_/redis): Docker Hub official images

All four are pinned to `tag@sha256:<digest>` as interpolation defaults in the compose file's `x-images` block. AFFiNE publishes its releases by moving the `stable` tag, so the pin is `stable@digest`, reproducible today, and the weekly digest-drift check fires whenever upstream releases, prompting a reviewed bump. `git pull` alone delivers the tested combination; an `*_IMAGE_TAG` variable in `.env` overrides deliberately.

Two override levels exist per image. `<PREFIX>_IMAGE_VERSION` in `.env` swaps only the version of that image (Compose then pulls the tag, without a digest) and leaves every other pin as tested; `<PREFIX>_IMAGE_TAG` replaces the whole reference, digest included. The variable names are listed in `.env.example`. Nested defaults need Docker Compose v2.5 or newer (2022); v2.0 to v2.4 leave the inner `${...}` unexpanded and `docker compose up` fails with an invalid reference instead of deploying something unexpected.

CI runs on every push, pull request, and every day at 06:00 UTC. GitHub Actions are pinned by commit SHA; Dependabot keeps those fresh.

## Production checklist

- [ ] **Register the owner account immediately after deploy**: first sign-up wins.
- [ ] **Strong secrets.** `AFFINE_DB_PASSWORD` and `AFFINE_REDIS_PASSWORD` at 24+ random characters; regenerate the Traefik dashboard BCrypt hash per deployment.
- [ ] **Host-mount the backup volumes** for disaster recovery.
- [ ] **Verify Let's Encrypt cert issuance** in the Traefik logs on first start.
- [ ] **Back up before upgrades**: the migration job upgrades the schema forward; the way back is a restore.
- [ ] **Know the restore procedure.** Run both restore scripts against a test environment before you need them.

## Backups

The `backups` container performs a dump → archive → prune → sleep loop: `pg_dump | gzip` of the AFFiNE database, `tar.gz` of the workspace storage, pruning by retention windows, then sleeping `BACKUP_INTERVAL` (default 24h).

Each cycle logs `Database backup OK: <file> (<bytes> bytes)` or `Database backup FAILED` (the same for the data archive where there is one). A failed dump is kept as `<file>.failed` for diagnosis and never overwrites a good backup. Grep the log for `FAILED` from your monitoring.

**Verify backups are running:**

```bash
docker compose -p affine logs backups | tail -5
```

**Restore** with the interactive scripts (`chmod +x *.sh` once): `./affine-restore-database.sh`, then `./affine-restore-application-data.sh`.

## Resource limits

Every service carries memory and CPU limits plus reservations as compose-level defaults: the same values CI boots the stack under. Override any of them in `.env` (the knobs and their defaults are listed in `.env.example`, e.g. `TRAEFIK_MEMORY_LIMIT=512m`) and the override survives every `git pull`. If a service is OOM-killed under real load, `docker inspect <container> --format '{{.State.OOMKilled}}'` says so; raise its `_MEMORY_LIMIT` and recreate.

## Container hardening

Every service runs with `security_opt: no-new-privileges:true`, so a process cannot gain privileges through setuid binaries even if it escapes its initial capability set. Infrastructure containers (the reverse proxy, databases, caches, backups) run with `cap_drop: [ALL]` and add back only what their entrypoints need: `NET_BIND_SERVICE` for Traefik to bind :80/:443, `CHOWN`/`SETUID`/`SETGID` (and friends) for database images to own their data directory and drop to their service user. Application containers keep the default capability set on purpose: upstream images assume it, and a wrong guess there is a boot loop in production rather than a hardening win. CI boots the stack under exactly these settings on every push, so what ships is what was tested.

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/affine-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every day at 06:00 UTC:

1. **Lint**: shellcheck on both restore scripts, actionlint on the workflow.
2. **Trivy scans** of all four pinned images (CRITICAL/HIGH, SARIF to the Security tab).
3. **Pin freshness** (daily/manual): digest drift (the release tracker for the `stable` pin) plus Traefik release lag.
4. **Deploy-and-test**: boots the full stack with ephemeral credentials, waits through the migration job, and requires the front page to answer 200 through Traefik.

A green run is the authoritative proof that the template deploys end-to-end and that its backups restore.

### Backup and restore, proven

`tests/e2e-backup-restore.sh` runs against the live stack and is what CI executes after the HTTPS smoke. The scenario that matters most is the restore roundtrip: insert a marker row, restore the earliest backup, assert the marker is gone. A backup that cannot be restored fails the build. Run it yourself against a running deployment with short intervals in `.env` (`BACKUP_INIT_SLEEP=15s`, `BACKUP_INTERVAL=60s`):

```bash
chmod +x tests/e2e-backup-restore.sh
./tests/e2e-backup-restore.sh
```

It stops the database container briefly to prove failure detection. Run it on a staging copy, not on production.

## Security notes

- Credentials are read from `.env` at deploy time; `.env` is gitignored and compose fails fast on missing required variables.
- **Pre-rotation advisory.** Releases before v1.0.0 (2026-08-31) shipped a tracked `.env` with generated-looking database and Redis passwords. Rotate them if your deployment reused them.
- Postgres and Redis listen only on the internal network.
- Upstream image digests are pinned; the daily freshness job flags drift loudly.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** · Docker Captain · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
