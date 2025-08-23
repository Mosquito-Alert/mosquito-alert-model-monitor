#!/bin/bash

# Cron-friendly dashboard sync script
# Run this every 5-15 minutes to sync dashboard without job interference
# Example crontab: */10 * * * * /path/to/sync_dashboard_cron.sh

MONITOR_REPO_PATH="$HOME/research/mosquito-alert-model-monitor"
LOG_FILE="$MONITOR_REPO_PATH/logs/dashboard_sync.log"

# Ensure logs directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Change to monitor repo
cd "$MONITOR_REPO_PATH" 2>/dev/null || {
    log_message "❌ Cannot access monitor repo at $MONITOR_REPO_PATH"
    exit 1
}

# Check if it's a git repo
if [ ! -d ".git" ]; then
    log_message "❌ Monitor repo is not a git repository"
    exit 1
fi

log_message "🔄 Starting scheduled dashboard sync..."

# Pull any remote changes first
if git pull origin main --rebase 2>/dev/null; then
    log_message "✅ Successfully pulled remote changes"
else
    log_message "⚠️  Failed to pull remote changes - may need manual intervention"
fi

# Check if there are any local changes to commit
if git diff --quiet && git diff --staged --quiet; then
    log_message "ℹ️  No changes to sync"
    exit 0
fi

# Add all data files
git add data/ 2>/dev/null

# Check if there are staged changes
if git diff --staged --quiet; then
    log_message "ℹ️  No staged changes after git add"
    exit 0
fi

# Commit changes
COMMIT_MSG="Scheduled dashboard sync: $(date '+%Y-%m-%d %H:%M:%S')"
if git commit -m "$COMMIT_MSG" 2>/dev/null; then
    log_message "✅ Changes committed: $COMMIT_MSG"
    
    # Push changes
    if git push origin main 2>/dev/null; then
        log_message "✅ Dashboard sync complete - deployed to GitHub"
    else
        log_message "⚠️  Push failed - may need manual intervention"
        
        # Try to reset and pull again in case of conflicts
        git reset --soft HEAD~1 2>/dev/null
        if git pull origin main --rebase 2>/dev/null; then
            log_message "✅ Resolved conflicts, retrying commit..."
            if git commit -m "$COMMIT_MSG" 2>/dev/null && git push origin main 2>/dev/null; then
                log_message "✅ Retry successful - dashboard deployed"
            else
                log_message "❌ Retry failed - manual intervention required"
            fi
        fi
    fi
else
    log_message "⚠️  Commit failed - possibly no changes or conflicts"
fi

# Clean up old log entries (keep last 100 lines)
tail -100 "$LOG_FILE" > "${LOG_FILE}.tmp" 2>/dev/null && mv "${LOG_FILE}.tmp" "$LOG_FILE" 2>/dev/null

log_message "🎯 Dashboard sync job completed"
