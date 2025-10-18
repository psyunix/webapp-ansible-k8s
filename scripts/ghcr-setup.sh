#!/bin/bash
# Script to set up and push Docker images to GitHub Container Registry (GHCR)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="ghcr.io"
GITHUB_USER="psyunix"
REPO_NAME="webapp-ansible-k8s"
IMAGE_NAME="${REGISTRY}/${GITHUB_USER}/${REPO_NAME}"

echo -e "${GREEN}=== GitHub Container Registry Setup ===${NC}\n"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
if ! command_exists docker; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Function to login to GHCR
ghcr_login() {
    echo -e "${YELLOW}Step 1: Login to GitHub Container Registry${NC}"
    echo ""
    echo "You need a GitHub Personal Access Token (PAT) with 'write:packages' scope."
    echo "Create one at: https://github.com/settings/tokens"
    echo ""
    read -sp "Enter your GitHub PAT: " GITHUB_TOKEN
    echo ""
    
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}Error: Token cannot be empty${NC}"
        exit 1
    fi
    
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully logged in to GHCR${NC}\n"
    else
        echo -e "${RED}✗ Failed to login to GHCR${NC}"
        exit 1
    fi
}

# Function to build the Docker image
build_image() {
    echo -e "${YELLOW}Step 2: Building Docker image${NC}"
    
    # Get version from git
    if command_exists git; then
        VERSION=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
    else
        VERSION="latest"
    fi
    
    FULL_IMAGE_TAG="${IMAGE_NAME}:${VERSION}"
    LATEST_IMAGE_TAG="${IMAGE_NAME}:latest"
    
    echo "Building image: $FULL_IMAGE_TAG"
    
    cd app
    docker build -t "$FULL_IMAGE_TAG" -t "$LATEST_IMAGE_TAG" .
    cd ..
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully built image${NC}\n"
    else
        echo -e "${RED}✗ Failed to build image${NC}"
        exit 1
    fi
}

# Function to push the Docker image
push_image() {
    echo -e "${YELLOW}Step 3: Pushing Docker image to GHCR${NC}"
    
    echo "Pushing: $FULL_IMAGE_TAG"
    docker push "$FULL_IMAGE_TAG"
    
    echo "Pushing: $LATEST_IMAGE_TAG"
    docker push "$LATEST_IMAGE_TAG"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully pushed image to GHCR${NC}\n"
    else
        echo -e "${RED}✗ Failed to push image${NC}"
        exit 1
    fi
}

# Function to make package public (optional)
make_public_instructions() {
    echo -e "${YELLOW}Step 4: Make your package public (optional)${NC}"
    echo ""
    echo "To make your container image public:"
    echo "1. Go to: https://github.com/users/${GITHUB_USER}/packages/container/${REPO_NAME}/settings"
    echo "2. Scroll to 'Danger Zone'"
    echo "3. Click 'Change visibility' → 'Public'"
    echo ""
}

# Function to show pull instructions
show_pull_instructions() {
    echo -e "${GREEN}=== Success! ===${NC}\n"
    echo "Your image is now available at:"
    echo "  ${IMAGE_NAME}:${VERSION}"
    echo "  ${IMAGE_NAME}:latest"
    echo ""
    echo "To pull the image:"
    echo "  docker pull ${IMAGE_NAME}:latest"
    echo ""
    echo "To use in Kubernetes:"
    echo "  image: ${IMAGE_NAME}:latest"
    echo ""
}

# Main execution
main() {
    case "${1:-all}" in
        login)
            ghcr_login
            ;;
        build)
            build_image
            ;;
        push)
            push_image
            ;;
        all)
            ghcr_login
            build_image
            push_image
            make_public_instructions
            show_pull_instructions
            ;;
        *)
            echo "Usage: $0 {login|build|push|all}"
            echo ""
            echo "  login - Login to GitHub Container Registry"
            echo "  build - Build Docker image"
            echo "  push  - Push image to GHCR (requires login first)"
            echo "  all   - Run all steps (default)"
            exit 1
            ;;
    esac
}

main "$@"
