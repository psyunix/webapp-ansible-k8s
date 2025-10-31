#!/bin/bash

# Quick Start Script for Web App Deployment
# Author: psyunix
# Description: Automated setup and deployment for Kubernetes web app with Ansible

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Global variables
PF_PID=""
VERBOSE=false
DRY_RUN=false
SKIP_BUILD=false
SKIP_IMAGE_CHECK=false
LOG_FILE=""
TEST_PORT=8888
MAX_RETRIES=3

# Cleanup function
cleanup() {
    if [[ -n "$PF_PID" ]] && kill -0 "$PF_PID" 2>/dev/null; then
        echo -e "\n${YELLOW}Cleaning up port-forward process...${NC}" >&2
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
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration - can be overridden by environment variables or config file
APP_NAME="${APP_NAME:-webapp}"
NAMESPACE="${K8S_NAMESPACE:-webapp}"
REGISTRY="${DOCKER_REGISTRY:-ghcr.io/psyunix}"
VERSION="${APP_VERSION:-latest}"
K8S_CONTEXT="${K8S_CONTEXT:-docker-desktop}"

# Load config file if it exists
if [[ -f ".quickstart.conf" ]]; then
    source .quickstart.conf
fi

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

print_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}🔍 $1${NC}"
    fi
}

log_message() {
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    fi
    if [[ "$VERBOSE" == "true" ]]; then
        print_debug "$1"
    fi
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
        # Check if Docker daemon is running
        if ! docker info &> /dev/null; then
            print_error "Docker daemon is not running"
            print_info "Please start Docker Desktop"
            exit 1
        else
            print_debug "Docker daemon is running"
        fi
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    else
        print_success "kubectl is installed"
        local kubectl_version
        kubectl_version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown")
        print_debug "kubectl version: $kubectl_version"
    fi
    
    # Check Python3
    if ! command -v python3 &> /dev/null; then
        missing_tools+=("python3")
    else
        print_success "Python3 is installed"
        local python_version
        python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        print_debug "Python version: $python_version"
    fi
    
    # Check curl (optional, but needed for testing)
    if ! command -v curl &> /dev/null; then
        print_warning "curl is not installed (needed for health testing)"
        print_info "Install with: brew install curl"
    else
        print_debug "curl is installed"
    fi
    
    # Check if Kubernetes is running
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Kubernetes cluster is not running"
        print_info "Please start Docker Desktop and enable Kubernetes"
        exit 1
    else
        print_success "Kubernetes cluster is running"
    fi
    
    # Check kubectl context
    local current_context
    current_context=$(kubectl config current-context 2>/dev/null || echo "")
    if [[ -n "$current_context" ]]; then
        print_debug "Current kubectl context: $current_context"
        if [[ "$current_context" != "$K8S_CONTEXT" ]]; then
            print_warning "Current context ($current_context) differs from expected ($K8S_CONTEXT)"
            if [[ "$VERBOSE" == "true" ]]; then
                print_info "To switch context: kubectl config use-context $K8S_CONTEXT"
            fi
        fi
    fi
    
    # Report missing tools
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Install missing tools using: brew install ${missing_tools[*]}"
        exit 1
    fi
    
    log_message "Prerequisites check completed successfully"
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
    
    local image_tag="${REGISTRY}/${APP_NAME}:${VERSION}"
    
    # Check if image already exists
    if [[ "$SKIP_IMAGE_CHECK" != "true" ]] && docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image_tag}$"; then
        print_warning "Image ${image_tag} already exists locally"
        read -p "Rebuild image? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping image build"
            log_message "Image build skipped - image already exists"
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] Would build ${image_tag}"
        return 0
    fi
    
    print_info "Building ${image_tag}..."
    log_message "Starting Docker image build: $image_tag"
    
    cd app
    if [[ "$VERBOSE" == "true" ]]; then
        docker build -t "${image_tag}" .
    else
        docker build -t "${image_tag}" . --quiet
    fi
    
    local build_status=$?
    cd ..
    
    if [[ $build_status -eq 0 ]]; then
        print_success "Docker image built successfully"
        log_message "Docker image built successfully: $image_tag"
        
        # Show image info
        print_debug "Image size: $(docker images "${image_tag}" --format "{{.Size}}")"
    else
        print_error "Docker image build failed"
        log_message "Docker image build failed: $image_tag"
        exit 1
    fi
    
    echo ""
}

# Push Docker image to registry (optional)
push_image() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] Would push ${REGISTRY}/${APP_NAME}:${VERSION}"
        return 0
    fi
    
    print_header "Pushing Docker Image"
    print_info "Pushing ${REGISTRY}/${APP_NAME}:${VERSION}..."
    log_message "Pushing Docker image to registry"
    
    if docker push "${REGISTRY}/${APP_NAME}:${VERSION}"; then
        print_success "Docker image pushed successfully"
        log_message "Docker image pushed successfully"
    else
        print_error "Failed to push Docker image"
        print_warning "Make sure you're logged in to the registry: docker login ${REGISTRY}"
        exit 1
    fi
    
    echo ""
}

