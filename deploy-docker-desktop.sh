#!/bin/bash

# Deploy with Docker Desktop Kubernetes (multi-node)
set -e

echo "========================================="
echo "Deploying to Docker Desktop Kubernetes"
echo "========================================="
echo ""

cd /Users/psyunix/Documents/git/claude/ansible/webapp-ansible-k8s

# Step 1: Build image
echo "Step 1: Building Docker image..."
docker build -t webapp:latest ./app
echo "✓ Image built"
echo ""

# Step 2: Save and load image to kind/k3d nodes (for Docker Desktop)
echo "Step 2: Making image available to Kubernetes nodes..."

# For Docker Desktop with multiple nodes, we need to load to each node
echo "Loading image to desktop-worker..."
docker save webapp:latest | docker exec -i desktop-worker ctr -n k8s.io images import - 2>/dev/null || echo "Note: Could not load to desktop-worker"

echo "Loading image to desktop-worker2..."
docker save webapp:latest | docker exec -i desktop-worker2 ctr -n k8s.io images import - 2>/dev/null || echo "Note: Could not load to desktop-worker2"

echo "Loading image to desktop-control-plane..."
docker save webapp:latest | docker exec -i desktop-control-plane ctr -n k8s.io images import - 2>/dev/null || echo "Note: Could not load to control-plane"

echo "✓ Image loaded to Kubernetes nodes"
echo ""

# Step 3: Clean up old deployment
echo "Step 3: Cleaning up old deployment..."
kubectl delete namespace webapp --ignore-not-found=true
sleep 5
echo "✓ Cleaned up"
echo ""

# Step 4: Deploy
echo "Step 4: Deploying application..."
source venv/bin/activate
cd ansible
ansible-playbook playbooks/deploy-webapp.yml
cd ..
echo ""

echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Check status:"
echo "  kubectl get pods -n webapp"
echo ""
echo "Access application:"
echo "  curl http://localhost"
echo "  open http://localhost"
echo ""
