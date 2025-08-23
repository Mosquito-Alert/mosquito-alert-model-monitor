#!/bin/bash

# Mosquito Alert Model Monitor - Job Status Update Script
# This script should be called by your cronjobs to update status information

JOB_NAME="$1"
STATUS="$2"
DURATION="$3"
PROGRESS="$4"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <job_name> <status> [duration] [progress]"
    echo "Status options: running, completed, failed, pending"
    exit 1
fi

# Set paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
STATUS_DIR="$PROJECT_DIR/data/status"
HISTORY_DIR="$PROJECT_DIR/data/history"

# Create directories if they don't exist
mkdir -p "$STATUS_DIR"
mkdir -p "$HISTORY_DIR"

# Generate timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE=$(date +"%Y-%m-%d")

# Create status file
STATUS_FILE="$STATUS_DIR/${JOB_NAME}.json"

# Get current CPU and memory usage
CPU_USAGE=$(ps aux | awk '{cpu += $3} END {print cpu}' 2>/dev/null || echo "0")
MEMORY_USAGE=$(ps aux | awk '{mem += $4} END {print mem*1024/100}' 2>/dev/null || echo "0")

# Build JSON status
cat > "$STATUS_FILE" << EOF
{
  "job_name": "$JOB_NAME",
  "status": "$STATUS",
  "last_updated": "$TIMESTAMP",
  "duration": ${DURATION:-"null"},
  "progress": ${PROGRESS:-"null"},
  "cpu_usage": $CPU_USAGE,
  "memory_usage": $MEMORY_USAGE,
  "next_scheduled_run": "$(date -d '+1 day' -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

# Add to daily history
HISTORY_FILE="$HISTORY_DIR/${DATE}.json"

# Create or update history file
if [ ! -f "$HISTORY_FILE" ]; then
    echo "[]" > "$HISTORY_FILE"
fi

# Add current status to history (simplified - in production you'd want proper JSON merging)
echo "Status updated for $JOB_NAME: $STATUS"

# If this script is part of a git repository, commit and push changes
cd "$PROJECT_DIR"
if [ -d ".git" ]; then
    git add data/status data/history
    git commit -m "Update status for $JOB_NAME: $STATUS" || true
    
    # Only push if we're not in a CI environment
    if [ -z "$CI" ]; then
        git push origin main || echo "Warning: Could not push to remote repository"
    fi
fi

echo "Status update completed for $JOB_NAME"
