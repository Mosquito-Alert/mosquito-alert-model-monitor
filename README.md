# Mosquito Alert Model Monitor

A Quarto dashboard for monitoring automated data wrangling tasks and models running on computational clusters.

## Features

- **Real-time Status Monitoring**: Track the status, progress, and performance of multiple jobs
- **Static Dashboard**: Built with Quarto for fast, reliable GitHub Pages deployment
- **Alert System**: Automatic detection of failed jobs, long-running tasks, and stale processes
- **Historical Tracking**: Performance trends and success rate analysis over time
- **Resource Monitoring**: CPU and memory usage tracking for each job
- **GitHub Pages Deployment**: Automated deployment via GitHub Actions

## Quick Start

### 1. Setup Environment on HPC Cluster

```bash
# Clone the repository
git clone https://github.com/Mosquito-Alert/mosquito-alert-model-monitor.git
cd mosquito-alert-model-monitor

# Find available conda modules on your HPC system
module avail 2>&1 | grep -i conda
# or
module avail 2>&1 | grep -i miniconda

# Load conda module (adjust name/version to match your system)
module load Miniconda3/24.7.1-0

# Create conda environment
conda env create -f environment.yml
conda activate mosquito-alert-monitor

# Alternative: Install dependencies manually if needed
# conda install -c conda-forge r-base r-dt r-plotly r-jsonlite r-lubridate r-dplyr r-purrr r-stringr r-ggplot2 quarto
```

### 2. Setup SLURM Dashboard Sync (RECOMMENDED)

Add to your cluster crontab (`crontab -e`):
```bash
# Dashboard sync every 15 minutes (lightweight: 512MB RAM, 1 CPU, ~1 min runtime)
*/15 * * * * cd ~/research/mosquito-alert-model-monitor && sbatch scripts/slurm_dashboard_sync.sh
```

### 3. Integrate Your Projects

For each project you want to monitor, add these calls to your main scripts:

#### **Bash Scripts:**
```bash
# At the beginning
DASHBOARD_SCRIPT="$HOME/research/mosquito-alert-model-monitor/scripts/update_job_status.sh"
JOB_NAME="your_project_name"  # Use descriptive name
START_TIME=$(date +%s)

$DASHBOARD_SCRIPT "$JOB_NAME" "running" 0 0 "Job started"

# Throughout your script (for progress tracking)
$DASHBOARD_SCRIPT "$JOB_NAME" "running" $(($(date +%s) - $START_TIME)) 25 "Data loading"
$DASHBOARD_SCRIPT "$JOB_NAME" "running" $(($(date +%s) - $START_TIME)) 50 "Processing"
$DASHBOARD_SCRIPT "$JOB_NAME" "running" $(($(date +%s) - $START_TIME)) 75 "Finalizing"

# At the end
$DASHBOARD_SCRIPT "$JOB_NAME" "completed" $(($(date +%s) - $START_TIME)) 100 "Completed successfully"
```

#### **Python Scripts:**
```python
import subprocess, time, os

DASHBOARD_SCRIPT = os.path.expanduser("~/research/mosquito-alert-model-monitor/scripts/update_job_status.sh")
JOB_NAME = "your_project_name"
start_time = time.time()

def update_status(status, progress, message):
    elapsed = int(time.time() - start_time)
    subprocess.run([DASHBOARD_SCRIPT, JOB_NAME, status, str(elapsed), str(progress), message], 
                  check=False, capture_output=True)

update_status("running", 0, "Job started")
# ... your code ...
update_status("completed", 100, "Job completed")
```

### 4. Deploy to GitHub Pages

1. Enable GitHub Pages in your repository settings
2. Set source to "GitHub Actions"  
3. Push changes to main branch - the dashboard will automatically deploy

**🔑 KEY FEATURES:**
- ✅ **Robust Integration**: Jobs NEVER fail due to dashboard issues
- ✅ **Real-time Updates**: Status changes trigger automatic dashboard rebuilds
- ✅ **SLURM Compatible**: Proper resource allocation for cluster environments
- ✅ **Log Access**: View project logs directly from the dashboard
- ✅ **Mobile Friendly**: Monitor jobs from anywhere via GitHub Pages
# Render and serve the dashboard
quarto preview index.qmd

