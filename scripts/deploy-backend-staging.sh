#!/bin/bash
set -euo pipefail

SOURCE_DIR="/home/ubuntu/devops-backend"
PRIVATE_HOST="ubuntu@10.0.11.117"
STAGING_DIR="/home/ubuntu/devops-staging"

echo "Starting backend deployment preparation..."

cd "$SOURCE_DIR"

# Verify source files
for file in index.js package.json package-lock.json; do
  test -f "$file"
done

# Prepare private staging directory
ssh "$PRIVATE_HOST" "mkdir -p '$STAGING_DIR'"

# Transfer backend source files only
rsync -av \
  --include='/index.js' \
  --include='/package.json' \
  --include='/package-lock.json' \
  --exclude='*' \
  "$SOURCE_DIR/" "$PRIVATE_HOST:$STAGING_DIR/"

# Verify transferred files
ssh "$PRIVATE_HOST" \
  "cd '$STAGING_DIR' && node --check index.js && test -f package.json && test -f package-lock.json"

echo "Backend staging completed successfully."
echo "Production service was not modified."
