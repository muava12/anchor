#!/bin/bash
# Backup Anchor Docker volume dari box-01 ke stb-smd
# Schedule: jalan di box-01 via cron saat box-01 aktif

set -euo pipefail

# Konfigurasi
CONTAINER_NAME="anchor"
VOLUME_NAME="anchor_data"
BACKUP_DIR="/MEDIA/backups/anchor-notes"
REMOTE_HOST="stb-smd"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="anchor_${TIMESTAMP}.tar.gz"

# Pastikan direktori backup ada di stb-smd
ssh "${REMOTE_HOST}" "mkdir -p ${BACKUP_DIR}"

# Backup volume Docker
echo "[$(date)] Starting backup of ${CONTAINER_NAME} volume..."
docker run --rm \
  -v "${VOLUME_NAME}:/data:ro" \
  -v /tmp:/backup \
  alpine:latest \
  tar czf "/backup/${BACKUP_FILE}" -C /data .

# Transfer ke stb-smd
echo "[$(date)] Transferring to ${REMOTE_HOST}:${BACKUP_DIR}/${BACKUP_FILE}..."
scp "/tmp/${BACKUP_FILE}" "${REMOTE_HOST}:${BACKUP_DIR}/${BACKUP_FILE}"

# Cleanup local
rm -f "/tmp/${BACKUP_FILE}"

# Retensi: hapus backup lebih dari 30 hari di stb-smd
ssh "${REMOTE_HOST}" "find ${BACKUP_DIR} -name 'anchor_*.tar.gz' -mtime +30 -delete"

echo "[$(date)] Backup completed: ${BACKUP_FILE}"