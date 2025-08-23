#!/bin/bash

# Monitor Repository Sync Script
# Runs periodically on cluster to pull latest changes and avoid conflicts
# Should be added to crontab: */30 * * * * ~/research/mosquito-alert-model-monitor/scripts/cluster_sync.sh

MONITOR_REPO="$HOME/research/mosquito-alert-model-monitor"
LOG_FILE="$MONITOR_REPO/logs/cluster_sync.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

cd "$MONITOR_REPO" || {
    log_message "ERROR: Cannot access monitor repository: $MONITOR_REPO"
    exit 0
}

# Check if it's a git repo
if [ ! -d ".git" ]; then
    log_message "WARNING: Not a git repository - sync skipped"
    exit 0
fi

log_message "INFO: Starting cluster sync from $(hostname)"

# Stash any local changes (mainly status files we've created)
git stash push -u -m "Auto-stash before pull $(date)" 2>/dev/null || true

# Pull latest changes from remote
if git pull origin main 2>&1 | tee -a "$LOG_FILE"; then
    log_message "SUCCESS: Pull completed successfully"
    
    # Reapply our local status files if they were stashed
    if git stash list | grep -q "Auto-stash"; then
        log_message "INFO: Reapplying local changes..."
        git stash pop 2>&1 | tee -a "$LOG_FILE" || {
            log_message "WARNING: Failed to reapply stashed changes"
            # Clear the problematic stash
            git stash drop 2>/dev/null || true
        }
    fi
else
    log_message "WARNING: Pull failed - keeping local state"
fi

# Clean up old log entries (keep last 100 lines)
if [ -f "$LOG_FILE" ]; then
    tail -n 100 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

log_message "INFO: Cluster sync completed"
