#!/bin/bash

# Exit on any error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo -e "${2:-$BLUE}$1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "Please run as root (with sudo)" "$RED"
    exit 1
fi

# Get the actual user who ran sudo (not root)
SUDO_USER="${SUDO_USER:-$USER}"
if [ "$SUDO_USER" = "root" ]; then
    log "Please run with sudo, not as root directly" "$RED"
    exit 1
fi

# Check for .env file
ENV_FILE=".env"
ENV_TEMPLATE=".env.template"

if [ ! -f "$ENV_FILE" ]; then
    if [ ! -f "$ENV_TEMPLATE" ]; then
        log "Neither .env nor .env.template found. Please ensure at least .env.template exists." "$RED"
        exit 1
    fi
    log "No .env file found. Creating from template..." "$YELLOW"
    cp "$ENV_TEMPLATE" "$ENV_FILE"
    log ".env file created. Please review and modify if needed." "$GREEN"
    exit 0
fi

# Source the .env file
set -a
source "$ENV_FILE"
set +a

# Default values if not set in .env
BACKEND_SERVICE_NAME=${BACKEND_SERVICE_NAME:-awsight-web-backend}
FRONTEND_SERVICE_NAME=${FRONTEND_SERVICE_NAME:-awsight-web-front}
BASE_DIR=${BASE_DIR:-/home/ubuntu/AWSight-IR/webui}
BACKEND_DIR=${BACKEND_DIR:-$BASE_DIR/server}
FRONTEND_DIR=${FRONTEND_DIR:-$BASE_DIR/client}
BACKEND_VENV=${BACKEND_VENV:-$BACKEND_DIR/venv}
BACKEND_PORT=${BACKEND_PORT:-8000}
PYTHON_VERSION=${PYTHON_VERSION:-3.12}
NODE_ENV=${NODE_ENV:-production}
NPM_COMMAND=${NPM_COMMAND:-preview}

# Install system packages
log "=== Installing Required System Packages ==="

# Update package list
log "Updating package list..." "$YELLOW"
apt update

# Install npm if not already installed
if ! command -v npm &> /dev/null; then
    log "npm not found. Installing npm..." "$YELLOW"
    apt install -y npm
    log "npm installed successfully" "$GREEN"
else
    log "npm is already installed" "$GREEN"
fi

# Install Python if not already installed
if ! command -v "python${PYTHON_VERSION}" &> /dev/null; then
    log "Python ${PYTHON_VERSION} not found. Installing..." "$YELLOW"
    apt install -y "python${PYTHON_VERSION}"
    log "Python ${PYTHON_VERSION} installed successfully" "$GREEN"
else
    log "Python ${PYTHON_VERSION} is already installed" "$GREEN"
fi

# Install Python venv if not already installed
if ! dpkg -l | grep -q "python${PYTHON_VERSION}-venv"; then
    log "Python venv not found. Installing python${PYTHON_VERSION}-venv..." "$YELLOW"
    apt install -y "python${PYTHON_VERSION}-venv"
    log "Python venv installed successfully" "$GREEN"
else
    log "Python venv is already installed" "$GREEN"
fi

# Get user's group
USER_GROUP=$(id -gn "$SUDO_USER")

# Print setup information
log "=== AWsight Web Services Setup ==="
log "Setting up services with following configuration:" "$GREEN"
log "User: ${SUDO_USER}" "$YELLOW"
log "Group: ${USER_GROUP}" "$YELLOW"
log "Backend Directory: ${BACKEND_DIR}" "$YELLOW"
log "Frontend Directory: ${FRONTEND_DIR}" "$YELLOW"
log "Backend Virtual Environment: ${BACKEND_VENV}" "$YELLOW"
log "Backend Port: ${BACKEND_PORT}" "$YELLOW"
log "Backend Service Name: ${BACKEND_SERVICE_NAME}" "$YELLOW"
log "Frontend Service Name: ${FRONTEND_SERVICE_NAME}" "$YELLOW"

