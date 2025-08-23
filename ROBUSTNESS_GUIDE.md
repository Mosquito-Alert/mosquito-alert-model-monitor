# Dashboard Robustness Implementation Guide

## 🚨 **Problem Summary**
The current dashboard integration is fragile and can cause critical job failures when git operations fail due to merge conflicts or repository state issues.

## ✅ **Robust Solutions Implemented**

### **1. Fail-Safe Status Updates (RECOMMENDED)**

Replace the current status update calls in your project scripts with the robust version:

#### **Old (Fragile) Approach:**
```bash
# This can fail and crash your job
./scripts/update_job_status.sh "job_name" "status" 120 75
```

#### **New (Robust) Approach:**
```bash
# This NEVER fails - always exits successfully
~/research/mosquito-alert-model-monitor/scripts/robust_status_update.sh "job_name" "status" 120 75 "log message"
```

### **2. Automatic Cron-Based Dashboard Sync**

Set up a cron job to sync the dashboard every 10 minutes, independent of your critical jobs:

```bash
# Add to your crontab
*/10 * * * * ~/research/mosquito-alert-model-monitor/scripts/sync_dashboard_cron.sh
```

This ensures the dashboard stays updated even if individual jobs can't push to git.

### **3. Enhanced Project Integration**

For each monitored project, update the scripts to use the robust approach:

#### **mosquito_model_data_prep/prepare_malert_data.sh:**
```bash
# Replace existing update_job_status.sh calls with:
~/research/mosquito-alert-model-monitor/scripts/robust_status_update.sh "prepare_malert_data" "running" $(($(date +%s) - $SCRIPT_START_TIME)) 50 "Processing reports"

# At the end, use the enhanced push script:
~/research/mosquito-alert-model-monitor/scripts/collect_logs.sh ~/research/mosquito-alert-model-monitor mosquito_model_data_prep ~/research/mosquito_model_data_prep/logs
~/research/mosquito-alert-model-monitor/scripts/failsafe_git_update.sh ~/research/mosquito-alert-model-monitor prepare_malert_data completed
```

## **4. Hybrid Approach (BEST PRACTICE)**

Combine both approaches for maximum reliability:

1. **Jobs use robust status updates** (never fail)
2. **Cron job syncs dashboard** (regular updates)
3. **Manual sync available** (troubleshooting)

## 🔧 **Implementation Steps**

### **Step 1: Update mosquito_model_data_prep Integration**

1. Modify `prepare_malert_data.sh`:
```bash
# Replace all calls to ./scripts/update_job_status.sh with:
STATUS_SCRIPT="$HOME/research/mosquito-alert-model-monitor/scripts/robust_status_update.sh"

# Throughout the script:
$STATUS_SCRIPT "prepare_malert_data" "running" $(($(date +%s) - $SCRIPT_START_TIME)) 25 "Downloading data"
$STATUS_SCRIPT "prepare_malert_data" "running" $(($(date +%s) - $SCRIPT_START_TIME)) 50 "Processing reports" 
# ... etc

# At the end:
$STATUS_SCRIPT "prepare_malert_data" "completed" $(($(date +%s) - $SCRIPT_START_TIME)) 100 "Pipeline completed"

# Collect logs and sync (but don't fail if it doesn't work)
$HOME/research/mosquito-alert-model-monitor/scripts/collect_logs.sh "" "mosquito_model_data_prep" || true
$HOME/research/mosquito-alert-model-monitor/scripts/failsafe_git_update.sh || true
```

### **Step 2: Set Up Cron Job**

Add to your cluster crontab:
```bash
# Dashboard sync every 10 minutes
*/10 * * * * ~/research/mosquito-alert-model-monitor/scripts/sync_dashboard_cron.sh

# Log collection every 30 minutes
*/30 * * * * ~/research/mosquito-alert-model-monitor/scripts/collect_logs.sh "" "mosquito_model_data_prep"
*/30 * * * * ~/research/mosquito-alert-model-monitor/scripts/collect_logs.sh "" "weather"
```

### **Step 3: Test the Robust System**

```bash
# Test that status updates never fail
~/research/mosquito-alert-model-monitor/scripts/robust_status_update.sh "test_job" "running" 60 50 "Testing robustness"
echo "Exit code: $?"  # Should always be 0

# Test log collection
~/research/mosquito-alert-model-monitor/scripts/collect_logs.sh "" "mosquito_model_data_prep"

# Test cron sync
~/research/mosquito-alert-model-monitor/scripts/sync_dashboard_cron.sh
```

## 📊 **Benefits of This Approach**

✅ **Critical jobs NEVER fail** due to dashboard issues  
✅ **Dashboard stays updated** via cron jobs  
✅ **Git conflicts handled automatically** with retries and fallbacks  
✅ **Log files accessible** via web interface  
✅ **Manual override available** for troubleshooting  
✅ **Backward compatible** with existing setup  

## 🚨 **Migration Priority**

1. **IMMEDIATE**: Update `prepare_malert_data.sh` to use robust status updates
2. **HIGH**: Set up cron jobs for dashboard sync
3. **MEDIUM**: Update other project integrations
4. **LOW**: Enhance log viewing and history pages

## ⚠️ **Important Notes**

- The robust scripts **always exit with code 0** to prevent job failures
- Git operations include retries and conflict resolution
- Log collection is optional and won't break jobs if it fails
- Dashboard updates are "best effort" - job completion is the priority
- Manual sync is always available as a fallback

This approach ensures your critical data processing jobs will **NEVER** fail due to dashboard integration issues, while still providing comprehensive monitoring when possible.