# Check if namespace exists
check_namespace() {
    if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        print_info "Namespace ${NAMESPACE} does not exist - will be created during deployment"
        return 1
    else
        print_debug "Namespace ${NAMESPACE} exists"
        return 0
    fi
}

# Deploy application
deploy_app() {
    print_header "Deploying Application"
    
    print_info "Deploying ${APP_NAME} version ${VERSION} to ${NAMESPACE} namespace..."
    log_message "Starting deployment: app=${APP_NAME}, version=${VERSION}, namespace=${NAMESPACE}"
    
    # Check namespace
    check_namespace || true
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] Would deploy ${APP_NAME} version ${VERSION}"
        print_info "[DRY RUN] Would run: APP_VERSION=${VERSION} ansible-playbook playbooks/deploy-webapp.yml"
        return 0
    fi
    
    cd ansible
    local ansible_opts=()
    if [[ "$VERBOSE" == "true" ]]; then
        ansible_opts+=("-vv")
    fi
    
    if APP_VERSION=${VERSION} ansible-playbook "${ansible_opts[@]}" playbooks/deploy-webapp.yml; then
        print_success "Application deployed successfully"
        log_message "Application deployed successfully"
    else
        print_error "Application deployment failed"
        log_message "Application deployment failed"
        cd ..
        exit 1
    fi
    cd ..
    
    echo ""
}

# Rollback application
rollback_app() {
    print_header "Rolling Back Application"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] Would rollback ${APP_NAME}"
        return 0
    fi
    
    print_info "Rolling back ${APP_NAME} in ${NAMESPACE} namespace..."
    log_message "Starting rollback: app=${APP_NAME}, namespace=${NAMESPACE}"
    
    if [[ ! -f "ansible/playbooks/rollback.yml" ]]; then
        print_error "Rollback playbook not found: ansible/playbooks/rollback.yml"
        exit 1
    fi
    
    cd ansible
    local ansible_opts=()
    if [[ "$VERBOSE" == "true" ]]; then
        ansible_opts+=("-vv")
    fi
    
    if ansible-playbook "${ansible_opts[@]}" playbooks/rollback.yml; then
        print_success "Application rolled back successfully"
        log_message "Application rolled back successfully"
    else
        print_error "Application rollback failed"
        log_message "Application rollback failed"
        cd ..
        exit 1
    fi
    cd ..
    
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
    log_message "Starting deployment health test"
    
    # Check if service exists first
    if ! kubectl get svc -n ${NAMESPACE} ${APP_NAME}-service &>/dev/null; then
        print_warning "Service ${APP_NAME}-service not found in namespace ${NAMESPACE}"
        log_message "Service not found - test skipped"
        return 1
    fi
    
    # Get service port
    local service_port
    service_port=$(kubectl get svc -n ${NAMESPACE} ${APP_NAME}-service -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
    print_debug "Service port: $service_port"
    
    # Port forward in background with better error handling
    local pf_log="/tmp/pf-${APP_NAME}-${NAMESPACE}.log"
    print_debug "Starting port-forward on localhost:${TEST_PORT}"
    kubectl port-forward -n ${NAMESPACE} svc/${APP_NAME}-service ${TEST_PORT}:${service_port} > "${pf_log}" 2>&1 &
    PF_PID=$!
    
    # Wait a moment for port forward to establish and check if it's still running
    local wait_count=0
    local max_wait=10
    while [[ $wait_count -lt $max_wait ]]; do
        sleep 1
        if ! kill -0 $PF_PID 2>/dev/null; then
            print_warning "Port forward failed to establish. Check ${pf_log} for details"
            if [[ "$VERBOSE" == "true" ]] && [[ -f "$pf_log" ]]; then
                print_debug "Port-forward log:"
                cat "$pf_log" | sed 's/^/  /'
            fi
            return 1
        fi
        wait_count=$((wait_count + 1))
    done
    
    # Test HTTP endpoint with retries
    if ! command -v curl &> /dev/null; then
        print_warning "curl is not installed - skipping HTTP health test"
        print_info "Install curl to enable health testing: brew install curl"
        log_message "Health test skipped - curl not installed"
        return 0
    fi
    
    local test_success=false
    local retry_count=0
    
    print_info "Testing HTTP endpoint (retrying up to ${MAX_RETRIES} times)..."
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        print_debug "Attempt $((retry_count + 1))/${MAX_RETRIES}: Testing http://localhost:${TEST_PORT}"
        
        if curl -s -f -m 5 "http://localhost:${TEST_PORT}" > /dev/null 2>&1; then
            print_success "Application is responding to HTTP requests"
            log_message "Health test passed - application is responding"
            test_success=true
            break
        else
            retry_count=$((retry_count + 1))
            if [[ $retry_count -lt $MAX_RETRIES ]]; then
                print_debug "Attempt failed, retrying in 2 seconds..."
                sleep 2
            fi
        fi
    done
    
    if [[ "$test_success" == "false" ]]; then
        print_warning "Could not reach application on localhost:${TEST_PORT} after ${MAX_RETRIES} attempts"
        log_message "Health test failed - application not responding"
        
        if [[ "$VERBOSE" == "true" ]]; then
            print_debug "Checking pod status..."
            kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME} 2>/dev/null || true
        fi
    fi
    
    # Kill port forward
    if kill -0 $PF_PID 2>/dev/null; then
        kill $PF_PID 2>/dev/null || true
        wait $PF_PID 2>/dev/null || true
        PF_PID=""
    fi
    
    # Clean up log file if test succeeded
    if [[ "$test_success" == "true" ]] && [[ -f "$pf_log" ]]; then
        rm -f "$pf_log"
    fi
    
    echo ""
    return $([[ "$test_success" == "true" ]] && echo 0 || echo 1)
}

