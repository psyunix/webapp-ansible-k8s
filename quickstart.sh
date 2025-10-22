#!/bin/bash

# Quick Start Script for Web App Deployment
# Author: psyunix
# Description: Automated setup and deployment for Kubernetes web app with Ansible

set -e  # Exit on error

# Global variable for port-forward PID
PF_PID=""

# Cleanup function
cleanup() {
    if [[ -n "$PF_PID" ]] && kill -0 "$PF_PID" 2>/dev/null; then
        echo -e "\n${YELLOW}Cleaning up port-forward process...${NC}"
        kill "$PF_PID" 2>/dev/null || true
        wait "$PF_PID" 2>/dev/null || true
    fi
}

# Set up signal traps
trap cleanup EXIT INT TERM

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="webapp"
NAMESPACE="webapp"
REGISTRY="ghcr.io/psyunix"
VERSION="${APP_VERSION:-latest}"

# Functions
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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    else
        print_success "Docker is installed"
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    else
        print_success "kubectl is installed"
    fi
    
    # Check Python3
    if ! command -v python3 &> /dev/null; then
        missing_tools+=("python3")
    else
        print_success "Python3 is installed"
    fi
    
    # Check if Kubernetes is running
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Kubernetes cluster is not running"
        print_info "Please start Docker Desktop and enable Kubernetes"
        exit 1
    else
        print_success "Kubernetes cluster is running"
    fi
    
    # Report missing tools
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Install missing tools using: brew install ${missing_tools[*]}"
        exit 1
    fi
    
    echo ""
}

# Setup Python environment
setup_python_env() {
    print_header "Setting Up Python Environment"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        print_info "Creating Python virtual environment..."
        python3 -m venv venv
        print_success "Virtual environment created"
    else
        print_info "Virtual environment already exists"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    print_info "Upgrading pip..."
    pip install --upgrade pip --quiet
    
    # Install dependencies
    print_info "Installing Python packages..."
    pip install ansible kubernetes openshift PyYAML --quiet
    print_success "Python packages installed"
    
    # Install Ansible collections
    print_info "Installing Ansible Kubernetes collection..."
    ansible-galaxy collection install kubernetes.core --force > /dev/null 2>&1
    print_success "Ansible collections installed"
    
    echo ""
}

# Verify Ansible setup
verify_ansible() {
    print_header "Verifying Ansible Setup"
    
    cd ansible
    
    # Run syntax check
    print_info "Running Ansible syntax check..."
    if ansible-playbook playbooks/deploy-webapp.yml --syntax-check > /dev/null 2>&1; then
        print_success "Ansible syntax check passed"
    else
        print_error "Ansible syntax check failed"
        exit 1
    fi
    
    cd ..
    echo ""
}

# Build Docker image
build_image() {
    print_header "Building Docker Image"
    
    print_info "Building ${REGISTRY}/${APP_NAME}:${VERSION}..."
    cd app
    docker build -t ${REGISTRY}/${APP_NAME}:${VERSION} . --quiet
    cd ..
    print_success "Docker image built successfully"
    
    echo ""
}

# Deploy application
deploy_app() {
    print_header "Deploying Application"
    
    print_info "Deploying ${APP_NAME} version ${VERSION} to ${NAMESPACE} namespace..."
    
    cd ansible
    APP_VERSION=${VERSION} ansible-playbook playbooks/deploy-webapp.yml
    cd ..
    
    print_success "Application deployed successfully"
    echo ""
}

# Display deployment status
show_status() {
    print_header "Deployment Status"
    
    echo -e "${BLUE}Deployments:${NC}"
    kubectl get deployment -n ${NAMESPACE}
    echo ""
    
    echo -e "${BLUE}Pods:${NC}"
    kubectl get pods -n ${NAMESPACE}
    echo ""
    
    echo -e "${BLUE}Services:${NC}"
    kubectl get svc -n ${NAMESPACE}
    echo ""
}

# Wait for deployment
wait_for_deployment() {
    print_header "Waiting for Deployment"
    
    print_info "Waiting for pods to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/${APP_NAME} -n ${NAMESPACE}
    print_success "All pods are ready"
    
    echo ""
}

