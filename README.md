# Mosquito Alert Model Monitor

A Quarto dashboard for monitoring automated data wrangling tasks and models running on computational clusters.

## Features

- **Real-time Status Monitoring**: Track the status, progress, and performance of multiple jobs
- **Interactive Dashboard**: Built with Quarto and Shiny for dynamic, real-time updates
- **Alert System**: Automatic detection of failed jobs, long-running tasks, and stale processes
- **Historical Tracking**: Performance trends and success rate analysis over time
- **Resource Monitoring**: CPU and memory usage tracking for each job
- **GitHub Pages Deployment**: Automated deployment via GitHub Actions

## Quick Start

### 1. Setup Environment

```bash
# Clone the repository
git clone https://github.com/Mosquito-Alert/mosquito-alert-model-monitor.git
cd mosquito-alert-model-monitor

# Create conda environment
conda env create -f environment.yml
conda activate mosquito-alert-monitor

# Or install dependencies manually
conda install -c conda-forge r-base r-shiny r-dt r-plotly r-jsonlite r-lubridate r-dplyr r-purrr r-stringr r-ggplot2 quarto
```

### 2. Configure Your Jobs

Each job should write status information to JSON files in the `data/status/` directory. Use the provided script:

```bash
# From your cronjob or model script
./scripts/update_job_status.sh "my_job_name" "running" 1800 75
```

### 3. Run the Dashboard Locally

```bash
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

#### Bash Script Integration
```bash
#!/bin/bash
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