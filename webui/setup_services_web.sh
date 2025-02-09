#!/bin/bash

# Exit on any error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (with sudo)${NC}"
    exit 1
fi

# Get the actual user who ran sudo (not root)
SUDO_USER="${SUDO_USER:-$USER}"
if [ "$SUDO_USER" = "root" ]; then
    echo -e "${RED}Please run with sudo, not as root directly${NC}"
    exit 1
fi

# Check for .env file
ENV_FILE=".env"
ENV_TEMPLATE=".env.template"

if [ ! -f "$ENV_FILE" ]; then
    if [ ! -f "$ENV_TEMPLATE" ]; then
        echo -e "${RED}Neither .env nor .env.template found. Please ensure at least .env.template exists.${NC}"
        exit 1
    fi
    echo -e "${YELLOW}No .env file found. Creating from template...${NC}"
    cp "$ENV_TEMPLATE" "$ENV_FILE"
    echo -e "${GREEN}.env file created. Please review and modify if needed.${NC}"
    exit 0
fi

# Source the .env file
set -a
source "$ENV_FILE"
set +a

# Service names if not set in .env
BACKEND_SERVICE_NAME=${BACKEND_SERVICE_NAME:-awsight-web-backend}
FRONTEND_SERVICE_NAME=${FRONTEND_SERVICE_NAME:-awsight-web-front}

# Install requirements
echo -e "${BLUE}=== Installing Required System Packages ===${NC}"

# Update package list
echo -e "${YELLOW}Updating package list...${NC}"
apt update

# Install npm if not already installed
if ! command -v npm &> /dev/null; then
    echo -e "${YELLOW}npm not found. Installing npm...${NC}"
    apt install -y npm
    echo -e "${GREEN}npm installed successfully${NC}"
else
    echo -e "${GREEN}npm is already installed${NC}"
fi

# Install Python venv if not already installed
echo -e "\n${YELLOW}Checking Python venv installation...${NC}"
if ! dpkg -l | grep -q "python${PYTHON_VERSION}-venv"; then
    echo -e "${YELLOW}Python venv not found. Installing python${PYTHON_VERSION}-venv...${NC}"
    apt install -y "python${PYTHON_VERSION}-venv"
    echo -e "${GREEN}Python venv installed successfully${NC}"
else
    echo -e "${GREEN}Python venv is already installed${NC}"
fi

# Get user's group
USER_GROUP=$(id -gn "$SUDO_USER")

# Print setup information
echo -e "${BLUE}=== AWsight Web Services Setup ===${NC}"
echo -e "${GREEN}Setting up services with following configuration:${NC}"
echo -e "User: ${YELLOW}$SUDO_USER${NC}"
echo -e "Group: ${YELLOW}$USER_GROUP${NC}"
echo -e "Backend Directory: ${YELLOW}$BACKEND_DIR${NC}"
echo -e "Frontend Directory: ${YELLOW}$FRONTEND_DIR${NC}"
echo -e "Backend Virtual Environment: ${YELLOW}$BACKEND_VENV${NC}"
echo -e "Backend Port: ${YELLOW}$BACKEND_PORT${NC}"
echo -e "Backend Service Name: ${YELLOW}$BACKEND_SERVICE_NAME${NC}"
echo -e "Frontend Service Name: ${YELLOW}$FRONTEND_SERVICE_NAME${NC}"

# Verify directories exist
if [ ! -d "$BACKEND_DIR" ]; then
    echo -e "${RED}Error: Backend directory $BACKEND_DIR does not exist${NC}"
    exit 1
fi

if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${RED}Error: Frontend directory $FRONTEND_DIR does not exist${NC}"
    exit 1
fi

# Confirm with user
read -p "Continue with this configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Setup cancelled${NC}"
    exit 1
fi

# Setup Python virtual environment and install packages
echo -e "\n${BLUE}=== Setting up Python Virtual Environment ===${NC}"
if [ ! -d "$BACKEND_VENV" ]; then
    echo -e "${YELLOW}Creating new virtual environment at $BACKEND_VENV${NC}"
    sudo -u "$SUDO_USER" "python${PYTHON_VERSION}" -m venv "$BACKEND_VENV"
    echo -e "${GREEN}Virtual environment created successfully${NC}"
fi

# Install Python packages
echo -e "\n${BLUE}=== Installing Python Packages ===${NC}"
sudo -u "$SUDO_USER" "$BACKEND_VENV/bin/pip" install --upgrade pip
sudo -u "$SUDO_USER" "$BACKEND_VENV/bin/pip" install \
    fastapi[all] \
    uvicorn \
    python-dotenv \
    anthropic \
    pytest \
    requests \
    pydantic \
    typing-extensions