# Parse command line flags
parse_flags() {
    local command=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --dry-run|-d)
                DRY_RUN=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --skip-image-check)
                SKIP_IMAGE_CHECK=true
                shift
                ;;
            --log-file)
                if [[ -z "$2" ]]; then
                    print_error "--log-file requires a file path"
                    exit 1
                fi
                LOG_FILE="$2"
                shift 2
                ;;
            --test-port)
                if [[ -z "$2" ]]; then
                    print_error "--test-port requires a port number"
                    exit 1
                fi
                TEST_PORT="$2"
                shift 2
                ;;
            --max-retries)
                if [[ -z "$2" ]]; then
                    print_error "--max-retries requires a number"
                    exit 1
                fi
                MAX_RETRIES="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                print_error "Unknown flag: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$command" ]]; then
                    command="$1"
                else
                    print_error "Unknown argument: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    echo "$command"
}

# Show help message
show_help() {
    cat << EOF
Usage: ./quickstart.sh [command] [options]

Commands:
  setup      - Setup Python environment and dependencies
  build      - Build Docker image only
  push       - Push Docker image to registry
  deploy     - Full deployment (default)
  rollback   - Rollback to previous version
  status     - Show deployment status
  test       - Test application health
  logs       - Stream application logs
  clean      - Delete all resources
  help       - Show this help message

Options:
  -v, --verbose          Enable verbose output
  -d, --dry-run          Show what would be done without executing
  --skip-build           Skip building Docker image (use existing)
  --skip-image-check     Skip checking if image exists before building
  --log-file FILE        Write logs to specified file
  --test-port PORT       Port to use for health testing (default: 8888)
  --max-retries N        Maximum retry attempts for health test (default: 3)
  -h, --help             Show this help message

Environment Variables:
  APP_VERSION            Application version (default: latest)
  APP_NAME               Application name (default: webapp)
  K8S_NAMESPACE          Kubernetes namespace (default: webapp)
  DOCKER_REGISTRY        Docker registry (default: ghcr.io/psyunix)
  K8S_CONTEXT            Kubernetes context (default: docker-desktop)

Examples:
  ./quickstart.sh deploy
  ./quickstart.sh deploy --verbose
  ./quickstart.sh deploy --dry-run
  ./quickstart.sh build --skip-image-check
  APP_VERSION=v1.0.0 ./quickstart.sh deploy
  ./quickstart.sh deploy --log-file deploy.log
EOF
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
    
    # Initialize log file if specified
    if [[ -n "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
        log_message "Script started with arguments: $*"
    fi
    
    # Parse command line arguments
    local command
    command=$(parse_flags "$@")
    
    # Default command
    if [[ -z "$command" ]]; then
        command="deploy"
    fi
    
    case "$command" in
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
        "push")
            check_prerequisites
            push_image
            ;;
        "deploy")
            check_prerequisites
            setup_python_env
            verify_ansible
            if [[ "$SKIP_BUILD" != "true" ]]; then
                build_image
            else
                print_info "Skipping build (--skip-build flag set)"
            fi
            deploy_app
            wait_for_deployment
            show_status
            test_deployment
            show_access_info
            ;;
        "rollback")
            check_prerequisites
            rollback_app
            wait_for_deployment
            show_status
            test_deployment
            show_access_info
            ;;
        "status")
            check_prerequisites
            show_status
            ;;
        "test")
            check_prerequisites
            test_deployment
            ;;
        "clean")
            print_header "Cleaning Up"
            print_warning "This will delete the ${NAMESPACE} namespace and all resources"
            if [[ "$DRY_RUN" == "true" ]]; then
                print_info "[DRY RUN] Would delete namespace ${NAMESPACE}"
            else
                read -p "Are you sure? (yes/no): " confirm
                if [ "$confirm" == "yes" ]; then
                    kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
                    print_success "Cleanup complete"
                    log_message "Namespace ${NAMESPACE} deleted"
                else
                    print_info "Cleanup cancelled"
                fi
            fi
            ;;
        "logs")
            check_prerequisites
            print_header "Application Logs"
            if ! kubectl get namespace ${NAMESPACE} &>/dev/null; then
                print_error "Namespace ${NAMESPACE} does not exist"
                exit 1
            fi
            if ! kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME} &>/dev/null; then
                print_error "No pods found for app=${APP_NAME} in namespace ${NAMESPACE}"
                exit 1
            fi
            kubectl logs -n ${NAMESPACE} -l app=${APP_NAME} -f
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function
main "$@"
