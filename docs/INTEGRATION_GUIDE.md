# Project Integration Guide for mosquito-alert-model-monitor

## Overview
This guide shows how to integrate any computational project with the mosquito-alert-model-monitor dashboard. The integration is designed to be **bulletproof** - main project jobs never fail due to dashboard issues.

## Architecture Principles

### 🎯 Separation of Concerns
- **Main projects**: Focus on their core mission, fail fast on real infrastructure issues
- **Monitor project**: Handle all dashboard complexity, never fail calling jobs
- **Git conflicts**: Handled gracefully without blocking data collection

### 🛡️ Robustness Hierarchy
1. Core data collection NEVER fails due to dashboard issues
2. Status updates are best-effort only  
3. Git conflicts resolved automatically
4. Module loading required for main scripts (not defensive)

## Quick Integration (5 minutes)

### Step 1: Create Drop-in Status Script
Create `scripts/update_job_status.sh` in your project:

```bash
#!/bin/bash
# Drop-in status update script - NEVER fails calling jobs

JOB_NAME="${1:-project-unknown}"
STATUS="${2:-unknown}"
DURATION="${3:-0}"
PROGRESS="${4:-0}"
LOG_MESSAGE="${5:-Job status update}"

# Use monitor script if available
MONITOR_SCRIPT="$HOME/research/mosquito-alert-model-monitor/scripts/update_job_status.sh"

if [ -f "$MONITOR_SCRIPT" ]; then
    echo "📊 Updating dashboard..."
    "$MONITOR_SCRIPT" "$JOB_NAME" "$STATUS" "$DURATION" "$PROGRESS" "$LOG_MESSAGE"
else
    echo "⚠️  Monitor not found - skipping dashboard update"
fi

# ALWAYS exit successfully
exit 0
```

### Step 2: Add Status Calls to Main Script
```bash
#!/bin/bash
# Your main project script

# Job setup
JOB_NAME="my-project-job"
STATUS_SCRIPT="./scripts/update_job_status.sh"
START_TIME=$(date +%s)

# Status updates (never fail your job)
$STATUS_SCRIPT "$JOB_NAME" "running" 0 5

# Your actual work here
python my_main_script.py

# Final status
$STATUS_SCRIPT "$JOB_NAME" "completed" $(($(date +%s) - START_TIME)) 100
```

### Step 3: Add Cluster Sync (Prevents Git Conflicts)
Add to your cluster crontab:
```bash
# Sync monitor repo every 30 minutes to prevent conflicts
*/30 * * * * ~/research/mosquito-alert-model-monitor/scripts/cluster_sync.sh
```

## That's It! 
Your project now reports to the dashboard without any risk of failure.

## Advanced Configuration

### Custom Job Names
Use descriptive job names that will appear on the dashboard:
```bash
$STATUS_SCRIPT "weather-hourly-collection" "running" 0 25
$STATUS_SCRIPT "mosquito-model-training" "completed" 3600 100
$STATUS_SCRIPT "data-preprocessing" "failed" 1200 75
```

### Progress Tracking
Update progress throughout long-running jobs:
```bash
$STATUS_SCRIPT "$JOB_NAME" "running" $(($(date +%s) - START_TIME)) 25
# ... do work ...
$STATUS_SCRIPT "$JOB_NAME" "running" $(($(date +%s) - START_TIME)) 50
# ... do more work ...
$STATUS_SCRIPT "$JOB_NAME" "running" $(($(date +%s) - START_TIME)) 75
```

### Error Handling
```bash
if my_critical_process; then
    $STATUS_SCRIPT "$JOB_NAME" "completed" $(($(date +%s) - START_TIME)) 100
else
    $STATUS_SCRIPT "$JOB_NAME" "failed" $(($(date +%s) - START_TIME)) 50
    exit 1  # Fail the main job for real errors
fi
```

## Git Conflict Prevention

The system automatically handles git conflicts, but you can prevent them:

1. **Add cluster sync to cron** (recommended):
   ```bash
   */30 * * * * ~/research/mosquito-alert-model-monitor/scripts/cluster_sync.sh
   ```

2. **Manual sync before major updates**:
   ```bash
   cd ~/research/mosquito-alert-model-monitor
   git pull origin main
   ```

3. **View sync logs**:
   ```bash
   tail -f ~/research/mosquito-alert-model-monitor/logs/cluster_sync.log
   ```

## Troubleshooting

### Dashboard Not Updating
1. Check if monitor repository exists: `ls ~/research/mosquito-alert-model-monitor`
2. Check git status: `cd ~/research/mosquito-alert-model-monitor && git status`
3. Check sync logs: `tail ~/research/mosquito-alert-model-monitor/logs/cluster_sync.log`

### Git Conflicts
The system handles these automatically, but if you see issues:
```bash
cd ~/research/mosquito-alert-model-monitor
git stash
git pull origin main
git stash pop
```

### Status Not Appearing
1. Verify job name matches what you expect
2. Check status files: `ls ~/research/mosquito-alert-model-monitor/data/status/`
3. Check the dashboard URL after 2-3 minutes

## Examples

### Weather Data Collection
```bash
$STATUS_SCRIPT "weather-hourly" "running" 0 10
R CMD BATCH code/get_latest_data.R
$STATUS_SCRIPT "weather-hourly" "completed" 120 100
```

### Machine Learning Training  
```bash
$STATUS_SCRIPT "model-training" "running" 0 5
python train_model.py --epochs 100
$STATUS_SCRIPT "model-training" "completed" 7200 100
```

### Data Processing Pipeline
```bash
$STATUS_SCRIPT "data-pipeline" "running" 0 20
./preprocess_data.sh
$STATUS_SCRIPT "data-pipeline" "running" 1800 60  
./analyze_data.sh
$STATUS_SCRIPT "data-pipeline" "completed" 3600 100
```

This integration approach ensures your critical jobs never fail due to dashboard issues while providing comprehensive monitoring.
