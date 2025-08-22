#!/bin/bash

# test_weather_integration_local.sh
# --------------------------------
# Local test to verify weather project integration with dashboard
# This simulates the weather job status updates without running actual collection

echo "=== Testing Weather Data Collector Integration (Local) ==="

# Configuration
MONITOR_REPO="/Users/palmer/research/mosquito-alert-model-monitor"
STATUS_SCRIPT="$MONITOR_REPO/scripts/update_job_status_and_push.sh"

cd "$MONITOR_REPO"

echo "✅ Testing weather job status updates..."

# Simulate different weather job statuses
echo "📡 Simulating weather-forecast job..."
$STATUS_SCRIPT "weather-forecast" "running" 120 45

sleep 2

echo "🌡️  Simulating weather-hourly job..."
$STATUS_SCRIPT "weather-hourly" "completed" 300 100

sleep 2

echo "📚 Simulating weather-historical job..."
$STATUS_SCRIPT "weather-historical" "running" 180 75

sleep 2

echo "🏘️  Simulating municipal-forecast-priority job..."
$STATUS_SCRIPT "municipal-forecast-priority" "completed" 90 100

echo ""
echo "✅ Weather job status files created:"
ls -la data/status/weather-*.json data/status/municipal-*.json 2>/dev/null || echo "No weather status files found"

echo ""
echo "📊 Sample status file content:"
if [ -f "data/status/weather-forecast.json" ]; then
    echo "--- weather-forecast.json ---"
    cat data/status/weather-forecast.json | head -10
else
    echo "⚠️  weather-forecast.json not found"
fi

echo ""
echo "🎯 Integration test complete!"
echo "📈 Check your dashboard at: file://$MONITOR_REPO/docs/index.html"
echo "🔄 If GitHub Actions is set up, the dashboard will rebuild automatically"
echo ""
echo "🚀 When you test on the cluster:"
echo "   1. Run: cd ~/research/weather-data-collector-spain"
echo "   2. Test: ./scripts/test_dashboard_integration.sh"
echo "   3. Monitor: Check dashboard for live updates"