# Or render static version
quarto render
```

### 4. Deploy to GitHub Pages

1. Enable GitHub Pages in your repository settings
2. Set source to "GitHub Actions"
3. Push changes to main branch - the dashboard will automatically deploy

## Job Integration

### Dashboard Update Mechanism

The dashboard is designed to update automatically through two possible strategies:

#### 1. Job-Triggered Updates (Recommended)
- **How it works**: When each job completes (success or failure), it automatically pushes status updates to the git repository, which triggers GitHub Actions to rebuild and redeploy the dashboard
- **Script**: Use `scripts/update_job_status_and_push.sh` in your jobs
- **Advantages**: Real-time updates as soon as jobs complete
- **Requirements**: Git push access from your HPC cluster

#### 2. Scheduled Updates (Alternative)
- **How it works**: Set up a separate cron job that periodically checks for status changes and pushes updates
- **Script**: Use `scripts/update_job_status.sh` followed by manual git operations
- **Advantages**: Works even if individual jobs can't push to git
- **Requirements**: Separate scheduling system

The current implementation uses strategy #1 for immediate dashboard updates.

### Status File Format

Each job should create/update a JSON file in `data/status/` with this structure:

```json
{
  "job_name": "species_classification_model",
  "status": "running",
  "start_time": "2025-08-17T08:30:00Z", 
  "duration": 1800,
  "progress": 65,
  "cpu_usage": 85.2,
  "memory_usage": 2048,
  "next_scheduled_run": "2025-08-18T08:30:00Z",
  "log_entries": [
    "Starting model training",
    "Loading data...",
    "Training in progress"
  ],
  "config": {
    "model_type": "ResNet50",
    "batch_size": 32
  }
}
```

### Integration Examples

#### Option 1: Using the HPC Module Wrapper Script
```bash
# Automatically loads modules and activates conda environment
./scripts/run_with_conda.sh scripts/update_job_status.sh "my_job" "running" 60 50

# Use in crontab
30 8 * * * /path/to/mosquito-alert-model-monitor/scripts/run_with_conda.sh /path/to/your/model_script.sh
```

#### Option 2: Manual Module Loading in Your Scripts  
```bash
#!/bin/bash
# Load required modules for HPC
module load Miniconda3/24.7.1-0
conda activate mosquito-alert-monitor

# Optional: Load additional modules as needed
# module load GCC/12.3.0
# module load Python/3.11.3-GCCcore-12.3.0

JOB_NAME="my_model"
./scripts/update_job_status.sh "$JOB_NAME" "running" 0 0

# Run your model/pipeline
python my_model.py

if [ $? -eq 0 ]; then
    ./scripts/update_job_status.sh "$JOB_NAME" "completed" $SECONDS 100
else
    ./scripts/update_job_status.sh "$JOB_NAME" "failed" $SECONDS 0
fi
```

#### Option 3: Crontab with Module Loading
```bash
# In your crontab (adjust module names to match your system)
30 8 * * * module load Miniconda3/24.7.1-0 && conda activate mosquito-alert-monitor && /path/to/your/script.sh
```

#### Python Integration
```python
import json
import time
from pathlib import Path

def update_job_status(job_name, status, duration=None, progress=None):
    status_file = Path("data/status") / f"{job_name}.json"
    status_data = {
        "job_name": job_name,
        "status": status,
        "last_updated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "duration": duration,
        "progress": progress
    }
    with open(status_file, 'w') as f:
        json.dump(status_data, f, indent=2)

# Use in your model code
update_job_status("my_python_model", "running", progress=0)
# ... run model ...
update_job_status("my_python_model", "completed", duration=3600, progress=100)
```

## Dashboard Pages

- **Main Dashboard** (`index.qmd`): Overview with real-time job status and resource usage
- **Job Details** (`jobs.qmd`): Detailed information for each job including logs and configuration
- **History** (`history.qmd`): Historical performance trends and analytics
- **Alerts** (`alerts.qmd`): Alert management and notification configuration

## Configuration

### Alert Thresholds
Edit the alert logic in `alerts.qmd`:
- Failed jobs: Immediate high-severity alert
- Long-running jobs: >2 hours triggers medium-severity alert  
- Stale jobs: >24 hours without update triggers medium-severity alert

### Notifications
Configure email and Slack notifications in `config/`:
- `email_config.json`: SMTP settings for email alerts
- `slack_config.json`: Webhook settings for Slack notifications

## File Structure

```
mosquito-alert-model-monitor/
├── index.qmd                 # Main dashboard
├── jobs.qmd                  # Job details page
├── history.qmd               # Historical analysis
├── alerts.qmd                # Alerts and notifications
├── _quarto.yml               # Quarto configuration
├── styles.css                # Custom CSS styles
├── environment.yml           # Conda environment
├── data/
│   ├── status/              # Current job status files
│   ├── details/             # Additional job details
│   ├── history/             # Historical data
│   └── alerts/              # Alert logs
├── scripts/
│   ├── update_job_status.sh # Status update utility
│   └── example_model_job.sh # Example job script
├── config/
│   ├── email_config.json    # Email notification settings
│   └── slack_config.json    # Slack notification settings
└── .github/workflows/
    └── deploy-dashboard.yml  # GitHub Actions deployment
```

## Suggested Improvements Over Original Specifications

1. **GitHub Actions Rendering**: Instead of rendering on the cluster, use GitHub Actions for cleaner separation of concerns
2. **JSON-based Status API**: Structured data format for easy integration and parsing
3. **Resource Usage Monitoring**: Track CPU/memory usage of jobs
4. **Alert System**: Automated detection of problematic jobs
5. **Historical Analytics**: Track performance trends over time
6. **Modular Design**: Separate pages for different dashboard functions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with `quarto preview`
5. Submit a pull request

## License

This project is licensed under the same license as the main Mosquito Alert project.