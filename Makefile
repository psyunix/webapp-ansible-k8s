.PHONY: help setup build push deploy rollback clean test logs status

# Variables
APP_NAME := webapp
NAMESPACE := webapp
VERSION := latest
REGISTRY := ghcr.io/psyunix
IMAGE := $(REGISTRY)/$(APP_NAME)

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Setup local environment
	@echo "Setting up environment..."
	python3 -m venv venv
	. venv/bin/activate && pip install --upgrade pip
	. venv/bin/activate && pip install ansible kubernetes openshift PyYAML
	. venv/bin/activate && ansible-galaxy collection install kubernetes.core
	@echo "✓ Environment setup complete"

check-k8s: ## Check if Kubernetes is running
	@echo "Checking Kubernetes cluster..."
	@kubectl cluster-info > /dev/null 2>&1 || (echo "❌ Kubernetes is not running. Please start Docker Desktop Kubernetes." && exit 1)
	@echo "✓ Kubernetes cluster is running"

build: ## Build Docker image
	@echo "Building Docker image..."
	cd app && docker build -t $(IMAGE):$(VERSION) .
	@echo "✓ Image built: $(IMAGE):$(VERSION)"

push: build ## Build and push Docker image to registry
	@echo "Pushing image to registry..."
	docker push $(IMAGE):$(VERSION)
	@echo "✓ Image pushed: $(IMAGE):$(VERSION)"

ansible-check: ## Run Ansible syntax check
	@echo "Running Ansible syntax check..."
	cd ansible && ansible-playbook playbooks/deploy-webapp.yml --syntax-check
	@echo "✓ Ansible syntax check passed"

ansible-dry-run: ansible-check ## Run Ansible deployment in dry-run mode
	@echo "Running Ansible dry-run..."
	cd ansible && ansible-playbook playbooks/deploy-webapp.yml --check
	@echo "✓ Dry-run complete"

deploy: check-k8s ansible-check ## Deploy application to Kubernetes
	@echo "Deploying $(APP_NAME) version $(VERSION)..."
	cd ansible && APP_VERSION=$(VERSION) ansible-playbook playbooks/deploy-webapp.yml
	@echo "✓ Deployment complete"

deploy-verbose: check-k8s ## Deploy with verbose output
	@echo "Deploying $(APP_NAME) with verbose output..."
	cd ansible && APP_VERSION=$(VERSION) ansible-playbook playbooks/deploy-webapp.yml -vv

rollback: ## Rollback to previous deployment
	@echo "Rolling back deployment..."
	cd ansible && ansible-playbook playbooks/rollback.yml
	@echo "✓ Rollback complete"

scale: ## Scale deployment (usage: make scale REPLICAS=3)
	@echo "Scaling deployment to $(REPLICAS) replicas..."
	kubectl scale deployment/$(APP_NAME) -n $(NAMESPACE) --replicas=$(REPLICAS)
	@echo "✓ Scaled to $(REPLICAS) replicas"

status: ## Show deployment status
	@echo "=== Deployment Status ==="
	@kubectl get deployment -n $(NAMESPACE)
	@echo ""
	@echo "=== Pods ==="
	@kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -n $(NAMESPACE)

logs: ## Show application logs
	@echo "Streaming logs from $(APP_NAME)..."
	kubectl logs -n $(NAMESPACE) -l app=$(APP_NAME) -f

describe: ## Describe deployment
	@kubectl describe deployment $(APP_NAME) -n $(NAMESPACE)

shell: ## Open shell in running pod
	@POD=$$(kubectl get pod -n $(NAMESPACE) -l app=$(APP_NAME) -o jsonpath='{.items[0].metadata.name}'); \
	echo "Opening shell in pod: $$POD"; \
	kubectl exec -it -n $(NAMESPACE) $$POD -- /bin/sh

test-local: ## Test application locally with Docker
	@echo "Starting application locally on port 8080..."
	docker run -d -p 8080:80 --name $(APP_NAME)-test $(IMAGE):$(VERSION)
	@echo "✓ Application running at http://localhost:8080"
	@echo "Run 'make test-stop' to stop the test container"

test-stop: ## Stop local test container
	@echo "Stopping test container..."
	docker stop $(APP_NAME)-test && docker rm $(APP_NAME)-test
	@echo "✓ Test container stopped"

port-forward: ## Port forward service to localhost:8080
	@echo "Port forwarding service to localhost:8080..."
	@echo "Access application at http://localhost:8080"
	kubectl port-forward -n $(NAMESPACE) svc/$(APP_NAME)-service 8080:80

clean: ## Clean up all resources
	@echo "Cleaning up resources..."
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "✓ Cleanup complete"

clean-images: ## Remove local Docker images
	@echo "Removing local images..."
	docker rmi $(IMAGE):$(VERSION) || true
	@echo "✓ Images removed"

restart: ## Restart deployment
	@echo "Restarting deployment..."
	kubectl rollout restart deployment/$(APP_NAME) -n $(NAMESPACE)
	kubectl rollout status deployment/$(APP_NAME) -n $(NAMESPACE)
	@echo "✓ Deployment restarted"

watch: ## Watch deployment rollout
	@kubectl rollout status deployment/$(APP_NAME) -n $(NAMESPACE) -w

events: ## Show recent events
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

full-deploy: setup build push deploy ## Complete deployment from scratch

verify: ## Verify deployment health
	@echo "Verifying deployment health..."
	@kubectl wait --for=condition=available --timeout=300s deployment/$(APP_NAME) -n $(NAMESPACE)
	@echo "✓ Deployment is healthy"

install-tools: ## Install required tools on macOS
	@echo "Installing required tools..."
	@command -v brew >/dev/null 2>&1 || /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew install kubectl python@3.11
	@echo "✓ Tools installed"
