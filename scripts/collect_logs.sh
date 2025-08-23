#!/bin/bash

# Enhanced log collection script for dashboard integration
# This script safely copies log files from monitored projects to the dashboard

MONITOR_REPO_PATH="${1:-$HOME/research/mosquito-alert-model-monitor}"
PROJECT_NAME="${2:-unknown}"
PROJECT_LOG_DIR="${3:-logs}"

# Ensure the monitor repo exists
if [ ! -d "$MONITOR_REPO_PATH" ]; then
    echo "⚠️  Monitor repository not found at: $MONITOR_REPO_PATH"
    exit 0
fi

# Create details directory for log storage
DETAILS_DIR="$MONITOR_REPO_PATH/data/details"
mkdir -p "$DETAILS_DIR" 2>/dev/null || {
    echo "⚠️  Cannot create details directory - skipping log collection"
    exit 0
}

# Function to safely copy and truncate log files
collect_log_file() {
    local source_file="$1"
    local project_prefix="$2"
    
    if [ ! -f "$source_file" ]; then
        return 0
    fi
    
    local base_name=$(basename "$source_file" .out)
    local dest_file="$DETAILS_DIR/${project_prefix}_${base_name}_latest.log"
    
    # Copy last 500 lines to avoid huge files
    tail -500 "$source_file" > "$dest_file" 2>/dev/null || {
        echo "⚠️  Failed to copy log: $source_file"
        return 1
    }
    
    # Add header with metadata
    {
        echo "# Log file: $source_file"
        echo "# Project: $project_prefix"
        echo "# Collected: $(date)"
        echo "# Last 500 lines"
        echo "# =================================="
        echo ""
        cat "$dest_file"
    } > "${dest_file}.tmp" && mv "${dest_file}.tmp" "$dest_file"
    
    echo "✅ Collected log: $(basename "$dest_file")"
}

# Collect logs based on project
case "$PROJECT_NAME" in
    "mosquito_model_data_prep"|"prepare_malert_data")
        echo "📋 Collecting mosquito model data prep logs..."
        LOG_SOURCE_DIR="$HOME/research/mosquito_model_data_prep/logs"
        if [ -d "$LOG_SOURCE_DIR" ]; then
            for log_file in "$LOG_SOURCE_DIR"/*.out; do
                collect_log_file "$log_file" "mosquito_prep"
            done
        fi
        ;;
    "weather-"*)
        echo "📋 Collecting weather data collector logs..."
        LOG_SOURCE_DIR="$HOME/research/weather-data-collector-spain/logs"
        if [ -d "$LOG_SOURCE_DIR" ]; then
            for log_file in "$LOG_SOURCE_DIR"/*.out; do
                collect_log_file "$log_file" "weather"
            done
        fi
        ;;
    *)
        echo "📋 Collecting logs from custom directory: $PROJECT_LOG_DIR"
        if [ -d "$PROJECT_LOG_DIR" ]; then
            for log_file in "$PROJECT_LOG_DIR"/*.{out,log,txt} 2>/dev/null; do
                if [ -f "$log_file" ]; then
                    collect_log_file "$log_file" "custom"
                fi
            done
        fi
        ;;
esac

# Clean up old log files (keep only last 10 files per project)
echo "🧹 Cleaning up old log files..."
find "$DETAILS_DIR" -name "*_latest.log" -type f -print0 | \
    xargs -0 ls -t | \
    tail -n +21 | \
    xargs -r rm -f

echo "📋 Log collection complete for $PROJECT_NAME"

# Return success to avoid breaking calling scripts
exit 0
