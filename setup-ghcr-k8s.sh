#!/bin/bash
# Script to set up GHCR authentication for Kubernetes on Fedora/Linux
# This creates the necessary secret for Kubernetes to pull images from GHCR

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="webapp"
SECRET_NAME="ghcr-secret"
REGISTRY="ghcr.io"
GITHUB_USER="psyunix"

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Main execution
main() {
    clear
    print_header "GHCR Authentication Setup for Kubernetes"
    echo ""
    
    # Check if GITHUB_TOKEN is set
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}GitHub Personal Access Token (PAT) Required${NC}"
        echo ""
        echo "You need a PAT with 'read:packages' scope to pull images from GHCR."
        echo "Create one at: https://github.com/settings/tokens"
        echo ""
        read -sp "Enter your GitHub PAT: " GITHUB_TOKEN
        echo ""
        
        if [ -z "$GITHUB_TOKEN" ]; then
            print_error "Token cannot be empty"
            exit 1
        fi
    fi
    
    # Create namespace if it doesn't exist
    print_info "Ensuring namespace exists..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    print_success "Namespace ready"
    
    # Delete existing secret if it exists
    print_info "Removing old secret (if exists)..."
    kubectl delete secret $SECRET_NAME -n $NAMESPACE --ignore-not-found=true
    
    # Create the image pull secret
    print_info "Creating GHCR image pull secret..."
    kubectl create secret docker-registry $SECRET_NAME \
        --docker-server=$REGISTRY \
        --docker-username=$GITHUB_USER \
        --docker-password=$GITHUB_TOKEN \
        --docker-email=${GITHUB_EMAIL:-noreply@github.com} \
        --namespace=$NAMESPACE
    
    if [ $? -eq 0 ]; then
        print_success "Secret created successfully"
    else
        print_error "Failed to create secret"
        exit 1
    fi
    
    # Export for Ansible (optional)
    print_info "Exporting configuration for Ansible..."
    DOCKER_CONFIG=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.\.dockerconfigjson}')
    export GHCR_DOCKER_CONFIG=$DOCKER_CONFIG
    
    echo ""
    print_header "Setup Complete!"
    echo ""
    print_success "Kubernetes can now pull images from ghcr.io/psyunix/"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Login to GHCR: echo \$GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin"
    echo "  2. Build and push image: ./quickstart.sh build && ./quickstart.sh push"
    echo "  3. Deploy: ./quickstart.sh deploy"
    echo ""
    echo -e "${YELLOW}Or use the all-in-one script: ./scripts/ghcr-setup.sh${NC}"
    echo ""
}

main "$@"
