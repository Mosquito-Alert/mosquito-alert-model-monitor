#!/bin/bash
#SBATCH --job-name=dashboard_sync
#SBATCH --time=00:05:00
#SBATCH --mem=512M
#SBATCH --cpus-per-task=1
#SBATCH --partition=ceab
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null

# SLURM-compatible dashboard sync script
# This script runs as a SLURM job for proper resource allocation
# Minimal resource usage: 512MB RAM, 1 CPU, 5 minutes max

MONITOR_REPO_PATH="$HOME/research/mosquito-alert-model-monitor"
LOG_FILE="$MONITOR_REPO_PATH/logs/dashboard_sync.log"

# Ensure logs directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SLURM:$SLURM_JOB_ID] $1" >> "$LOG_FILE"
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

log_message "🔄 Starting SLURM dashboard sync job (ID: $SLURM_JOB_ID)..."

# Pull any remote changes first (with timeout)
timeout 30 git pull origin main --rebase 2>/dev/null
if [ $? -eq 0 ]; then
    log_message "✅ Successfully pulled remote changes"
elif [ $? -eq 124 ]; then
    log_message "⚠️  Git pull timed out - continuing with local changes"
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
COMMIT_MSG="SLURM dashboard sync: $(date '+%Y-%m-%d %H:%M:%S') (Job: $SLURM_JOB_ID)"
if timeout 30 git commit -m "$COMMIT_MSG" 2>/dev/null; then
    log_message "✅ Changes committed: $COMMIT_MSG"
    
    # Push changes (with timeout)
    if timeout 60 git push origin main 2>/dev/null; then
        log_message "✅ Dashboard sync complete - deployed to GitHub"
    else
        log_message "⚠️  Push failed or timed out - attempting conflict resolution"
        
        # Try to reset and pull again in case of conflicts
        git reset --soft HEAD~1 2>/dev/null
        if timeout 30 git pull origin main --rebase 2>/dev/null; then
            log_message "✅ Resolved conflicts, retrying commit..."
            if timeout 30 git commit -m "$COMMIT_MSG" 2>/dev/null && timeout 60 git push origin main 2>/dev/null; then
                log_message "✅ Retry successful - dashboard deployed"
            else
                log_message "❌ Retry failed - manual intervention required"
            fi
        else
            log_message "❌ Conflict resolution failed - manual intervention required"
        fi
    fi
else
    log_message "⚠️  Commit failed - possibly no changes or conflicts"
fi

# Clean up old log entries (keep last 200 lines)
tail -200 "$LOG_FILE" > "${LOG_FILE}.tmp" 2>/dev/null && mv "${LOG_FILE}.tmp" "$LOG_FILE" 2>/dev/null

log_message "🎯 SLURM dashboard sync job completed (ID: $SLURM_JOB_ID)"
