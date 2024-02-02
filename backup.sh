#!/bin/bash

backup_dir="backup-$(date +%Y%m%d-%H%M%S)"
backup_archive="$backup_dir.tar.gz"

echo "copying data from data/ to $backup_dir/"

cp -r data $backup_dir || (echo "failed to copy data/ to $backup_dir/" && exit 1)

echo "creating archive $backup_archive"

tar -czf $backup_archive $backup_dir || (echo "failed to create archive $backup_archive" && exit 1)

echo "move archive to .backup"

mv $backup_archive .backup/$backup_archive || (echo "failed to move archive $backup_archive" && exit 1)

echo "removing $backup_dir"

rm -rf $backup_dir || (echo "failed to remove $backup_dir" && exit 1)

