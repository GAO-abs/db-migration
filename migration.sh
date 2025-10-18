#!/bin/bash

# ========================================
# PostgreSQL Database Migration Script (database_dump)
# AWS → Huawei Cloud
# ========================================

# Exit immediately if any command fails
set -e

# ====== CONFIGURATION ======
SRC_HOST="your-aws-endpoint.amazonaws.com"
SRC_PORT=5432
SRC_USER="postgres"
SRC_DB="src-db-name"

DST_HOST="your-huawei-db-host"
DST_PORT=5432
DST_USER="postgres"
DST_DB="dest-db-name"

BACKUP_FILE="${SRC_DB}_backup_$(TZ='Africa/Lagos' date +%F_%H%M%S).dump"
LOCAL_BACKUP_DIR="/tmp"
LOG_FILE="$LOCAL_BACKUP_DIR/migration_$(TZ='Africa/Lagos' date +%F_%H%M%S).log"

# ====== LOGGING FUNCTION ======
log() {
  echo "$(TZ='Africa/Lagos' date '+%Y-%m-%d %H:%M:%S') | $1" | tee -a "$LOG_FILE"
}

# ====== ERROR HANDLER ======
error_exit() {
  log "❌ ERROR: $1"
  log "Migration failed. Check log: $LOG_FILE"
  exit 1
}

# ====== STEP 0: Prompt for Passwords ======
echo "🔐 Enter AWS PostgreSQL password:"
read -s SRC_PASSWORD
echo "🔐 Enter Huawei PostgreSQL password:"
read -s DST_PASSWORD
echo

log "🚀 Starting database migration from AWS → Huawei Cloud"

# ====== STEP 1: Perform pg_dump from AWS ======
log "📦 Starting PostgreSQL backup from AWS (within VPC, no SSL needed)..."
if ! PGPASSWORD="$SRC_PASSWORD" pg_dump \
  -h "$SRC_HOST" \
  -p "$SRC_PORT" \
  -U "$SRC_USER" \
  -d "$SRC_DB" \
  --format=custom \
  --blobs \
  --verbose \
  -f "$LOCAL_BACKUP_DIR/$BACKUP_FILE" >>"$LOG_FILE" 2>&1; then
  error_exit "pg_dump failed."
fi
log "✅ Backup completed: $LOCAL_BACKUP_DIR/$BACKUP_FILE"

# ====== STEP 2: Restore dump into Huawei Cloud DB ======
log "🔄 Restoring backup into Huawei Cloud PostgreSQL (encrypted in transit)..."
set +e
PGPASSWORD="$DST_PASSWORD" pg_restore \
  --dbname="postgresql://$DST_USER:$DST_PASSWORD@$DST_HOST:$DST_PORT/$DST_DB?sslmode=require" \
  --jobs=4 \
  --verbose \
  --no-owner --no-privileges \
  "$LOCAL_BACKUP_DIR/$BACKUP_FILE" >>"$LOG_FILE" 2>&1
RESTORE_STATUS=$?
set -e

if [ $RESTORE_STATUS -ne 0 ]; then
  error_exit "pg_restore encountered some errors."
fi

log "🎉 Migration completed successfully!"
log "🗂️ Log file saved at: $LOG_FILE"
