# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.0.0] - 2026-08-31

First semver release. Brings this template to the fleet standard established
in [keycloak-traefik-letsencrypt-docker-compose](https://github.com/heyvaldemar/keycloak-traefik-letsencrypt-docker-compose)
v1.2.0.

### Security

- **AFFiNE pinned by digest** (`stable@sha256:…` — the floating `stable`
  tag alone made deployments unreproducible; the weekly digest-drift check
  now tracks upstream releases). **Traefik bumped 3.2 → 3.7** (3.2's
  Docker client cannot talk to Docker Engine 29). **Redis 7.2 → 7.4**,
  `postgres:16` digest-pinned.
- **Credentials untracked from git.** The tracked `.env` carried
  generated-looking database/Redis passwords published on GitHub — rotate
  them if reused. `.env` is now gitignored; compose fails fast on unset
  values. SMTP credentials are now optional/empty by default.

### Changed

- **Image pins live in the compose file as interpolation defaults**
  (`x-images` block); `.env` carries only secrets, hostnames, and
  deliberate overrides. Backup-loop variables escaped (`$$VAR`).
- README rebuilt to the fleet evaluator-first structure.

### Added

- **Deployment Verification workflow**: shellcheck + actionlint; Trivy
  scans of all four pinned images; weekly `check-pin-freshness` (digest
  drift — the version tracker for the `stable` pin — plus Traefik release
  lag); deploy-and-test that boots the full stack with ephemeral
  credentials and requires the front page to answer 200 through Traefik.

### Fixed

- Shellcheck findings in both restore scripts.

[Unreleased]: https://github.com/heyvaldemar/affine-traefik-letsencrypt-docker-compose/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/heyvaldemar/affine-traefik-letsencrypt-docker-compose/releases/tag/v1.0.0
