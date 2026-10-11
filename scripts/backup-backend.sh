#!/bin/bash
set -euo pipefail

BACKEND_DIR="/home/ubuntu/devops-backend"
BACKUP_DIR="/home/ubuntu/deployment-backups"

mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/backend-$(date +%Y%m%d-%H%M%S).tar.gz"

tar -czf "$BACKUP_FILE" \
  -C "$BACKEND_DIR" \
  --exclude='.env' \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='*.backup' \
  .

echo "Backup created: $BACKUP_FILE"
