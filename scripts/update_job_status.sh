#!/bin/bash

# Robust status update script that NEVER fails critical jobs
# This is a drop-in replacement for update_job_status_and_push.sh
# It prioritizes job completion over dashboard updates

JOB_NAME="${1:-unknown}"
STATUS="${2:-unknown}"
DURATION="${3:-0}"
PROGRESS="${4:-0}"
LOG_MESSAGE="${5:-Job status update}"

# Configuration
MONITOR_REPO_PATH="$HOME/research/mosquito-alert-model-monitor"
STATUS_DIR="$MONITOR_REPO_PATH/data/status"

echo "📊 Updating job status: $JOB_NAME -> $STATUS ($PROGRESS%)"

# Always try to update status files, but don't fail if we can't
update_status_files() {
    # Check if monitor repository exists
    if [ ! -d "$MONITOR_REPO_PATH" ]; then
        echo "⚠️  Monitor repository not found - skipping dashboard update"
        return 0
    fi

    # Ensure status directory exists
    mkdir -p "$STATUS_DIR" 2>/dev/null || {
        echo "⚠️  Cannot create status directory - skipping dashboard update"
        return 0
    }

    # Check if status directory is writable
    if [ ! -w "$STATUS_DIR" ]; then
        echo "⚠️  Cannot write to status directory - skipping dashboard update"
        return 0
    fi

    # Get current timestamp
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Calculate next scheduled run
    local next_run
    if date -d "tomorrow" >/dev/null 2>&1; then
        next_run=$(date -u -d "tomorrow 02:30" +"%Y-%m-%dT%H:%M:%SZ")
    else
        next_run=$(date -u -v+1d +"%Y-%m-%dT02:30:00Z")
    fi

    # Get system resource usage (safe fallbacks)
    local cpu_usage=$(ps -o %cpu= -p $$ 2>/dev/null | tr -d ' ' || echo "0")
    local memory_usage=$(ps -o rss= -p $$ 2>/dev/null | awk '{print $1/1024}' || echo "0")

    # Create JSON status file
    cat > "$STATUS_DIR/${JOB_NAME}.json" << 'JSONEOF'
{
  "job_name": "JOB_NAME_PLACEHOLDER",
  "status": "STATUS_PLACEHOLDER",
  "last_updated": "TIMESTAMP_PLACEHOLDER",
  "start_time": "TIMESTAMP_PLACEHOLDER",
  "duration": DURATION_PLACEHOLDER,
  "progress": PROGRESS_PLACEHOLDER,
  "cpu_usage": CPU_USAGE_PLACEHOLDER,
  "memory_usage": MEMORY_USAGE_PLACEHOLDER,
  "next_scheduled_run": "NEXT_RUN_PLACEHOLDER",
  "config": {
    "project_type": "automated_pipeline",
    "schedule": "Automated",
    "cluster": "SLURM cluster"
  },
  "log_entries": [
    "LOG_MESSAGE_PLACEHOLDER"
  ]
}
JSONEOF

    # Replace placeholders
    sed -i.bak \
        -e "s/JOB_NAME_PLACEHOLDER/$JOB_NAME/g" \
        -e "s/STATUS_PLACEHOLDER/$STATUS/g" \
        -e "s/TIMESTAMP_PLACEHOLDER/$timestamp/g" \
        -e "s/DURATION_PLACEHOLDER/${DURATION:-0}/g" \
        -e "s/PROGRESS_PLACEHOLDER/${PROGRESS:-0}/g" \
        -e "s/CPU_USAGE_PLACEHOLDER/${cpu_usage:-0}/g" \
        -e "s/MEMORY_USAGE_PLACEHOLDER/${memory_usage:-0}/g" \
        -e "s/NEXT_RUN_PLACEHOLDER/$next_run/g" \
        -e "s/LOG_MESSAGE_PLACEHOLDER/$LOG_MESSAGE/g" \
        "$STATUS_DIR/${JOB_NAME}.json" 2>/dev/null || {
        echo "⚠️  Failed to write status file - continuing anyway"
        return 0
    }

    # Clean up backup file
    rm -f "$STATUS_DIR/${JOB_NAME}.json.bak" 2>/dev/null

    echo "✅ Status file updated: $STATUS_DIR/${JOB_NAME}.json"
    return 0
}

# Update status files (this should always work)
update_status_files

# Try git operations using the locked git sync (but don't fail if it doesn't work)
if [ -f "$MONITOR_REPO_PATH/scripts/locked_git_sync.sh" ]; then
    echo "🔄 Attempting dashboard sync with git lock..."
    "$MONITOR_REPO_PATH/scripts/locked_git_sync.sh" "$MONITOR_REPO_PATH" "$JOB_NAME ($STATUS)" || {
        echo "⚠️  Dashboard sync failed but continuing job execution"
    }
else
    echo "⚠️  Locked git sync script not found - status updated locally only"
fi

echo "📊 Status update complete: $JOB_NAME -> $STATUS"

# ALWAYS exit successfully to ensure calling jobs continue
exit 0
