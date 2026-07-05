#!/bin/bash

###############################################################################
# Quick Setup Guide - One-Line VPS Installation
#
# This script automates the entire agent setup on your VPS.
# Just 3 simple steps:
#
# 1. Run installer (auto-installs Node.js, Git, dependencies)
# 2. Edit .env file (add BACKEND_URL and API_KEY)
# 3. Start service (systemd auto-starts on reboot)
#
###############################################################################

# STEP 1: Run Installer (One command, takes ~2-3 minutes)
# Replace REPO_URL with your GitHub URL
sudo bash install.sh https://github.com/yourname/node-monitoring-dashboard.git

# Wait for installer to complete...
# You should see: "Installation Complete!"

###############################################################################
# STEP 2: Edit Configuration
###############################################################################

# Open the .env file in nano editor
sudo nano /opt/node-monitoring-agent/agent/.env

# You'll see:
#   BACKEND_URL=https://your-vercel-project.vercel.app
#   API_KEY=your-api-key-from-add-node
#   INTERVAL=30000

# EDIT these values:
# 1. BACKEND_URL = Your Vercel project URL
#    Example: https://monitoring-node-abc123.vercel.app
#
# 2. API_KEY = From your dashboard "Add Node" step
#    (The long key shown when you added the node)
#
# 3. INTERVAL = How often to report (30000 = 30 seconds)

# Save: Press Ctrl+X → Y → Enter

###############################################################################
# STEP 3: Start Service
###############################################################################

# Start the monitoring service
sudo systemctl start monitor-agent

# Check if it's running
sudo systemctl status monitor-agent

# View live logs (watch metrics being sent)
sudo journalctl -u monitor-agent -f

# You should see: "Metrics reported successfully"
# If you see that, it's working! ✅

###############################################################################
# USEFUL COMMANDS
###############################################################################

# Status (is it running?)
sudo systemctl status monitor-agent

# Start service
sudo systemctl start monitor-agent

# Stop service
sudo systemctl stop monitor-agent

# Restart service
sudo systemctl restart monitor-agent

# View logs
sudo journalctl -u monitor-agent -f

# View last 50 log lines
sudo journalctl -u monitor-agent -n 50

# View logs from last hour
sudo journalctl -u monitor-agent --since "1 hour ago"

# Auto-start on reboot? (already enabled by installer)
sudo systemctl enable monitor-agent

# Disable auto-start
sudo systemctl disable monitor-agent

###############################################################################
# TROUBLESHOOTING
###############################################################################

# "Connection refused" error?
# → Check BACKEND_URL is correct (https://your-project.vercel.app)
# → Verify your VPS can access internet

# "Invalid API_KEY" error?
# → Copy API key exactly from "Add Node" step
# → Don't add extra spaces or quotes

# "Service won't start" error?
# → Check logs: sudo journalctl -u monitor-agent -n 50
# → Verify .env file format (no extra spaces)

# "Node.js not found" error?
# → Installer might have failed
# → Run: node --version
# → If not found, manually install: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash - && sudo apt-get install -y nodejs

###############################################################################
# THAT'S IT!
###############################################################################

# Your VPS is now monitoring and sending metrics to your dashboard.
# Check your Vercel dashboard to see the node status change to "online"!

# The agent will:
# ✅ Auto-start on VPS reboot
# ✅ Auto-restart if it crashes
# ✅ Report metrics every 30 seconds (configurable)
# ✅ Continue running in background
