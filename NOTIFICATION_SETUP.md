# Notification Setup Guide

## 📢 **Current Status: Not Implemented**

> **⚠️ Important**: The notification system is **not currently implemented**. The configuration files in `config/` are placeholders for future development. This guide explains how to set up notifications when the system is implemented.

## 📋 **Configuration Files Overview**

The dashboard includes template configuration files for future notification features:

- **`config/email_config.json`**: Email notification settings (SMTP)
- **`config/slack_config.json`**: Slack webhook notification settings

These files are:
- ✅ **Templates only** - Not currently used by any scripts
- ✅ **Git-ignored** - Won't be tracked in version control
- ✅ **Cluster-specific** - You'd copy and configure them on your cluster

## 🔧 **Implementation Architecture**

When implemented, notifications would work as follows:

### **📡 Cluster-Based Notifications (Recommended)**
- Notifications sent directly from the cluster where jobs run
- Real-time alerts when jobs fail or encounter issues
- Rich context with access to logs and system status
- No dependency on GitHub Actions availability

### **🤖 GitHub Actions Summaries (Optional)**
- Daily/weekly summary reports
- Dashboard build status notifications
- Repository health alerts

## 🛠️ **Setup Instructions (Future Implementation)**

### **1. Slack Notifications**

**A. Create Slack App:**
1. Go to https://api.slack.com/apps
2. Click "Create New App" → "From scratch"
3. Name: "Mosquito Alert Monitor", choose your workspace
4. Go to "Incoming Webhooks" → Enable incoming webhooks
5. Click "Add New Webhook to Workspace"
6. Choose channel (e.g., `#mosquito-alert-monitoring`)
7. Copy the webhook URL

**B. Configure Slack on Cluster:**
```bash
# Copy template to cluster
cp config/slack_config.json /path/to/cluster/config/
```

Edit `slack_config.json`:
```json
{
  "enabled": true,
  "webhook_url": "https://hooks.slack.com/services/YOUR/ACTUAL/WEBHOOK",
  "channel": "#mosquito-alert-monitoring",
  "username": "Mosquito Alert Monitor",
  "alert_levels": ["high", "medium"],
  "message_template": {
    "high": "🚨 *HIGH ALERT*: {message}",
    "medium": "⚠️ *MEDIUM ALERT*: {message}",
    "low": "ℹ️ *LOW ALERT*: {message}"
  }
}
```

**C. Test Connectivity:**
```bash
# Test webhook from cluster
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"🧪 Test from cluster: Mosquito Alert Monitor"}' \
  YOUR_SLACK_WEBHOOK_URL
```

### **2. Email Notifications**

**A. Email Service Setup:**
- **Gmail**: Enable 2FA, create App Password
- **Institutional Email**: Get SMTP settings from IT
- **SendGrid/Mailgun**: Create API credentials

**B. Configure Email on Cluster:**
```bash
# Copy template to cluster
cp config/email_config.json /path/to/cluster/config/
```

Edit `email_config.json`:
```json
{
  "enabled": true,
  "smtp_server": "smtp.gmail.com",
  "smtp_port": 587,
  "sender_email": "your-alerts@example.com",
  "sender_password": "your-app-password",
  "recipients": [
    "researcher1@example.com",
    "researcher2@example.com"
  ],
  "alert_levels": ["high", "medium"],
  "subject_template": "[Mosquito Alert] {level}: {job_name}",
  "use_tls": true
}
```

**C. Test SMTP Connection:**
```bash
# Test SMTP access from cluster
telnet smtp.gmail.com 587
```

### **3. Cluster Network Requirements**

**Outbound Access Needed:**
- **Slack**: HTTPS (port 443) to `hooks.slack.com`
- **Email**: SMTP (port 587/465) to your email provider
- **Proxy**: Configure if behind institutional firewall

**Test Commands:**
```bash
# Check HTTPS access
curl -I https://hooks.slack.com

# Check SMTP access  
nc -zv smtp.gmail.com 587

# Check proxy settings
echo $HTTP_PROXY
echo $HTTPS_PROXY
```

## 🎯 **Alert Triggers (When Implemented)**

Notifications would be sent for:

### **High Severity (Immediate)**
- ✅ Job failures with error codes
- ✅ System resource critical (>90% disk, >95% memory)
- ✅ Dashboard sync failures

### **Medium Severity (Hourly Summary)**
- ✅ Long-running jobs (>2 hours)
- ✅ Stale jobs (>24 hours without update)
- ✅ Resource warnings (>80% disk, >90% memory)

### **Low Severity (Daily Summary)**
- ✅ Job completion summaries
- ✅ Performance trends
- ✅ System health reports

## 📱 **Notification Examples**

### **Slack Message Format:**
```
🚨 HIGH ALERT: Job Failed
📊 Job: prepare_malert_data
⏰ Failed at: 2025-08-23 14:30:15
💥 Error: Process killed (OOM)
🔗 Dashboard: https://mosquito-alert.github.io/mosquito-alert-model-monitor/
📋 Logs: /cluster/logs/prepare_malert_data.log
```

### **Email Subject/Body:**
```
Subject: [Mosquito Alert] HIGH: prepare_malert_data Failed

Job prepare_malert_data has failed with the following details:

Time: 2025-08-23 14:30:15
Duration: 45 minutes
Error: Out of memory (OOM)
Exit Code: 137

View Dashboard: https://mosquito-alert.github.io/mosquito-alert-model-monitor/
Check Logs: /cluster/logs/prepare_malert_data.log

This is an automated message from Mosquito Alert Monitor.
```

## 🔒 **Security Considerations**

### **Webhook Security:**
- Store webhook URLs in protected config files (mode 600)
- Rotate webhook URLs periodically
- Use dedicated Slack channels with limited access

### **Email Security:**
- Use app passwords, not account passwords
- Store credentials in protected files
- Consider institutional email over personal accounts

### **Cluster Security:**
- Keep config files in user directories (not shared)
- Use appropriate file permissions
- Don't commit real credentials to git

## 🚀 **Implementation Status**

**✅ Ready for Development:**
- Configuration templates created
- Architecture designed
- Setup instructions documented

**❌ Not Yet Implemented:**
- Notification sending scripts
- Integration with job status updates
- Alert threshold monitoring
- Config file reading functions

## 📞 **Getting Help**

If you want to implement the notification system:

1. **Check cluster network access** using the test commands above
2. **Set up Slack/email credentials** following this guide
3. **Request implementation** of the notification scripts
4. **Test with dummy notifications** before enabling alerts

The notification system is designed to be modular - you can enable Slack only, email only, or both, and configure which alert levels you want to receive.
