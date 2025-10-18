#!/bin/bash

cd /Users/psyunix/Documents/git/claude/ansible/webapp-ansible-k8s

# Build image (skip if already built)
echo "Building Docker image..."
docker build -t webapp:latest ./app 2>&1 | tail -5

# Activate venv and deploy
echo ""
echo "Deploying with Ansible..."
source venv/bin/activate && cd ansible && ansible-playbook playbooks/deploy-webapp.yml