# Display access information
show_access_info() {
    print_header "Access Information"
    
    SERVICE_TYPE=$(kubectl get svc ${APP_NAME}-service -n ${NAMESPACE} -o jsonpath='{.spec.type}')
    SERVICE_PORT=$(kubectl get svc ${APP_NAME}-service -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].port}')
    
    echo -e "${GREEN}Application successfully deployed!${NC}"
    echo ""
    echo -e "${BLUE}Service Type:${NC} ${SERVICE_TYPE}"
    echo -e "${BLUE}Port:${NC} ${SERVICE_PORT}"
    echo ""
    
    if [ "${SERVICE_TYPE}" == "LoadBalancer" ]; then
        echo -e "${GREEN}Access your application at:${NC}"
        echo -e "  ${BLUE}http://localhost:${SERVICE_PORT}${NC}"
    else
        echo -e "${YELLOW}To access the application, run:${NC}"
        echo -e "  ${BLUE}kubectl port-forward -n ${NAMESPACE} svc/${APP_NAME}-service 8080:${SERVICE_PORT}${NC}"
        echo -e "${GREEN}Then access at:${NC}"
        echo -e "  ${BLUE}http://localhost:8080${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}To view logs:${NC}"
    echo -e "  kubectl logs -n ${NAMESPACE} -l app=${APP_NAME} -f"
    echo ""
    echo -e "${BLUE}To scale the deployment:${NC}"
    echo -e "  kubectl scale deployment/${APP_NAME} -n ${NAMESPACE} --replicas=<number>"
    echo ""
    echo -e "${BLUE}To delete the deployment:${NC}"
    echo -e "  kubectl delete namespace ${NAMESPACE}"
    echo ""
}

# Test deployment
test_deployment() {
    print_header "Testing Deployment"
    
    print_info "Testing application health..."
    
    # Check if service exists first
    if ! kubectl get svc -n ${NAMESPACE} ${APP_NAME}-service &>/dev/null; then
        print_warning "Service ${APP_NAME}-service not found in namespace ${NAMESPACE}"
        return 1
    fi
    
    # Port forward in background with better error handling
    kubectl port-forward -n ${NAMESPACE} svc/${APP_NAME}-service 8888:80 > /tmp/pf.log 2>&1 &
    PF_PID=$!
    
    # Wait a moment for port forward to establish and check if it's still running
    sleep 3
    if ! kill -0 $PF_PID 2>/dev/null; then
        print_warning "Port forward failed to establish. Check /tmp/pf.log for details"
        return 1
    fi
    
    # Test HTTP endpoint
    if curl -s http://localhost:8888 > /dev/null; then
        print_success "Application is responding to HTTP requests"
    else
        print_warning "Could not reach application on localhost:8888"
    fi
    
    # Kill port forward
    if kill -0 $PF_PID 2>/dev/null; then
        kill $PF_PID 2>/dev/null || true
        wait $PF_PID 2>/dev/null || true
    fi
    
    echo ""
}

# Main execution
main() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
╦ ╦┌─┐┌┐    ╔═╗┌─┐┌─┐  ╔╦╗┌─┐┌─┐┬  ┌─┐┬ ┬┌─┐┬─┐
║║║├┤ ├┴┐   ╠═╣├─┘├─┘   ║║├┤ ├─┘│  │ │└┬┘├┤ ├┬┘
╚╩╝└─┘└─┘   ╩ ╩┴  ┴    ═╩╝└─┘┴  ┴─┘└─┘ ┴ └─┘┴└─
   with Ansible + Kubernetes + Docker Desktop
EOF
    echo -e "${NC}"
    echo ""
    
    # Parse command line arguments
    case "${1:-deploy}" in
        "setup")
            check_prerequisites
            setup_python_env
            print_success "Setup complete! Run './quickstart.sh deploy' to deploy the application"
            ;;
        "build")
            check_prerequisites
            build_image
            print_success "Build complete!"
            ;;
        "deploy")
            check_prerequisites
            setup_python_env
            verify_ansible
            build_image
            deploy_app
            wait_for_deployment
            show_status
            test_deployment
            show_access_info
            ;;
        "status")
            show_status
            ;;
        "test")
            test_deployment
            ;;
        "clean")
            print_header "Cleaning Up"
            print_warning "This will delete the ${NAMESPACE} namespace and all resources"
            read -p "Are you sure? (yes/no): " confirm
            if [ "$confirm" == "yes" ]; then
                kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
                print_success "Cleanup complete"
            else
                print_info "Cleanup cancelled"
            fi
            ;;
        "logs")
            print_header "Application Logs"
            kubectl logs -n ${NAMESPACE} -l app=${APP_NAME} -f
            ;;
        "help"|*)
            echo "Usage: ./quickstart.sh [command]"
            echo ""
            echo "Commands:"
            echo "  setup    - Setup Python environment and dependencies"
            echo "  build    - Build Docker image only"
            echo "  deploy   - Full deployment (default)"
            echo "  status   - Show deployment status"
            echo "  test     - Test application health"
            echo "  logs     - Stream application logs"
            echo "  clean    - Delete all resources"
            echo "  help     - Show this help message"
            echo ""
            ;;
    esac
}

# Run main function
main "$@"
