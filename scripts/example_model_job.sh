#!/bin/bash

# Example cronjob script for species classification model
# This should be adapted for your specific model/pipeline

# Set up environment
export PATH="/path/to/your/conda/bin:$PATH"
source activate your-environment-name

# Set working directory
cd /path/to/your/model/directory

# Get script directory for status updates
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_SCRIPT="$SCRIPT_DIR/update_job_status.sh"

JOB_NAME="species_classification_model"
START_TIME=$(date +%s)

# Update status to running
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
    
    # Update status to completed
    $STATUS_SCRIPT "$JOB_NAME" "completed" "$DURATION" 100
    
    echo "Model training completed successfully"
else
    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Update status to failed
    $STATUS_SCRIPT "$JOB_NAME" "failed" "$DURATION" 0
    
    echo "Model training failed"
    exit 1
fi

# Trigger dashboard rebuild (optional - only if rendering locally)
# cd /path/to/mosquito-alert-model-monitor
# quarto render
# git add docs/
# git commit -m "Update dashboard after $JOB_NAME completion"
# git push
