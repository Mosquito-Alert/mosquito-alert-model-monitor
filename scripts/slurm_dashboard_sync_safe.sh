#!/bin/bash
#SBATCH --job-name=dashboard_sync
#SBATCH --time=00:05:00
#SBATCH --mem=512M
#SBATCH --cpus-per-task=1
#SBATCH --partition=ceab
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null

# SLURM-compatible dashboard sync script - RACE CONDITION SAFE
# This script safely syncs without interfering with concurrent project updates
# Minimal resource usage: 512MB RAM, 1 CPU, 5 minutes max

MONITOR_REPO_PATH="$HOME/research/mosquito-alert-model-monitor"
LOG_FILE="$MONITOR_REPO_PATH/logs/dashboard_sync.log"
LOCK_FILE="$MONITOR_REPO_PATH/.git/dashboard_sync.lock"

# Ensure logs directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SLURM:$SLURM_JOB_ID] $1" >> "$LOG_FILE"
    echo "$1"
}

# Function to acquire lock with timeout
acquire_lock() {
    local timeout=30
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            log_message "🔒 Acquired dashboard sync lock"
            return 0
        fi
        
        # Check if existing lock is stale (>5 minutes old)
        if [ -f "$LOCK_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0))) -gt 300 ]; then
            log_message "🔧 Removing stale lock file"
            rm -f "$LOCK_FILE" 2>/dev/null
        else
            log_message "⏳ Waiting for dashboard sync lock (attempt $((elapsed/2 + 1)))"
            sleep 2
            elapsed=$((elapsed + 2))
        fi
    done
    
    log_message "⚠️  Could not acquire lock within ${timeout}s - another sync may be running"
    return 1
}

# Function to release lock
release_lock() {
    rm -f "$LOCK_FILE" 2>/dev/null
    log_message "🔓 Released dashboard sync lock"
}

# Set up cleanup on exit
cleanup() {
    release_lock
}
trap cleanup EXIT INT TERM

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

# Acquire lock to prevent race conditions
if ! acquire_lock; then
    log_message "❌ Could not acquire sync lock - exiting to prevent conflicts"
    exit 1
fi

log_message "🔄 Starting SLURM dashboard sync job (ID: $SLURM_JOB_ID)..."

# Check git status to see what we're dealing with
git_status=$(git status --porcelain 2>/dev/null)
if [ -z "$git_status" ]; then
    log_message "ℹ️  No local changes to sync"
    exit 0
fi

# Pull any remote changes first - SAFELY
log_message "📥 Checking for remote updates..."
if timeout 30 git fetch origin main 2>/dev/null; then
    # Check if remote has changes
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/main 2>/dev/null)
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        log_message "🔄 Remote has updates - attempting safe merge"
        
        # Only merge if we can do it safely (no conflicts)
        if timeout 30 git merge --no-edit origin/main 2>/dev/null; then
            log_message "✅ Successfully merged remote changes"
        else
            log_message "⚠️  Merge conflicts detected - using failsafe approach"
            
            # Reset to our local state and then re-add only our specific changes
            git merge --abort 2>/dev/null || true
            
            # Get list of files changed locally
            local_changes=$(git diff --name-only HEAD 2>/dev/null)
            
            # Pull remote changes
            if timeout 30 git reset --hard origin/main 2>/dev/null; then
                log_message "🔧 Reset to remote state, re-applying local changes..."
                
                # Re-apply only our local status files if they still exist
                for file in $local_changes; do
                    if [ -f "$file" ] && [[ "$file" == data/status/* ]]; then
                        git add "$file" 2>/dev/null
                        log_message "📝 Re-added local change: $file"
                    fi
                done
            else
                log_message "❌ Could not reset to remote state"
                exit 1
            fi
        fi
    else
        log_message "ℹ️  Local and remote are in sync"
    fi
else
    log_message "⚠️  Failed to fetch remote changes - proceeding with local sync only"
fi

# Add only data files (excluding any temporary or lock files)
git add data/status/ data/history/ data/details/ 2>/dev/null

# Check if there are staged changes
if git diff --staged --quiet; then
    log_message "ℹ️  No staged changes after git add"
    exit 0
fi

# Show what we're about to commit for debugging
staged_files=$(git diff --staged --name-only 2>/dev/null | head -10)
log_message "📝 Staging files: $(echo $staged_files | tr '\n' ' ')"

# Commit changes
COMMIT_MSG="SLURM dashboard sync: $(date '+%Y-%m-%d %H:%M:%S') (Job: $SLURM_JOB_ID)"
if timeout 30 git commit -m "$COMMIT_MSG" 2>/dev/null; then
    log_message "✅ Changes committed: $COMMIT_MSG"
    
    # Push changes (with timeout and retry)
    retry_count=0
    max_retries=3
    
    while [ $retry_count -lt $max_retries ]; do
        if timeout 60 git push origin main 2>/dev/null; then
            log_message "✅ Dashboard sync complete - deployed to GitHub"
            break
        else
            retry_count=$((retry_count + 1))
            log_message "⚠️  Push attempt $retry_count failed"
            
            if [ $retry_count -lt $max_retries ]; then
                log_message "🔄 Fetching latest changes before retry..."
                timeout 30 git pull --rebase origin main 2>/dev/null || {
                    log_message "⚠️  Rebase failed, attempting fresh sync..."
                    git rebase --abort 2>/dev/null || true
                    timeout 30 git reset --soft HEAD~1 2>/dev/null
                    timeout 30 git pull origin main 2>/dev/null
                    timeout 30 git commit -m "$COMMIT_MSG" 2>/dev/null || true
                }
                sleep 2
            else
                log_message "❌ All push retries failed - manual intervention required"
            fi
        fi
    done
else
    log_message "⚠️  Commit failed - possibly no changes or conflicts"
fi

# Clean up old log entries (keep last 200 lines)
if [ -f "$LOG_FILE" ]; then
    tail -200 "$LOG_FILE" > "${LOG_FILE}.tmp" 2>/dev/null && mv "${LOG_FILE}.tmp" "$LOG_FILE" 2>/dev/null
fi

log_message "🎯 SLURM dashboard sync job completed (ID: $SLURM_JOB_ID)"
