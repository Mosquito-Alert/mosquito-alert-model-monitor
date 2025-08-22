#!/bin/bash

# Demo script showing how to use fast cluster-based dashboard rebuilds
# This demonstrates the performance difference between methods

echo "=== Mosquito Alert Model Monitor - Fast Update Demo ==="
echo ""

# Set the environment variable to enable cluster building
export USE_CLUSTER_BUILD=true

echo "🚀 Updating job status with FAST cluster building enabled..."
echo "Expected time: < 1 minute (vs 30+ minutes with GitHub Actions)"
echo ""

# Example: Update a job status (you can modify these parameters)
JOB_NAME="${1:-weather-data-collector-spain}"
STATUS="${2:-running}"
DURATION="${3:-45}"
PROGRESS="${4:-75}"

echo "Updating $JOB_NAME -> $STATUS (${DURATION}s, ${PROGRESS}%)"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the status update with cluster building
"$SCRIPT_DIR/update_job_status_and_push.sh" "$JOB_NAME" "$STATUS" "$DURATION" "$PROGRESS"

echo ""
echo "=== Performance Comparison ==="
echo "🐌 GitHub Actions: 30+ minutes (with optimizations: ~10-15 minutes)"
echo "🚀 Cluster Building: < 1 minute"
echo "📈 Speed improvement: 30x - 60x faster!"
echo ""
echo "To use cluster building by default, add this to your environment:"
echo "export USE_CLUSTER_BUILD=true"
