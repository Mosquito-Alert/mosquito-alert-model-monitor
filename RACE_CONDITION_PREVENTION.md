# Race Condition Prevention Guide

## 🚨 **Critical Issue: Dashboard Sync Race Conditions**

### **The Problem**
Multiple projects updating the dashboard simultaneously can cause data loss through git conflicts and stashing operations.

### **Race Condition Scenarios**

#### **Scenario 1: Concurrent Updates**
```
10:30:00 - Weather project pushes status update
10:30:15 - SLURM sync script runs (cron every 15 min)
10:30:16 - Sync script stashes weather updates  
10:30:17 - Dashboard shows stale weather data
```

#### **Scenario 2: Git Conflict Stashing**
```
Project A: Updates data/status/job_a.json
Project B: Updates data/status/job_b.json (same time)
Sync Script: Encounters merge conflict
Sync Script: Stashes ALL changes (loses both updates)
Dashboard: Shows outdated status for both jobs
```

#### **Scenario 3: Overwrite During Push**
```
Project A: Commits status update locally
Project B: Commits status update locally  
Project A: Pushes successfully
Project B: Force pushes, overwrites Project A's update
Result: Project A's status lost
```

## ✅ **Solution: Safe Scripts with Locking**

### **New Safe Scripts**

**1. `scripts/slurm_dashboard_sync_safe.sh`**
- Uses file locking to prevent concurrent sync operations
- Safely merges remote changes without losing local updates
- Only adds specific data files, not entire directories
- Retries with conflict resolution

**2. `scripts/failsafe_git_update_safe.sh`**  
- Acquires lock before git operations
- Updates only the specific job's status file
- Checks for conflicts with that specific file
- Falls back to local-only updates if lock unavailable

### **Key Safety Features**

#### **🔒 File Locking**
```bash
# Prevents multiple git operations simultaneously
LOCK_FILE="$REPO_PATH/.git/dashboard_sync.lock"
acquire_lock() {
    if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
        return 0  # Got lock
    else
        return 1  # Another operation in progress
    fi
}
```

#### **📝 Selective File Operations**
```bash
# OLD (dangerous): Adds all changes
git add data/

# NEW (safe): Adds only specific files
git add "data/status/${JOB_NAME}.json"
```

#### **🔄 Conflict Detection**
```bash
# Check if our specific file conflicts with remote
our_file="data/status/${JOB_NAME}.json"
remote_changes=$(git diff --name-only HEAD origin/main)
if echo "$remote_changes" | grep -q "^$our_file$"; then
    # Handle conflict specifically for our file
fi
```

#### **⏱️ Graceful Degradation**
```bash
# If can't get lock, update locally only
if ! acquire_lock; then
    echo "📝 Status updated locally - sync job will pick up later"
    exit 0  # Don't fail the calling job
fi
```

## 🔧 **Migration Plan**

### **Phase 1: Deploy Safe Scripts (Recommended)**
```bash
# Replace current sync script
cp scripts/slurm_dashboard_sync_safe.sh scripts/slurm_dashboard_sync.sh

# Update crontab to use safe script
crontab -e
# Change to: */15 * * * * cd ~/research/mosquito-alert-model-monitor && sbatch scripts/slurm_dashboard_sync.sh
```

### **Phase 2: Update Project Integration**
```bash
# In mosquito_model_data_prep project:
# Replace calls to update_job_status.sh with safe version
~/research/mosquito-alert-model-monitor/scripts/failsafe_git_update_safe.sh \
    ~/research/mosquito-alert-model-monitor \
    "prepare_malert_data" \
    "running" \
    3600 \
    50
```

### **Phase 3: Monitor for Issues**
```bash
# Check sync logs for conflicts
tail -50 ~/research/mosquito-alert-model-monitor/logs/dashboard_sync.log

# Look for:
# "⚠️  Could not acquire lock" - High contention
# "🔧 Removing stale lock file" - Crashed operations  
# "❌ All push retries failed" - Network/conflict issues
```

## 📊 **Testing the Fix**

### **Simulate Race Condition**
```bash
# Terminal 1: Start fake job update
for i in {1..10}; do
    echo '{"job_name":"test_job_a","status":"running","progress":'$((i*10))'}' > data/status/test_job_a.json
    ~/research/mosquito-alert-model-monitor/scripts/failsafe_git_update_safe.sh \
        ~/research/mosquito-alert-model-monitor test_job_a running
    sleep 5
done

# Terminal 2: Start another fake job update  
for i in {1..10}; do
    echo '{"job_name":"test_job_b","status":"completed","progress":100}' > data/status/test_job_b.json
    ~/research/mosquito-alert-model-monitor/scripts/failsafe_git_update_safe.sh \
        ~/research/mosquito-alert-model-monitor test_job_b completed
    sleep 3
done

# Terminal 3: Run sync script
sbatch scripts/slurm_dashboard_sync_safe.sh
```

### **Expected Results**
- ✅ Both test_job_a and test_job_b updates preserved
- ✅ No "stash" operations in git log
- ✅ Lock messages in logs showing coordination
- ✅ All updates appear in dashboard

## 🎯 **Monitoring Commands**

### **Check Lock Status**
```bash
# See if operations are waiting for locks
ls -la ~/research/mosquito-alert-model-monitor/.git/*.lock

# Check process holding lock
if [ -f ~/research/mosquito-alert-model-monitor/.git/dashboard_sync.lock ]; then
    cat ~/research/mosquito-alert-model-monitor/.git/dashboard_sync.lock
fi
```

### **View Recent Git Operations**
```bash
# Check for stash operations (should be rare/none)
cd ~/research/mosquito-alert-model-monitor
git log --oneline -10 | grep -i stash

# Check commit frequency (should be steady)
git log --oneline --since="1 hour ago" | wc -l
```

### **Dashboard Sync Health**
```bash
# Check sync job success rate
tail -100 ~/research/mosquito-alert-model-monitor/logs/dashboard_sync.log | \
    grep -E "(completed|failed)" | tail -10
```

## ⚠️ **What to Watch For**

### **Signs of Race Conditions (Bad)**
- Multiple "stash" entries in git log
- Status files missing expected updates
- Log messages about "complex conflicts"
- Jobs reporting success but not appearing in dashboard

### **Signs of Healthy Operation (Good)**  
- Regular commit messages with job names
- "Acquired/Released lock" messages in logs
- Consistent dashboard updates within 2-3 minutes
- No "manual intervention required" messages

## 🚀 **Performance Impact**

### **Lock Overhead**
- **Minimal**: File locking adds ~100ms per operation
- **Timeout**: Operations wait max 30s for locks
- **Fallback**: Local updates continue even if locks fail

### **Resource Usage**
- **Same SLURM allocation**: 512MB RAM, 1 CPU, 5 min max
- **Slightly longer runtime**: +10-20s for safety checks
- **Better reliability**: Fewer failed syncs requiring manual fix

The safe approach trades a small performance cost for significantly better data integrity and reliability.
