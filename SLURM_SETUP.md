# SLURM Cron Job Setup for Dashboard Sync

## Resource Usage Analysis

**Per Sync Job:**
- **Memory**: 512MB (very light)
- **CPU**: 1 core
- **Time**: Maximum 5 minutes (typically 30-60 seconds)
- **Network**: Minimal git operations only

**Total Daily Load:**
- If run every 15 minutes: 96 jobs/day × 1-2 minutes = ~2-3 hours total CPU time
- If run every 30 minutes: 48 jobs/day × 1-2 minutes = ~1-1.5 hours total CPU time

## Recommended Crontab Entry

Add to your cluster crontab (`crontab -e`):

```bash
# Dashboard sync every 15 minutes (recommended for active development)
*/15 * * * * cd ~/research/mosquito-alert-model-monitor && sbatch scripts/slurm_dashboard_sync.sh

# OR: Dashboard sync every 30 minutes (recommended for production)
*/30 * * * * cd ~/research/mosquito-alert-model-monitor && sbatch scripts/slurm_dashboard_sync.sh
```

## Load Impact Assessment

**MINIMAL LOAD** - This is extremely lightweight:
- Uses same resources as a simple git operation
- Runs for only 1-2 minutes typically
- No computational processing
- Only file I/O and network operations

**Comparison:**
- Your data prep jobs: ~hours of runtime, GBs of memory
- Dashboard sync: ~1 minute runtime, 512MB memory

**Recommendation**: Start with 15-minute intervals. If you want to reduce load further, change to 30-minute intervals.

## Monitoring

Check sync job status:
```bash
# View recent sync jobs
squeue -u $USER | grep dashboard_sync

# Check sync logs
tail -50 ~/research/mosquito-alert-model-monitor/logs/dashboard_sync.log
```

## Manual Sync

If needed, run sync manually:
```bash
cd ~/research/mosquito-alert-model-monitor
sbatch scripts/slurm_dashboard_sync.sh
```
