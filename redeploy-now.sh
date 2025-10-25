#!/bin/bash
set -e

export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH
cd /Users/psyunix/Documents/git/claude/ansible/webapp-ansible-k8s

echo '🔨 Building Docker image locally...'
docker build --no-cache -t webapp:latest ./app

echo ''
echo '📦 Loading image into Kubernetes nodes...'
echo 'Loading into desktop-worker...'
docker save webapp:latest | docker exec -i desktop-worker ctr -n k8s.io images import -
echo 'Loading into desktop-worker2...'
docker save webapp:latest | docker exec -i desktop-worker2 ctr -n k8s.io images import -

echo ''
echo '🚀 Deploying to Kubernetes with Ansible...'
source venv/bin/activate
cd ansible
ansible-playbook playbooks/deploy-webapp.yml

echo ''
echo '♻️  Restarting pods to pick up new image...'
kubectl delete pods --all -n webapp

echo ''
echo '⏳ Waiting for pods to be ready...'
kubectl wait --for=condition=ready pod -l app=webapp -n webapp --timeout=60s

echo ''
echo '✅ Deployment complete!'
echo 'Access your app at: http://localhost'
echo ''
echo '🔍 Verify with: kubectl describe pod -n webapp | grep "Image ID:"'
