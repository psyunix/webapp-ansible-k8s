#!/bin/bash

# Fix and redeploy script
# This script fixes the ImagePullBackOff error by using local images

set -e

echo "========================================="
echo "Fixing ImagePullBackOff Error"
echo "========================================="
echo ""

# Navigate to project directory
# Allow overriding the project directory using the PROJECT_DIR env var
# or the first script argument. Otherwise detect macOS vs Linux and
# choose a sensible default path for each.
if [ -n "$1" ]; then
    PROJECT_DIR="$1"
elif [ -n "$PROJECT_DIR" ]; then
    PROJECT_DIR="$PROJECT_DIR"
else
    case "$(uname -s)" in
        Darwin)
            # macOS default path
            PROJECT_DIR="/Users/psyunix/Documents/git/claude/ansible/webapp-ansible-k8s"
            ;;
        Linux)
            # Linux default path
            PROJECT_DIR="/home/mcvetic/git/webapp-ansible-k8s"
            ;;
        *)
            echo "Unsupported OS '$(uname -s)'. Please set PROJECT_DIR or pass the project path as the first argument."
            exit 1
            ;;
    esac
fi

echo "Using project directory: $PROJECT_DIR"
cd "$PROJECT_DIR"

echo "Step 1: Building Docker image locally..."
docker build -t webapp:latest ./app
echo "✓ Image built successfully"
echo ""

echo "Step 2: Cleaning up old deployment..."
kubectl delete namespace webapp --ignore-not-found=true
echo "✓ Old deployment cleaned"
echo ""

echo "Waiting for namespace to be fully deleted..."
sleep 5
echo ""

echo "Step 3: Setting up Python environment..."
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

echo "Activating virtual environment..."
source venv/bin/activate

echo "Installing dependencies..."
pip install -q --upgrade pip
pip install -q ansible kubernetes openshift PyYAML
ansible-galaxy collection install kubernetes.core --force > /dev/null 2>&1

echo "✓ Python environment ready"
echo ""

echo "Step 4: Deploying with local image..."
cd ansible
ansible-playbook playbooks/deploy-webapp.yml
cd ..
echo ""

echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Check status with:"
echo "  kubectl get all -n webapp"
echo ""
echo "Access application at:"
echo "  http://localhost"
echo ""