# Create directories if they don't exist
mkdir -p "$BACKEND_DIR" "$FRONTEND_DIR"
chown -R "$SUDO_USER:$USER_GROUP" "$BACKEND_DIR" "$FRONTEND_DIR"

# Confirm with user
read -p "Continue with this configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Setup cancelled" "$RED"
    exit 1
fi

# Setup Python virtual environment
log "=== Setting up Python Virtual Environment ==="
if [ ! -d "$BACKEND_VENV" ]; then
    log "Creating new virtual environment at $BACKEND_VENV" "$YELLOW"
    # Remove any partial venv
    rm -rf "$BACKEND_VENV"
    # Create new venv
    sudo -u "$SUDO_USER" "python${PYTHON_VERSION}" -m venv "$BACKEND_VENV"
    log "Virtual environment created successfully" "$GREEN"
fi

# Install Python packages
log "=== Installing Python Packages ==="
sudo -u "$SUDO_USER" bash -c "source $BACKEND_VENV/bin/activate && \
    pip install --upgrade pip && \
    pip install \
        fastapi[all] \
        uvicorn \
        python-dotenv \
        anthropic \
        pytest \
        requests \
        pydantic \
        typing-extensions"

# Setup Backend Service
log "=== Setting up Backend Service ==="
cat > "/etc/systemd/system/$BACKEND_SERVICE_NAME.service" << EOL
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

log "Backend service file created" "$GREEN"

# Setup Frontend Service
log "=== Setting up Frontend Service ==="
cat > "/etc/systemd/system/$FRONTEND_SERVICE_NAME.service" << EOL
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

log "Frontend service file created" "$GREEN"

# Install frontend dependencies and build
log "=== Setting up Frontend Application ==="
cd "$FRONTEND_DIR"

# Install global npm packages
log "Installing global npm packages..." "$YELLOW"
npm install -g pm2

# Install project dependencies
log "Installing project dependencies..." "$YELLOW"
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
log "Building the frontend application..." "$YELLOW"
sudo -u "$SUDO_USER" npm run build

# Enable and start services
log "=== Starting Services ==="
systemctl daemon-reload

log "Enabling and starting backend service..." "$GREEN"
systemctl enable "$BACKEND_SERVICE_NAME"
systemctl start "$BACKEND_SERVICE_NAME"

log "Enabling and starting frontend service..." "$GREEN"
systemctl enable "$FRONTEND_SERVICE_NAME"
systemctl start "$FRONTEND_SERVICE_NAME"

# Final status check
log "=== Service Status ==="
log "Backend Service Status:" "$YELLOW"
systemctl status "$BACKEND_SERVICE_NAME" --no-pager
log "\nFrontend Service Status:" "$YELLOW"
systemctl status "$FRONTEND_SERVICE_NAME" --no-pager

# Print helpful information
log "=== Setup Complete! ==="
log "Useful commands:" "$GREEN"
log "Backend service management:"
log "  sudo systemctl start $BACKEND_SERVICE_NAME" "$YELLOW"
log "  sudo systemctl stop $BACKEND_SERVICE_NAME" "$YELLOW"
log "  sudo systemctl restart $BACKEND_SERVICE_NAME" "$YELLOW"
log "  sudo systemctl status $BACKEND_SERVICE_NAME" "$YELLOW"
log "  sudo journalctl -u $BACKEND_SERVICE_NAME -f" "$YELLOW"
log "\nFrontend service management:"
log "  sudo systemctl start $FRONTEND_SERVICE_NAME" "$YELLOW"
log "  sudo systemctl stop $FRONTEND_SERVICE_NAME" "$YELLOW"
log "  sudo systemctl restart $FRONTEND_SERVICE_NAME" "$YELLOW"
log "  sudo systemctl status $FRONTEND_SERVICE_NAME" "$YELLOW"
log "  sudo journalctl -u $FRONTEND_SERVICE_NAME -f" "$YELLOW"
