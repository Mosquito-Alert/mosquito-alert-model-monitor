#!/bin/bash

# Git sync with file locking to prevent race conditions
# This script ONLY handles git operations, not file writes

# Get monitor path from environment or argument
MONITOR_REPO_PATH="${MONITOR_PATH:-$1}"
OPERATION_DESC="${2:-sync}"

# Validate monitor path exists
if [ -z "$MONITOR_REPO_PATH" ] || [ ! -d "$MONITOR_REPO_PATH" ]; then
    echo "❌ Monitor repository not found: $MONITOR_REPO_PATH"
    echo "Set MONITOR_PATH environment variable or pass path as first argument"
    exit 1
fi

if [ ! -d "$MONITOR_REPO_PATH/.git" ]; then
    echo "❌ Not a git repository: $MONITOR_REPO_PATH"
    exit 1
fi

# Lock configuration
LOCK_DIR="$MONITOR_REPO_PATH/.git_sync_lock"
LOCK_TIMEOUT=30  # Maximum wait time in seconds
LOCK_CHECK_INTERVAL=1  # Check every second

echo "🔄 Git sync requested: $OPERATION_DESC"

# Function to acquire lock
acquire_lock() {
    local attempt=0
    local max_attempts=$((LOCK_TIMEOUT / LOCK_CHECK_INTERVAL))
    
    while [ $attempt -lt $max_attempts ]; do
        # Try to create lock directory atomically
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            # Store lock info
            echo "$$" > "$LOCK_DIR/pid"
            echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$LOCK_DIR/timestamp"
            echo "$OPERATION_DESC" > "$LOCK_DIR/operation"
            echo "$(hostname)" > "$LOCK_DIR/host"
            echo "✅ Git lock acquired (PID: $$)"
            return 0
        fi
        
        # Lock exists, check if it's stale
        if [ -f "$LOCK_DIR/pid" ]; then
            local lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null)
            local lock_time=$(cat "$LOCK_DIR/timestamp" 2>/dev/null)
            
            # Check if process is still running
            if ! kill -0 "$lock_pid" 2>/dev/null; then
                echo "⚠️  Removing stale lock (PID $lock_pid not running)"
                rm -rf "$LOCK_DIR" 2>/dev/null
                continue
            fi
            
            # Check if lock is too old (force cleanup after 5 minutes)
            if [ -n "$lock_time" ]; then
                local current_time=$(date -u +"%s")
                local lock_timestamp=$(date -u -d "$lock_time" +"%s" 2>/dev/null || echo "0")
                local age=$((current_time - lock_timestamp))
                
                if [ $age -gt 300 ]; then  # 5 minutes
                    echo "⚠️  Removing expired lock (age: ${age}s)"
                    rm -rf "$LOCK_DIR" 2>/dev/null
                    continue
                fi
            fi
        fi
        
        # Wait and retry
        echo "⏳ Waiting for git lock... (attempt $((attempt + 1))/$max_attempts)"
        sleep $LOCK_CHECK_INTERVAL
        attempt=$((attempt + 1))
    done
    
    echo "❌ Failed to acquire git lock after ${LOCK_TIMEOUT}s"
    return 1
}

# Function to release lock
release_lock() {
    if [ -d "$LOCK_DIR" ]; then
        rm -rf "$LOCK_DIR" 2>/dev/null
        echo "🔓 Git lock released"
    fi
}

# Function to perform git operations
perform_git_sync() {
    cd "$MONITOR_REPO_PATH" || {
        echo "❌ Cannot cd to monitor repo: $MONITOR_REPO_PATH"
        return 1
    }
    
    echo "📁 Working directory: $(pwd)"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Not a git repository: $MONITOR_REPO_PATH"
        return 1
    fi
    
    # Add all status and data files
    echo "📝 Adding updated files..."
    git add data/ 2>/dev/null || echo "⚠️  No data files to add"
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        echo "ℹ️  No changes to commit"
        return 0
    fi
    
    # Show what we're committing
    echo "📋 Changes to commit:"
    git diff --cached --name-only | head -10
    
    # Commit changes
    local commit_message="Dashboard update: $OPERATION_DESC ($(date -u +"%Y-%m-%d %H:%M:%S"))"
    echo "💾 Committing: $commit_message"
    
    if git commit -m "$commit_message" 2>/dev/null; then
        echo "✅ Changes committed successfully"
    else
        echo "⚠️  Commit failed, but continuing"
        return 0  # Don't fail completely
    fi
    
    # Push changes with retry logic
    echo "⬆️  Pushing to remote..."
    local push_attempts=0
    local max_push_attempts=3
    
    while [ $push_attempts -lt $max_push_attempts ]; do
        if git push origin main 2>/dev/null; then
            echo "✅ Push successful"
            return 0
        fi
        
        push_attempts=$((push_attempts + 1))
        echo "⚠️  Push attempt $push_attempts failed"
        
        if [ $push_attempts -lt $max_push_attempts ]; then
            echo "🔄 Pulling latest changes..."
            if git pull --rebase origin main 2>/dev/null; then
                echo "✅ Rebase successful, retrying push..."
            else
                echo "⚠️  Rebase failed, retrying anyway..."
                sleep 2
            fi
        fi
    done
    
    echo "⚠️  All push attempts failed, but local commit succeeded"
    return 0  # Don't fail completely - data is safe locally
}

# Cleanup on exit
trap 'release_lock' EXIT

# Main execution
if [ ! -d "$MONITOR_REPO_PATH" ]; then
    echo "❌ Monitor repository not found: $MONITOR_REPO_PATH"
    exit 1
fi

# Acquire lock
if ! acquire_lock; then
    echo "⚠️  Could not acquire git lock - skipping sync"
    exit 0  # Don't fail completely
fi

# Perform git sync
echo "🔄 Starting git sync operations..."
perform_git_sync
git_result=$?

if [ $git_result -eq 0 ]; then
    echo "✅ Git sync completed: $OPERATION_DESC"
else
    echo "⚠️  Git sync had issues but data is preserved"
fi

# Lock will be released by trap on exit
exit 0
