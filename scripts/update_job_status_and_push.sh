#!/bin/bash

# Enhanced status update script that includes git operations
# This script updates job status AND pushes to git to trigger dashboard rebuild
# Usage: ./update_job_status_and_push.sh <job_name> <status> [duration] [progress]

JOB_NAME="$1"
STATUS="$2"
DURATION="$3"
PROGRESS="$4"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <job_name> <status> [duration] [progress]"
    echo "Status options: running, completed, failed, pending"
    exit 1
fi

# Get script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Set paths
STATUS_DIR="$PROJECT_DIR/data/status"
HISTORY_DIR="$PROJECT_DIR/data/history"

# Create directories if they don't exist
mkdir -p "$STATUS_DIR"
mkdir -p "$HISTORY_DIR"

echo "Updating status for job: $JOB_NAME -> $STATUS"

# First, call the original status update script
"$SCRIPT_DIR/update_job_status.sh" "$JOB_NAME" "$STATUS" "$DURATION" "$PROGRESS"

if [ $? -ne 0 ]; then
    echo "Error: Failed to update job status"
    exit 1
fi

# Change to project directory for git operations
cd "$PROJECT_DIR"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "Warning: Not in a git repository. Skipping git operations."
    echo "Status updated locally in $STATUS_DIR/${JOB_NAME}.json"
    exit 0
fi

# Add the status files to git
git add data/status/ data/history/ 2>/dev/null

# Check if there are any changes to commit
if git diff --staged --quiet; then
    echo "No changes to commit. Status may already be up to date."
    exit 0
fi

# Commit the changes
COMMIT_MSG="Update job status: $JOB_NAME -> $STATUS"
if [ ! -z "$DURATION" ] && [ ! -z "$PROGRESS" ]; then
    COMMIT_MSG="$COMMIT_MSG (${DURATION}s, ${PROGRESS}%)"
fi

git commit -m "$COMMIT_MSG" || {
    echo "Warning: Git commit failed. Status updated locally but not pushed to remote."
    exit 1
}

# Push to remote (this will trigger GitHub Actions)
echo "Pushing changes to trigger dashboard rebuild..."
git push origin main || {
    echo "Warning: Git push failed. Changes committed locally but not pushed to remote."
    echo "You may need to push manually later: git push origin main"
    exit 1
}

echo "✅ Status updated and pushed successfully!"
echo "📊 Dashboard will rebuild automatically via GitHub Actions"
echo "🔗 Check progress at: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
