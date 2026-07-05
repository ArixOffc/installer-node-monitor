#!/bin/bash

###############################################################################
# Node Monitoring Agent - Automatic VPS Installer
#
# Usage: sudo bash install.sh <REPO_URL>
# Example: sudo bash install.sh https://github.com/yourname/node-monitoring-dashboard.git
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/node-monitoring-agent"
SERVICE_NAME="monitor-agent"
SERVICE_USER="root"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Node Monitoring Agent - Auto Installer${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Run: sudo bash install.sh <REPO_URL>"
   exit 1
fi

# Check if repo URL provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Repository URL required${NC}"
    echo "Usage: sudo bash install.sh <REPO_URL>"
    echo "Example: sudo bash install.sh https://github.com/yourname/node-monitoring-dashboard.git"
    exit 1
fi

REPO_URL="$1"

echo -e "${YELLOW}Step 1/6: Checking prerequisites...${NC}\n"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js not found. Installing...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    echo -e "${GREEN}✓ Node.js installed${NC}\n"
else
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Node.js ${NODE_VERSION} found${NC}\n"
fi

# Check git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Git not found. Installing...${NC}"
    apt-get update
    apt-get install -y git
    echo -e "${GREEN}✓ Git installed${NC}\n"
else
    GIT_VERSION=$(git --version)
    echo -e "${GREEN}✓ ${GIT_VERSION}${NC}\n"
fi

echo -e "${YELLOW}Step 2/6: Creating installation directory...${NC}\n"

# Create install directory
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Directory $INSTALL_DIR already exists${NC}"
    read -p "Remove and reinstall? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}✓ Directory removed${NC}\n"
    else
        echo -e "${YELLOW}Keeping existing installation${NC}\n"
    fi
fi

if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    echo -e "${GREEN}✓ Created $INSTALL_DIR${NC}\n"
fi

echo -e "${YELLOW}Step 3/6: Cloning repository...${NC}\n"

# Clone or update repo
if [ -d "$INSTALL_DIR/.git" ]; then
    echo -e "${YELLOW}Repository already exists, pulling latest...${NC}"
    cd "$INSTALL_DIR"
    git pull origin main 2>/dev/null || git pull origin master
else
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
echo -e "${GREEN}✓ Repository cloned/updated${NC}\n"

echo -e "${YELLOW}Step 4/6: Installing Node dependencies...${NC}\n"

# Navigate to agent folder and install
cd agent
npm install
echo -e "${GREEN}✓ Dependencies installed${NC}\n"

echo -e "${YELLOW}Step 5/6: Setting up configuration...${NC}\n"

# Copy .env.example to .env if not exists
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ Created .env from template${NC}"
    else
        echo -e "${YELLOW}⚠ .env.example not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ .env already exists, skipping${NC}"
fi

echo ""

echo -e "${YELLOW}Step 6/6: Setting up systemd service...${NC}\n"

# Copy systemd service file
if [ -f "monitor-agent.service" ]; then
    cp monitor-agent.service /etc/systemd/system/${SERVICE_NAME}.service
    sed -i "s|WorkingDirectory=/opt/node-monitoring-agent|WorkingDirectory=${INSTALL_DIR}/agent|g" \
        /etc/systemd/system/${SERVICE_NAME}.service
    sed -i "s|ExecStart=/usr/bin/node /opt/node-monitoring-agent/monitor-agent.js|ExecStart=/usr/bin/node ${INSTALL_DIR}/agent/monitor-agent.js|g" \
        /etc/systemd/system/${SERVICE_NAME}.service

    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}

    echo -e "${GREEN}✓ Systemd service installed${NC}\n"
else
    echo -e "${RED}✗ monitor-agent.service not found${NC}\n"
fi

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${BLUE}Next Steps:${NC}\n"

echo -e "1. ${YELLOW}Edit configuration file:${NC}"
echo -e "   ${BLUE}nano ${INSTALL_DIR}/agent/.env${NC}\n"

echo -e "   Required variables:"
echo -e "   ${BLUE}BACKEND_URL=${NC}https://your-vercel-project.vercel.app"
echo -e "   ${BLUE}API_KEY=${NC}your-api-key-from-add-node"
echo -e "   ${BLUE}INTERVAL=${NC}30000\n"

echo -e "2. ${YELLOW}Start the service:${NC}"
echo -e "   ${BLUE}sudo systemctl start ${SERVICE_NAME}${NC}\n"

echo -e "3. ${YELLOW}Check service status:${NC}"
echo -e "   ${BLUE}sudo systemctl status ${SERVICE_NAME}${NC}\n"

echo -e "4. ${YELLOW}View live logs:${NC}"
echo -e "   ${BLUE}sudo journalctl -u ${SERVICE_NAME} -f${NC}\n"

echo -e "${YELLOW}Configuration file location:${NC}"
echo -e "${BLUE}${INSTALL_DIR}/agent/.env${NC}\n"

echo -e "${YELLOW}Service file location:${NC}"
echo -e "${BLUE}/etc/systemd/system/${SERVICE_NAME}.service${NC}\n"

echo -e "${GREEN}Installation files are ready at:${NC}"
echo -e "${BLUE}${INSTALL_DIR}${NC}\n"
