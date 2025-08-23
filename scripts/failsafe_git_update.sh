#!/bin/bash

# Fail-safe git operations for dashboard updates
# This script NEVER fails - it either succeeds or logs the issue and continues
# Critical jobs should NEVER crash due to dashboard update failures

MONITOR_REPO_PATH="${1:-$HOME/research/mosquito-alert-model-monitor}"
JOB_NAME="${2:-unknown}"
STATUS="${3:-unknown}"

# Ensure we're in the monitor repo
cd "$MONITOR_REPO_PATH" 2>/dev/null || {
    echo "⚠️  Cannot access monitor repo at $MONITOR_REPO_PATH - skipping dashboard update"
    exit 0  # Exit success - don't fail the calling job
}

#!/bin/bash

# Failsafe Git Update Script v3.0
# Handles git conflicts gracefully without failing calling jobs
# Usage: failsafe_git_update.sh <repo_path> <job_name> <status> [duration] [progress]

REPO_PATH="${1:-$HOME/research/mosquito-alert-model-monitor}"
JOB_NAME="${2:-unknown}"
STATUS="${3:-unknown}"
DURATION="${4:-0}"
PROGRESS="${5:-0}"

cd "$REPO_PATH" || {
    echo "⚠️  Cannot access monitor repository: $REPO_PATH"
    exit 0
}

# Check if this is a git repository
if [ ! -d ".git" ]; then
    echo "ℹ️  Not a git repository - status updated locally only"
    exit 0
fi

echo "🔄 Attempting git sync for dashboard update..."

# Function to handle git conflicts by preferring remote changes
resolve_conflicts() {
    echo "🔧 Resolving git conflicts by accepting remote changes..."
    
    # Reset to remote state for problematic files, keeping our status updates
    git reset --hard HEAD 2>/dev/null || true
    git pull --strategy=ours origin main 2>/dev/null || {
        echo "⚠️  Complex conflict - attempting fresh sync..."
        
        # Last resort: stash local changes, pull, then reapply status files
        git stash push -m "Auto-stash from $(hostname) at $(date)" 2>/dev/null || true
        git pull origin main 2>/dev/null || {
            echo "⚠️  Git sync failed - dashboard will show stale data"
            return 1
        }
        
        # Re-create the status file (this is what we really care about)
        echo "📝 Recreating status file after conflict resolution..."
        return 0
    }
}

# Function to safely execute git operations
safe_git_operation() {
    local operation="$1"
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        case "$operation" in
            "pull")
                if git pull origin main --rebase 2>/dev/null; then
                    echo "✅ Git pull successful"
                    return 0
                fi
                ;;
            "push")
                if git push origin main 2>/dev/null; then
                    echo "✅ Git push successful - dashboard will rebuild"
                    return 0
                fi
                ;;
        esac
        
        retry_count=$((retry_count + 1))
        echo "⚠️  Git $operation attempt $retry_count failed, retrying in 2 seconds..."
        sleep 2
    done
    
    # If we get here, all retries failed
    echo "⚠️  Git $operation failed after $max_retries attempts"
    echo "📝 Status files updated locally but dashboard may not reflect changes"
    return 1  # Return failure but don't exit the script
}

# Always try to sync first (handles the case where remote has new changes)
echo "🔄 Attempting to sync with remote repository..."
safe_git_operation "pull"

# Check if there are any changes to commit
if git diff --quiet && git diff --staged --quiet; then
    echo "ℹ️  No changes to commit - status files unchanged"
    exit 0
fi

# Add any new status files
git add data/status/ data/history/ data/details/ 2>/dev/null || true

# Check again if there are staged changes
if git diff --staged --quiet; then
    echo "ℹ️  No staged changes after git add"
    exit 0
fi

# Create commit
COMMIT_MSG="Dashboard update: $JOB_NAME -> $STATUS ($(date '+%Y-%m-%d %H:%M:%S'))"
if git commit -m "$COMMIT_MSG" 2>/dev/null; then
    echo "✅ Changes committed locally"
    
    # Try to push (but don't fail if it doesn't work)
    if safe_git_operation "push"; then
        echo "🎯 Dashboard update complete and deployed"
    else
        echo "📝 Dashboard updated locally but not deployed to GitHub"
        echo "💡 Manual push may be needed later: cd $MONITOR_REPO_PATH && git push origin main"
    fi
else
    echo "⚠️  Git commit failed - possibly no changes or conflicts"
    echo "📝 Status files are updated locally"
fi

# Always exit successfully to avoid crashing calling jobs
exit 0