# Setup Backend Service
echo -e "\n${BLUE}=== Setting up Backend Service ===${NC}"
cat > /etc/systemd/system/$BACKEND_SERVICE_NAME.service << EOL
[Unit]
Description=AWsight Web Backend FastAPI Application
After=network.target

[Service]
User=$SUDO_USER
Group=$USER_GROUP
WorkingDirectory=$BACKEND_DIR
Environment="PATH=$BACKEND_VENV/bin"
Environment="PYTHONPATH=$BACKEND_DIR"
ExecStart=$BACKEND_VENV/bin/uvicorn main:app --host 0.0.0.0 --port $BACKEND_PORT

Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

echo -e "${GREEN}Backend service file created${NC}"

# Setup Frontend Service
echo -e "\n${BLUE}=== Setting up Frontend Service ===${NC}"
cat > /etc/systemd/system/$FRONTEND_SERVICE_NAME.service << EOL
[Unit]
Description=AWsight Web Frontend Vite Application
After=network.target

[Service]
Type=simple
User=${SUDO_USER}
Group=${USER_GROUP}
WorkingDirectory=${FRONTEND_DIR}
Environment=NODE_ENV=${NODE_ENV}
ExecStart=/usr/bin/npm run ${NPM_COMMAND}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

echo -e "${GREEN}Frontend service file created${NC}"

# Install frontend dependencies and build
echo -e "\n${BLUE}=== Setting up Frontend Application ===${NC}"
cd "$FRONTEND_DIR"

# Install global npm packages if needed
echo -e "${YELLOW}Installing global npm packages...${NC}"
sudo npm install -g pm2

# Install project dependencies
echo -e "${YELLOW}Installing project dependencies...${NC}"
sudo -u "$SUDO_USER" npm install \
    @types/react \
    @types/react-dom \
    @vitejs/plugin-react \
    autoprefixer \
    postcss \
    tailwindcss \
    typescript \
    vite

# Build the frontend application
echo -e "${YELLOW}Building the frontend application...${NC}"
sudo -u "$SUDO_USER" npm run build

# Enable and start services
echo -e "\n${BLUE}=== Starting Services ===${NC}"
systemctl daemon-reload

echo -e "${GREEN}Enabling and starting backend service...${NC}"
systemctl enable $BACKEND_SERVICE_NAME
systemctl start $BACKEND_SERVICE_NAME

echo -e "${GREEN}Enabling and starting frontend service...${NC}"
systemctl enable $FRONTEND_SERVICE_NAME
systemctl start $FRONTEND_SERVICE_NAME

# Final status check
echo -e "\n${BLUE}=== Service Status ===${NC}"
echo -e "${YELLOW}Backend Service Status:${NC}"
systemctl status $BACKEND_SERVICE_NAME --no-pager
echo -e "\n${YELLOW}Frontend Service Status:${NC}"
systemctl status $FRONTEND_SERVICE_NAME --no-pager

# Print helpful information
echo -e "\n${BLUE}=== Setup Complete! ===${NC}"
echo -e "${GREEN}Useful commands:${NC}"
echo -e "Backend service management:"
echo -e "  ${YELLOW}sudo systemctl start $BACKEND_SERVICE_NAME${NC}"
echo -e "  ${YELLOW}sudo systemctl stop $BACKEND_SERVICE_NAME${NC}"
echo -e "  ${YELLOW}sudo systemctl restart $BACKEND_SERVICE_NAME${NC}"
echo -e "  ${YELLOW}sudo systemctl status $BACKEND_SERVICE_NAME${NC}"
echo -e "  ${YELLOW}sudo journalctl -u $BACKEND_SERVICE_NAME -f${NC}"
echo -e "\nFrontend service management:"
echo -e "  ${YELLOW}sudo systemctl start $FRONTEND_SERVICE_NAME${NC}"
echo -e "  ${YELLOW}sudo systemctl stop $FRONTEND_SERVICE_NAME${NC}"
echo -e "  ${YELLOW}sudo systemctl restart $FRONTEND_SERVICE_NAME${NC}"
echo -e "  ${YELLOW}sudo systemctl status $FRONTEND_SERVICE_NAME${NC}"
echo -e "  ${YELLOW}sudo journalctl -u $FRONTEND_SERVICE_NAME -f${NC}"