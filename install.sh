#!/bin/bash

###############################################################################
# 🖥️ Node Monitoring Agent - Interactive Installer
#
# Cara pakai: sudo bash install.sh
# Atau:       sudo bash install.sh https://github.com/username/repo.git
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_URL="${1:-https://github.com/ArixOffc/installer-node-monitor.git}"
INSTALL_DIR="/opt/node-monitoring-agent"
SERVICE_NAME="monitor-agent"

echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     🖥️  Node Monitoring Agent - Interactive Installer    ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

# ─── Check root ──────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}✗ Error: Harus dijalankan sebagai root (sudo)${NC}"
   echo "  sudo bash install.sh"
   exit 1
fi

# ─── Input data dari user ────────────────────────────────────────────────────
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Masukkan konfigurasi monitoring agent${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Backend URL
while [ -z "$BACKEND_URL" ]; do
    echo -ne "${BLUE}🌐 Backend URL${NC}\n"
    echo -ne "  (Contoh: https://monitoring-node-xxxxx.vercel.app)\n"
    echo -ne "  ${CYAN}▶ ${NC}"
    read -r BACKEND_URL
    if [ -z "$BACKEND_URL" ]; then
        echo -e "${RED}  ✗ Backend URL tidak boleh kosong!${NC}\n"
    elif [[ ! "$BACKEND_URL" =~ ^https?:// ]]; then
        echo -e "${RED}  ✗ URL harus diawali http:// atau https://${NC}\n"
        BACKEND_URL=""
    fi
done

# API Key
while [ -z "$API_KEY" ]; do
    echo -ne "\n${BLUE}🔑 API Key${NC}\n"
    echo -ne "  (Dari dashboard admin → Add Node)\n"
    echo -ne "  ${CYAN}▶ ${NC}"
    read -r API_KEY
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}  ✗ API Key tidak boleh kosong!${NC}"
    fi
done

# Interval (dalam detik, default 10)
echo -ne "\n${BLUE}⏱️  Interval update (detik)${NC}\n"
echo -ne "  (Default: 10, Rekomendasi: 3-30 detik)\n"
echo -ne "  ${CYAN}▶ ${NC}"
read -r INTERVAL_INPUT
INTERVAL="${INTERVAL_INPUT:-10}"
INTERVAL_MS=$((INTERVAL * 1000))

echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Konfirmasi pengaturan${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}✓${NC} Backend URL:  ${CYAN}$BACKEND_URL${NC}"
echo -e "  ${GREEN}✓${NC} API Key:      ${CYAN}${API_KEY:0:20}...${API_KEY: -8}${NC}"
echo -e "  ${GREEN}✓${NC} Interval:     ${CYAN}${INTERVAL} detik (${INTERVAL_MS}ms)${NC}"
echo ""

# ─── Install Prerequisites ──────────────────────────────────────────────────
echo -e "\n${YELLOW}[1/6] Memeriksa prerequisites...${NC}"

if ! command -v node &> /dev/null; then
    echo -e "  ${YELLOW}⚠ Node.js belum terinstall. Menginstall...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    echo -e "  ${GREEN}✓ Node.js $(node -v) terinstall${NC}"
else
    echo -e "  ${GREEN}✓ Node.js $(node -v)${NC}"
fi

if ! command -v git &> /dev/null; then
    echo -e "  ${YELLOW}⚠ Git belum terinstall. Menginstall...${NC}"
    apt-get update && apt-get install -y git
    echo -e "  ${GREEN}✓ Git terinstall${NC}"
else
    echo -e "  ${GREEN}✓ $(git --version)${NC}"
fi

# ─── Clone repository ───────────────────────────────────────────────────────
echo -e "\n${YELLOW}[2/6] Menyiapkan direktori...${NC}"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "  ${YELLOW}⚠ Direktori $INSTALL_DIR sudah ada${NC}"
    echo -ne "  Hapus dan install ulang? (y/n) ${CYAN}▶${NC} "
    read -r REINSTALL
    if [[ "$REINSTALL" =~ ^[Yy]$ ]]; then
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        rm -rf "$INSTALL_DIR"
        echo -e "  ${GREEN}✓ Direktori lama dihapus${NC}"
    else
        echo -e "  ${YELLOW}⚠ Menggunakan direktori yang sudah ada${NC}"
    fi
fi

if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
fi

echo -e "\n${YELLOW}[3/6] Meng-clone repository...${NC}"

if [ ! -d "$INSTALL_DIR/.git" ]; then
    git clone "$REPO_URL" "$INSTALL_DIR"
else
    cd "$INSTALL_DIR" && git pull
fi
echo -e "  ${GREEN}✓ Repository siap${NC}"

# ─── Install dependencies ───────────────────────────────────────────────────
echo -e "\n${YELLOW}[4/6] Menginstall dependencies...${NC}"

# Cari package.json (bisa di root atau di agent/)
if [ -f "$INSTALL_DIR/package.json" ]; then
    cd "$INSTALL_DIR"
    npm install
elif [ -f "$INSTALL_DIR/agent/package.json" ]; then
    cd "$INSTALL_DIR/agent"
    npm install
else
    echo -e "${RED}✗ package.json tidak ditemukan!${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓ Dependencies terinstall${NC}"

# ─── Buat .env ──────────────────────────────────────────────────────────────
echo -e "\n${YELLOW}[5/6] Membuat konfigurasi (.env)...${NC}"

# Tentukan direktori agent
AGENT_DIR="$INSTALL_DIR"
if [ -f "$INSTALL_DIR/agent/monitor-agent.js" ]; then
    AGENT_DIR="$INSTALL_DIR/agent"
fi

# Tentukan path monitor-agent.js
if [ -f "$INSTALL_DIR/monitor-agent.js" ]; then
    SCRIPT_PATH="$INSTALL_DIR/monitor-agent.js"
elif [ -f "$INSTALL_DIR/agent/monitor-agent.js" ]; then
    SCRIPT_PATH="$INSTALL_DIR/agent/monitor-agent.js"
fi

ENV_FILE="$AGENT_DIR/.env"

cat > "$ENV_FILE" << EOF
# Konfigurasi Monitoring Agent
# Dibuat: $(date)

# URL backend Vercel
BACKEND_URL=${BACKEND_URL}

# API Key dari dashboard admin (Add Node)
API_KEY=${API_KEY}

# Interval report (dalam milidetik)
INTERVAL=${INTERVAL_MS}
EOF

echo -e "  ${GREEN}✓ .env berhasil dibuat${NC}"
echo -e "  📄 $ENV_FILE"

# ─── Setup Systemd Service ────────────────────────────────────────────────
echo -e "\n${YELLOW}[6/6] Setup systemd service...${NC}"

if [ -n "$SCRIPT_PATH" ]; then
    # Buat service file yang benar path-nya
    WORKDIR="$(dirname "$SCRIPT_PATH")"

    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Node Monitoring Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${WORKDIR}
ExecStart=/usr/bin/node ${SCRIPT_PATH}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl restart "$SERVICE_NAME"

    echo -e "  ${GREEN}✓ Systemd service: ${SERVICE_NAME}${NC}"
    echo -e "  📄 /etc/systemd/system/${SERVICE_NAME}.service"
else
    echo -e "${RED}✗ monitor-agent.js tidak ditemukan!${NC}"
    exit 1
fi

# ─── Selesai ────────────────────────────────────────────────────────────────
sleep 1
STATUS=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "inactive")

echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          ✅  INSTALLASI SELESAI!                        ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Status Service:  $(if [ "$STATUS" = "active" ]; then echo "${GREEN}● Running${NC}"; else echo "${RED}● Stopped${NC}"; fi)"
echo -e "  Backend URL:     ${CYAN}${BACKEND_URL}${NC}"
echo -e "  Interval:        ${CYAN}${INTERVAL} detik${NC}"
echo -e ""
echo -e "${YELLOW}  Perintah Penting:${NC}"
echo -e "  ${GREEN}•${NC} Cek status:    ${CYAN}sudo systemctl status ${SERVICE_NAME}${NC}"
echo -e "  ${GREEN}•${NC} Lihat log:     ${CYAN}sudo journalctl -u ${SERVICE_NAME} -f${NC}"
echo -e "  ${GREEN}•${NC} Restart:       ${CYAN}sudo systemctl restart ${SERVICE_NAME}${NC}"
echo -e "  ${GREEN}•${NC} Stop:          ${CYAN}sudo systemctl stop ${SERVICE_NAME}${NC}"
echo -e "  ${GREEN}•${NC} Start:         ${CYAN}sudo systemctl start ${SERVICE_NAME}${NC}"
echo -e ""
echo -e "${YELLOW}  Konfigurasi:${NC}"
echo -e "  ${CYAN}${ENV_FILE}${NC}"
echo -e ""

if [ "$STATUS" = "active" ]; then
    echo -e "  ${GREEN}✓ Agent BERHASIL berjalan!${NC}"
    echo -e "  ${GREEN}✓ Cek log dalam 3 detik:${NC}"
    echo -e "    ${CYAN}sudo journalctl -u ${SERVICE_NAME} -f --since \"10 seconds ago\"${NC}"
    echo -e ""
    sleep 2
    journalctl -u "$SERVICE_NAME" --since "5 seconds ago" --no-pager -n 5
    echo ""
else
    echo -e "  ${RED}✗ Service gagal start. Cek log:${NC}"
    echo -e "    ${CYAN}sudo journalctl -u ${SERVICE_NAME} -n 30${NC}"
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}       🚀 Monitoring Agent siap digunakan!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
