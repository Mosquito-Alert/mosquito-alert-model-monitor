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

# Check if it's a git repo
if [ ! -d ".git" ]; then
    echo "⚠️  Monitor repo is not a git repository - skipping dashboard update"
    exit 0  # Exit success - don't fail the calling job
fi

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
