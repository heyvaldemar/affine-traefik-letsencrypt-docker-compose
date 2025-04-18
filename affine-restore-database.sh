#!/bin/bash

# # affine-restore-database.sh Description
# This script facilitates the restoration of a database backup.
# 1. **Identify Containers**: It first identifies the service and backups containers by name, finding the appropriate container IDs.
# 2. **List Backups**: Displays all available database backups located at the specified backup path.
# 3. **Select Backup**: Prompts the user to copy and paste the desired backup name from the list to restore the database.
# 4. **Stop Service**: Temporarily stops the service to ensure data consistency during restoration.
# 5. **Restore Database**: Executes a sequence of commands to drop the current database, create a new one, and restore it from the selected compressed backup file.
# 6. **Start Service**: Restarts the service after the restoration is completed.
# To make the `affine-restore-database.shh` script executable, run the following command:
# `chmod +x affine-restore-database.sh`
# Usage of this script ensures a controlled and guided process to restore the database from an existing backup.

AFFINE_CONTAINER=$(docker ps -aqf "name=affine-affine")
AFFINE_BACKUPS_CONTAINER=$(docker ps -aqf "name=affine-backups")
AFFINE_DB_NAME="affinedb"
AFFINE_DB_USER="affinedbuser"
POSTGRES_PASSWORD=$(docker exec $AFFINE_BACKUPS_CONTAINER printenv PGPASSWORD)
BACKUP_PATH="/srv/affine-postgres/backups/"

echo "--> All available database backups:"

for entry in $(docker container exec "$AFFINE_BACKUPS_CONTAINER" sh -c "ls $BACKUP_PATH")
do
  echo "$entry"
done

echo "--> Copy and paste the backup name from the list above to restore database and press [ENTER]
--> Example: affine-postgres-backup-YYYY-MM-DD_hh-mm.gz"
echo -n "--> "

read SELECTED_DATABASE_BACKUP

echo "--> $SELECTED_DATABASE_BACKUP was selected"

echo "--> Stopping service..."
docker stop "$AFFINE_CONTAINER"

echo "--> Restoring database..."
docker exec "$AFFINE_BACKUPS_CONTAINER" sh -c "dropdb -h postgres -p 5432 $AFFINE_DB_NAME -U $AFFINE_DB_USER \
&& createdb -h postgres -p 5432 $AFFINE_DB_NAME -U $AFFINE_DB_USER \
&& gunzip -c ${BACKUP_PATH}${SELECTED_DATABASE_BACKUP} | psql -h postgres -p 5432 $AFFINE_DB_NAME -U $AFFINE_DB_USER"
echo "--> Database recovery completed..."

echo "--> Starting service..."
docker start "$AFFINE_CONTAINER"
