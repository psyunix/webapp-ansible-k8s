#!/bin/bash
set -e

export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH
cd /Users/psyunix/Documents/git/claude/ansible/webapp-ansible-k8s

echo '🔨 Building Docker image...'
docker build -t webapp:latest ./app

echo ''
echo '🚀 Deploying to Kubernetes with Ansible...'
source venv/bin/activate
cd ansible
ansible-playbook playbooks/deploy-webapp.yml

echo ''
echo '✅ Deployment complete!'
echo 'Access your app at: http://localhost'
