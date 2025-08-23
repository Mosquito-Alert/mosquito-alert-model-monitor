#!/bin/bash

# Race-Condition-Safe Git Update Script v4.0
# Handles git conflicts without interfering with concurrent updates from other projects
# Uses file locking and selective operations to prevent data loss
# Usage: failsafe_git_update_safe.sh <repo_path> <job_name> <status> [duration] [progress]

REPO_PATH="${1:-$HOME/research/mosquito-alert-model-monitor}"
JOB_NAME="${2:-unknown}"
STATUS="${3:-unknown}"
DURATION="${4:-0}"
PROGRESS="${5:-0}"
LOCK_FILE="$REPO_PATH/.git/status_update.lock"

cd "$REPO_PATH" || {
    echo "⚠️  Cannot access monitor repository: $REPO_PATH"
    exit 0
}

# Check if this is a git repository
if [ ! -d ".git" ]; then
    echo "ℹ️  Not a git repository - status updated locally only"
    exit 0
fi

# Function to acquire lock with timeout
acquire_lock() {
    local timeout=30
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            echo "🔒 Acquired git update lock for $JOB_NAME"
            return 0
        fi
        
        # Check if existing lock is stale (>2 minutes old)
        if [ -f "$LOCK_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0))) -gt 120 ]; then
            echo "🔧 Removing stale lock file"
            rm -f "$LOCK_FILE" 2>/dev/null
        else
            sleep 1
            elapsed=$((elapsed + 1))
        fi
    done
    
    echo "⚠️  Could not acquire lock - another git operation in progress"
    echo "📝 Status file updated locally only"
    return 1
}

# Function to release lock
release_lock() {
    rm -f "$LOCK_FILE" 2>/dev/null
}

# Set up cleanup
cleanup() {
    release_lock
}
trap cleanup EXIT INT TERM

echo "🔄 Starting safe git update for $JOB_NAME..."

# Try to acquire lock (but don't fail if we can't)
if acquire_lock; then
    # We have the lock - proceed with git operations
    
    # Check current git status
    if git diff --quiet data/status/${JOB_NAME}.json 2>/dev/null; then
        echo "ℹ️  No changes to ${JOB_NAME}.json - skipping git operations"
        exit 0
    fi
    
    # Try to sync with remote first (but only if we can do it safely)
    echo "📥 Checking for remote updates..."
    if timeout 15 git fetch origin main 2>/dev/null; then
        LOCAL=$(git rev-parse HEAD 2>/dev/null)
        REMOTE=$(git rev-parse origin/main 2>/dev/null)
        
        if [ "$LOCAL" != "$REMOTE" ]; then
            echo "🔄 Remote has updates - checking for conflicts..."
            
            # Check if our specific file conflicts
            our_file="data/status/${JOB_NAME}.json"
            remote_changes=$(git diff --name-only HEAD origin/main 2>/dev/null)
            
            if echo "$remote_changes" | grep -q "^$our_file$"; then
                echo "⚠️  Conflict detected for $our_file - using timestamp-based resolution"
                
                # Pull remote changes first
                if timeout 15 git pull origin main 2>/dev/null; then
                    echo "✅ Pulled remote changes successfully"
                else
                    echo "⚠️  Pull failed - proceeding with local update only"
                fi
            else
                # No conflict with our file - safe to pull
                if timeout 15 git pull origin main 2>/dev/null; then
                    echo "✅ Safely pulled remote changes (no conflicts)"
                else
                    echo "⚠️  Pull failed despite no conflicts - network issue?"
                fi
            fi
        fi
    else
        echo "⚠️  Cannot reach remote - proceeding with local operations"
    fi
    
    # Add only our specific status file
    if [ -f "data/status/${JOB_NAME}.json" ]; then
        git add "data/status/${JOB_NAME}.json" 2>/dev/null || true
        
        # Check if there are staged changes
        if ! git diff --staged --quiet; then
            # Try to commit
            COMMIT_MSG="Update ${JOB_NAME} status: ${STATUS} ($(date '+%Y-%m-%d %H:%M:%S'))"
            
            if timeout 15 git commit -m "$COMMIT_MSG" 2>/dev/null; then
                echo "✅ Status committed: $JOB_NAME -> $STATUS"
                
                # Try to push with retries
                retry_count=0
                max_retries=2
                
                while [ $retry_count -lt $max_retries ]; do
                    if timeout 30 git push origin main 2>/dev/null; then
                        echo "✅ Dashboard update pushed - will be live in ~2-3 minutes"
                        break
                    else
                        retry_count=$((retry_count + 1))
                        echo "⚠️  Push attempt $retry_count failed"
                        
                        if [ $retry_count -lt $max_retries ]; then
                            echo "🔄 Retrying after brief delay..."
                            sleep 2
                            
                            # Quick rebase attempt
                            timeout 15 git pull --rebase origin main 2>/dev/null || {
                                echo "⚠️  Rebase failed - will retry push as-is"
                                git rebase --abort 2>/dev/null || true
                            }
                        else
                            echo "⚠️  All push attempts failed - dashboard may show stale data"
                            echo "💡 Manual push may be needed: cd $REPO_PATH && git push origin main"
                        fi
                    fi
                done
            else
                echo "ℹ️  No changes to commit (status unchanged)"
            fi
        else
            echo "ℹ️  No staged changes for $JOB_NAME"
        fi
    else
        echo "⚠️  Status file not found: data/status/${JOB_NAME}.json"
    fi
    
else
    # Could not acquire lock - just update locally
    echo "📝 Git lock unavailable - status updated locally only"
    echo "💡 Dashboard sync job will pick up changes later"
fi

# Always exit successfully - never fail the calling job
exit 0
