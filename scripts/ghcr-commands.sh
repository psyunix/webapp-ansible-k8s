#!/bin/bash
# Quick commands for working with GitHub Container Registry

# ====================
# SETUP (One-time)
# ====================

# 1. Create Personal Access Token at:
#    https://github.com/settings/tokens
#    Scopes: write:packages, read:packages

# 2. Login to GHCR
export GITHUB_TOKEN="ghp_your_token_here"
echo $GITHUB_TOKEN | docker login ghcr.io -u psyunix --password-stdin

# ====================
# BUILD & PUSH
# ====================

# Build image with multiple tags
docker build -t ghcr.io/psyunix/webapp-ansible-k8s:latest ./app
docker build -t ghcr.io/psyunix/webapp-ansible-k8s:v1.0.0 ./app
docker build -t ghcr.io/psyunix/webapp-ansible-k8s:$(git rev-parse --short HEAD) ./app

# Push image
docker push ghcr.io/psyunix/webapp-ansible-k8s:latest
docker push ghcr.io/psyunix/webapp-ansible-k8s:v1.0.0
docker push ghcr.io/psyunix/webapp-ansible-k8s:$(git rev-parse --short HEAD)

# Build and push in one go
docker buildx build --push \
  -t ghcr.io/psyunix/webapp-ansible-k8s:latest \
  -t ghcr.io/psyunix/webapp-ansible-k8s:$(git rev-parse --short HEAD) \
  ./app

# ====================
# PULL & USE
# ====================

# Pull image
docker pull ghcr.io/psyunix/webapp-ansible-k8s:latest

# Run container
docker run -p 8080:80 ghcr.io/psyunix/webapp-ansible-k8s:latest

# ====================
# KUBERNETES
# ====================

# Create image pull secret for private images
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=psyunix \
  --docker-password=$GITHUB_TOKEN \
  --docker-email=your-email@example.com

# Delete and recreate secret
kubectl delete secret ghcr-secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=psyunix \
  --docker-password=$GITHUB_TOKEN

# Use in deployment (add to your deployment.yml)
# spec:
#   imagePullSecrets:
#   - name: ghcr-secret
#   containers:
#   - name: webapp
#     image: ghcr.io/psyunix/webapp-ansible-k8s:latest

# ====================
# MANAGEMENT
# ====================

# List local images
docker images | grep ghcr.io/psyunix/webapp-ansible-k8s

# Remove local image
docker rmi ghcr.io/psyunix/webapp-ansible-k8s:latest

# View package on GitHub
# https://github.com/psyunix?tab=packages

# Make package public
# https://github.com/users/psyunix/packages/container/webapp-ansible-k8s/settings

# ====================
# GITHUB ACTIONS
# ====================

# Trigger workflow manually
gh workflow run deploy.yml

# View workflow runs
gh run list --workflow=deploy.yml

# View latest run
gh run view

# ====================
# TROUBLESHOOTING
# ====================

# Check if logged in
docker info | grep Username

# Re-login if needed
docker logout ghcr.io
echo $GITHUB_TOKEN | docker login ghcr.io -u psyunix --password-stdin

# Inspect image
docker inspect ghcr.io/psyunix/webapp-ansible-k8s:latest

# Check image layers
docker history ghcr.io/psyunix/webapp-ansible-k8s:latest
