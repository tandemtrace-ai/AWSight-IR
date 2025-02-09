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

# Service names
BACKEND_SERVICE="awsight-web-backend"
FRONTEND_SERVICE="awsight-web-front"

# Print removal plan
echo -e "${BLUE}=== Service Removal Plan ===${NC}"
echo -e "The following services will be removed:"
echo -e "1. ${YELLOW}$BACKEND_SERVICE${NC} (FastAPI Backend)"
echo -e "2. ${YELLOW}$FRONTEND_SERVICE${NC} (Vite Frontend)"

# Function to safely remove a service
remove_service() {
    local service_name=$1
    echo -e "\n${BLUE}=== Removing $service_name service ===${NC}"
    
    # Check if service exists
    if systemctl list-unit-files | grep -q "^$service_name.service"; then
        echo -e "${YELLOW}Stopping $service_name service...${NC}"
        systemctl stop $service_name || true
        
        echo -e "${YELLOW}Disabling $service_name service...${NC}"
        systemctl disable $service_name || true
        
        echo -e "${YELLOW}Removing service file...${NC}"
        rm -f /etc/systemd/system/$service_name.service
        
        echo -e "${GREEN}Service $service_name removed successfully${NC}"
    else
        echo -e "${YELLOW}Service $service_name not found, skipping...${NC}"
    fi
}

# Final confirmation
echo -e "\n${RED}Warning: This will remove the services and cannot be undone!${NC}"
read -p "Continue with removal? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Removal cancelled${NC}"
    exit 1
fi

# Remove services
remove_service $BACKEND_SERVICE
remove_service $FRONTEND_SERVICE

# Reload systemd
echo -e "\n${YELLOW}Reloading systemd daemon...${NC}"
systemctl daemon-reload

# Final status message
echo -e "\n${BLUE}=== Cleanup Complete ===${NC}"
echo -e "${GREEN}Services have been successfully removed.${NC}"
echo -e "\nThe following actions were performed:"
echo -e "• Stopped both services"
echo -e "• Disabled services from starting on boot"
echo -e "• Removed service files"
echo -e "• Reloaded systemd daemon"

echo -e "\n${YELLOW}Note: To reinstall the services, you can use the setup script again.${NC}"