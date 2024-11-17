#!/bin/bash

BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
BACKUP_SQL_FILE="ao-analytics.sql"
BACKUP_ARCHIVE="$BACKUP_DIR.tar.gz"

docker exec ao-analytics-db pg_dump \
    -U $POSTGRES_USER \
    -d $POSTGRES_DB \
    -Fp -v \
    -f $BACKUP_SQL_FILE || (echo "failed to dump ao-analytics" && exit 1)

mkdir -p $BACKUP_DIR || (echo "failed to create $BACKUP_DIR" && exit 1)

docker cp ao-analytics-db:$BACKUP_SQL_FILE $BACKUP_DIR/$BACKUP_SQL_FILE || (echo "failed to copy $BACKUP_SQL_FILE" && exit 1)
docker exec ao-analytics-db rm $BACKUP_SQL_FILE || (echo "failed to remove $BACKUP_SQL_FILE" && exit 1)

tar -czf $BACKUP_ARCHIVE $BACKUP_DIR || (echo "failed to create archive $BACKUP_ARCHIVE" && exit 1)
rm -rf $BACKUP_DIR || (echo "failed to remove $BACKUP_DIR" && exit 1)
