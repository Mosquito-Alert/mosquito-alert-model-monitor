#!/bin/bash

# Generate sample data for testing the dashboard

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
STATUS_DIR="$PROJECT_DIR/data/status"

echo "Generating sample job status data..."

# Simulate a running job
cat > "$STATUS_DIR/live_classification.json" << EOF
{
  "job_name": "live_classification",
  "status": "running",
  "start_time": "$(date -u -v-2H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '2 hours ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "duration": 7200,
  "progress": 85,
  "cpu_usage": 92.3,
  "memory_usage": 3072,
  "next_scheduled_run": "$(date -u -v+22H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '+22 hours' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "log_entries": [
    "Starting live classification system",
    "Loading trained model weights",
    "Processing incoming image stream",
    "Classified 8,500 images so far",
    "Current accuracy: 89.2%"
  ],
  "config": {
    "model_path": "/models/latest_classifier.pt",
    "batch_size": 64,
    "confidence_threshold": 0.75
  }
}
EOF

# Simulate a completed job
cat > "$STATUS_DIR/weekly_report.json" << EOF
{
  "job_name": "weekly_report",
  "status": "completed",
  "start_time": "$(date -u -v-1H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '1 hour ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "end_time": "$(date -u -v-30M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '30 minutes ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "duration": 1800,
  "progress": 100,
  "cpu_usage": 25.1,
  "memory_usage": 1024,
  "next_scheduled_run": "$(date -u -v+6d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '+6 days' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "log_entries": [
    "Starting weekly analysis report",
    "Aggregating data from past 7 days",
    "Generating visualizations",
    "Report generation completed",
    "Results saved to /reports/weekly_$(date +%Y%m%d).pdf"
  ],
  "config": {
    "report_type": "weekly_summary",
    "output_format": "pdf",
    "include_charts": true
  }
}
EOF

# Simulate a pending job
cat > "$STATUS_DIR/model_training.json" << EOF
{
  "job_name": "model_training",
  "status": "pending",
  "next_scheduled_run": "$(date -u -v+30M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '+30 minutes' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "progress": 0,
  "cpu_usage": 0,
  "memory_usage": 0,
  "log_entries": [
    "Job scheduled for next training cycle",
    "Waiting for computational resources"
  ],
  "config": {
    "training_data": "/data/new_annotations_batch_47",
    "epochs": 50,
    "validation_split": 0.2
  }
}
EOF

echo "Sample data generated successfully!"
echo "You can now run 'quarto preview index.qmd' to view the dashboard with sample data."
