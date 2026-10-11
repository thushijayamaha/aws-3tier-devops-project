#!/bin/bash
set -euo pipefail

SOURCE_DIR="/home/ubuntu/devops-backend"
STAGING_DIR="/home/ubuntu/devops-staging"
PRODUCTION_DIR="/home/ubuntu/devops-backend"
BACKUP_DIR="/home/ubuntu/deployment-backups"

SSH_KEY="/home/ubuntu/.ssh/devops-deploy"
PRIVATE_HOST="ubuntu@10.0.11.117"

SSH_OPTS=(
  -i "$SSH_KEY"
  -o IdentitiesOnly=yes
  -o BatchMode=yes
  -o ConnectTimeout=10
)

echo "Starting production deployment..."

# 1. Validate source
cd "$SOURCE_DIR"
node --check index.js

# 2. Transfer files to staging
rsync -av \
  -e "ssh -i $SSH_KEY -o IdentitiesOnly=yes -o BatchMode=yes" \
  --include='/index.js' \
  --include='/package.json' \
  --include='/package-lock.json' \
  --exclude='*' \
  "$SOURCE_DIR/" "$PRIVATE_HOST:$STAGING_DIR/"

# 3. Deploy on Private EC2
ssh "${SSH_OPTS[@]}" "$PRIVATE_HOST" \
  "STAGING_DIR='$STAGING_DIR' PRODUCTION_DIR='$PRODUCTION_DIR' BACKUP_DIR='$BACKUP_DIR' bash -s" <<'REMOTE'
set -euo pipefail

cd "$STAGING_DIR"
node --check index.js

# Stop if dependencies changed
cmp -s package-lock.json "$PRODUCTION_DIR/package-lock.json" || {
  echo "Dependency lockfile changed. Deployment stopped."
  exit 1
}

cmp -s package.json "$PRODUCTION_DIR/package.json" || {
  echo "Package configuration changed. Deployment stopped."
  exit 1
}

# Backup current production source
mkdir -p "$BACKUP_DIR"
BACKUP="$BACKUP_DIR/backend-$(date +%Y%m%d-%H%M%S)-$$.tar.gz"

tar -czf "$BACKUP" \
  -C "$PRODUCTION_DIR" \
  index.js package.json package-lock.json

echo "Backup: $BACKUP"

# Update backend source
cp "$STAGING_DIR/index.js" "$PRODUCTION_DIR/index.js"

# Restart and verify
if sudo systemctl restart devops-backend; then
  for attempt in 1 2 3 4 5; do
    if curl -fsS --max-time 5 \
      http://127.0.0.1:3000/api/health >/dev/null; then
      echo "DEPLOYMENT_SUCCESS"
      exit 0
    fi
    sleep 2
  done
fi

echo "Health check failed. Rolling back..."

tar -xzf "$BACKUP" -C "$PRODUCTION_DIR"
sudo systemctl restart devops-backend

curl -fsS --max-time 5 \
  http://127.0.0.1:3000/api/health >/dev/null || {
  echo "ROLLBACK_HEALTH_CHECK_FAILED"
  exit 1
}

echo "ROLLBACK_COMPLETED"
exit 1
REMOTE
