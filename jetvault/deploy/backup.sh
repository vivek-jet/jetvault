#!/bin/sh
# Nightly JetVault backup: consistent SQLite snapshot + keys, attachments and sends.
# Installed as a cron job by bootstrap.sh. Keeps the last 14 archives in /opt/jetvault/backups.
# Lightsail automatic snapshots also capture these archives off-box.
set -eu

ROOT=/opt/jetvault
DEST="${ROOT}/backups"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

mkdir -p "${DEST}"

# Online, consistent copy of the database (safe while JetVault is running)
docker run --rm -v "${ROOT}/data:/data" -v "${WORK}:/backup" docker.io/keinos/sqlite3:latest \
    sqlite3 /data/db.sqlite3 ".backup '/backup/db.sqlite3'"

tar -C "${ROOT}/data" \
    --exclude=./db.sqlite3 --exclude=./db.sqlite3-wal --exclude=./db.sqlite3-shm \
    --exclude=./icon_cache --exclude=./tmp \
    -czf "${WORK}/files.tar.gz" .
tar -C "${WORK}" -czf "${DEST}/jetvault-${STAMP}.tar.gz" db.sqlite3 files.tar.gz
chmod 600 "${DEST}/jetvault-${STAMP}.tar.gz"

ls -1t "${DEST}"/jetvault-*.tar.gz | tail -n +15 | xargs -r rm -f
echo "backup written: ${DEST}/jetvault-${STAMP}.tar.gz"
