# Weather Data Collector - Dashboard Integration

## ✅ Integration Complete

The weather-data-collector-spain project is now fully integrated with the mosquito-alert-model-monitor dashboard.

## 🎯 What's Monitored

The dashboard now tracks these weather collection jobs:

| Job Name | Purpose | Frequency | Priority |
|----------|---------|-----------|----------|
| `weather-forecast` | Municipal forecasts (8,129 municipalities) | Every 6 hours | CRITICAL |
| `weather-hourly` | Station observations (all AEMET stations) | Every 2 hours | MEDIUM |
| `weather-historical` | Historical data backfill | Daily | LOW |
| `municipal-forecast-priority` | Immediate municipal data | Every 6 hours | CRITICAL |

## 🔧 Key Changes Made

### 1. Enhanced Status Reporting
- **Updated**: `scripts/update_weather_status.sh` now includes git push functionality
- **Result**: Job status changes automatically trigger dashboard rebuilds

### 2. Job Script Integration
- **Modified**: `update_weather.sh` with proper status reporting
- **Modified**: `priority_municipal_data.sh` with status integration
- **Result**: All weather jobs report progress, duration, and completion status

### 3. Initial Status Files
- **Created**: Status files for all 4 weather jobs in the dashboard
- **Result**: Dashboard shows weather jobs even when not actively running

## 🚀 Testing on Cluster

When you're ready to test on the HPC cluster:

### 1. Quick Integration Test
```bash
cd ~/research/weather-data-collector-spain
./scripts/test_dashboard_integration.sh
```

### 2. Run a Real Weather Job
```bash
# Test the priority municipal forecast (short runtime)
sbatch priority_municipal_data.sh

# Monitor dashboard for live updates
```

### 3. Check Dashboard
- **Local**: `~/research/mosquito-alert-model-monitor/docs/index.html`
- **GitHub Pages**: Will auto-update within 2-3 minutes of job status changes

## 📊 Dashboard Features for Weather Jobs

- **Real-time Status**: Running, completed, failed, waiting
- **Progress Tracking**: 0-100% completion
- **Duration Monitoring**: Job execution time
- **Resource Usage**: CPU and memory utilization
- **Next Run Schedule**: Automatic calculation based on job type
- **Error Alerts**: Failed jobs highlighted in dashboard

## 🔄 How It Works

1. **Job starts** → Updates status to "running"
2. **Job progresses** → Periodic status updates with progress %
3. **Job completes/fails** → Final status update
4. **Status script** → Automatically commits and pushes to git
5. **GitHub Actions** → Rebuilds and deploys dashboard
6. **Dashboard** → Shows updated status within 2-3 minutes

## ⚠️ Requirements on Cluster

- SSH keys configured for git push
- `mosquito-alert-monitor` conda environment activated
- Access to `~/research/mosquito-alert-model-monitor` directory

## 🎉 Benefits

- **Real-time Monitoring**: See job status without logging into cluster
- **Historical Tracking**: Dashboard maintains job history
- **Automated Alerts**: Failed jobs are highlighted
- **Resource Monitoring**: Track cluster resource usage
- **Schedule Awareness**: See when jobs are expected to run next

Your weather data collection pipeline is now fully visible and monitored through the dashboard!
