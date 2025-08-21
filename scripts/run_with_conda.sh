#!/bin/bash

# Wrapper script to run commands with conda environment activated
# Usage: ./run_with_conda.sh <script_to_run> [args...]

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Set up conda (adjust path as needed)
# Try to find conda installation
if command -v conda >/dev/null 2>&1; then
    # conda is in PATH
    source "$(conda info --base)/etc/profile.d/conda.sh"
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    # Common miniconda location
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    # Common anaconda location
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
else
    echo "Error: Could not find conda installation."
    echo "Please edit this script to set the correct conda path."
    exit 1
fi

# Activate the environment
conda activate mosquito-alert-monitor

if [ $? -ne 0 ]; then
    echo "Error: Could not activate mosquito-alert-monitor environment."
    echo "Make sure it's created with: conda env create -f environment.yml"
    exit 1
fi

# Change to project directory
cd "$PROJECT_DIR"

# Run the requested script with all arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <script_to_run> [args...]"
    echo "Example: $0 scripts/update_job_status.sh my_job running 60 50"
    exit 1
fi

# Execute the command
exec "$@"
