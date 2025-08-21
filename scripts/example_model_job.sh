#!/bin/bash

# Example cronjob script for species classification model
# This should be adapted for your specific model/pipeline

# Set up environment for HPC cluster
# Load required modules (adjust module names/versions as needed)
module load Miniconda3/24.7.1-0

# Activate conda environment
conda activate mosquito-alert-monitor

# Alternative: If you have other required modules
# module load Python/3.11.3-GCCcore-12.3.0
# module load R/4.3.2-gfbf-2023a
# module load Miniconda3/24.7.1-0

# Set working directory for your model
cd /path/to/your/model/directory

# Get script directory for status updates
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_SCRIPT="$SCRIPT_DIR/update_job_status_and_push.sh"

JOB_NAME="species_classification_model"
START_TIME=$(date +%s)

# Update status to running (this will also push to git and trigger dashboard rebuild)
$STATUS_SCRIPT "$JOB_NAME" "running" 0 0

# Run your actual model/pipeline here
echo "Starting species classification model training..."

# Example model execution (replace with your actual commands)
python -c "
import time
import sys

# Simulate model training with progress updates
for i in range(1, 11):
    print(f'Training epoch {i}/10')
    time.sleep(5)  # Simulate work
    progress = i * 10
    # Update progress (you could call the status script here too)
    
print('Model training completed successfully')
"

# Check if the model succeeded
if [ $? -eq 0 ]; then
    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Update status to completed (this will push to git and trigger dashboard rebuild)
    $STATUS_SCRIPT "$JOB_NAME" "completed" "$DURATION" 100
    
    echo "Model training completed successfully"
else
    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Update status to failed (this will push to git and trigger dashboard rebuild)
    $STATUS_SCRIPT "$JOB_NAME" "failed" "$DURATION" 0
    
    echo "Model training failed"
    exit 1
fi

# Dashboard will rebuild automatically via GitHub Actions - no manual steps needed!
