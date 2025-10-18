#!/bin/bash
# Script to help set up GitHub Personal Access Token for GHCR

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== GitHub PAT Setup for GHCR ===${NC}\n"

# Check if token is already set
if [ -n "$GITHUB_TOKEN" ]; then
    echo -e "${GREEN}✓ GITHUB_TOKEN is already set in current session${NC}"
    echo "Token starts with: ${GITHUB_TOKEN:0:10}..."
else
    echo -e "${YELLOW}⚠ GITHUB_TOKEN is not set${NC}"
fi

echo ""
echo -e "${YELLOW}Steps to create/get your GitHub PAT:${NC}"
echo "1. Go to: https://github.com/settings/tokens"
echo "2. Click 'Generate new token (classic)'"
echo "3. Select scopes: write:packages, read:packages"
echo "4. Copy the generated token"
echo ""

# Function to set token temporarily
set_temp_token() {
    echo -e "${YELLOW}Setting token for current session...${NC}"
    read -sp "Enter your GitHub PAT: " GITHUB_TOKEN
    echo ""
    
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}Error: Token cannot be empty${NC}"
        return 1
    fi
    
    export GITHUB_TOKEN
    echo -e "${GREEN}✓ Token set for current session${NC}"
    echo "You can now run: echo \$GITHUB_TOKEN | docker login ghcr.io -u psyunix --password-stdin"
}

# Function to add token to bash profile
add_to_profile() {
    echo -e "${YELLOW}Adding token to ~/.bashrc...${NC}"
    read -sp "Enter your GitHub PAT: " GITHUB_TOKEN
    echo ""
    
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}Error: Token cannot be empty${NC}"
        return 1
    fi
    
    # Backup existing bashrc
    if [ -f ~/.bashrc ]; then
        cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
        echo -e "${BLUE}Backed up ~/.bashrc${NC}"
    fi
    
    # Add token to bashrc
    echo "" >> ~/.bashrc
    echo "# GitHub Personal Access Token for GHCR" >> ~/.bashrc
    echo "export GITHUB_TOKEN=$GITHUB_TOKEN" >> ~/.bashrc
    
    echo -e "${GREEN}✓ Token added to ~/.bashrc${NC}"
    echo -e "${YELLOW}Run 'source ~/.bashrc' or restart your terminal to apply${NC}"
}

# Function to test GHCR login
test_login() {
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}Error: GITHUB_TOKEN not set${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Testing GHCR login...${NC}"
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u psyunix --password-stdin
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully logged in to GHCR${NC}"
    else
        echo -e "${RED}✗ Failed to login to GHCR${NC}"
        return 1
    fi
}

# Function to test pulling an image
test_pull() {
    echo -e "${YELLOW}Testing image pull...${NC}"
    docker pull ghcr.io/psyunix/webapp-ansible-k8s:latest
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully pulled image${NC}"
    else
        echo -e "${RED}✗ Failed to pull image${NC}"
        echo "This might be normal if the image doesn't exist yet"
    fi
}

# Main menu
echo -e "${BLUE}What would you like to do?${NC}"
echo "1. Set token for current session only"
echo "2. Add token to ~/.bashrc (persistent)"
echo "3. Test GHCR login (requires token to be set)"
echo "4. Test pulling image"
echo "5. Show current token status"
echo ""

read -p "Choose an option (1-5): " choice

case $choice in
    1)
        set_temp_token
        ;;
    2)
        add_to_profile
        ;;
    3)
        test_login
        ;;
    4)
        test_pull
        ;;
    5)
        if [ -n "$GITHUB_TOKEN" ]; then
            echo -e "${GREEN}✓ GITHUB_TOKEN is set${NC}"
            echo "Token starts with: ${GITHUB_TOKEN:0:10}..."
        else
            echo -e "${RED}✗ GITHUB_TOKEN is not set${NC}"
        fi
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac