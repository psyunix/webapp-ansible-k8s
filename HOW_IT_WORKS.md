# How This Repository Works - Detailed Explanation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Components](#components)
4. [Deployment Workflow](#deployment-workflow)
5. [CI/CD Pipeline](#cicd-pipeline)
6. [File Structure Explained](#file-structure-explained)
7. [Key Technologies](#key-technologies)
8. [Step-by-Step Deployment Process](#step-by-step-deployment-process)
9. [Behind the Scenes](#behind-the-scenes)

---

## Overview

This repository provides a **complete automation workflow** for deploying web applications to Kubernetes using Ansible, Docker Desktop, and GitHub Actions. It demonstrates modern DevOps practices including Infrastructure as Code (IaC), containerization, and CI/CD automation.

**What it does:**
- Builds a containerized web application using Docker
- Deploys the application to a local Kubernetes cluster (Docker Desktop)
- Automates the entire process using Ansible playbooks
- Provides CI/CD integration through GitHub Actions
- Supports scaling, rollback, and health monitoring

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Developer Workflow                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1. Code Change → 2. Git Push → 3. GitHub Actions           │
│                                                               │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │   GitHub Actions CI   │
        │                       │
        │  • Build Docker Image │
        │  • Security Scan      │
        │  • Validate Ansible   │
        │  • Push to Registry   │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │  Local Deployment     │
        │                       │
        │  Developer Machine:   │
        │  • Run quickstart.sh  │
        │  • Or use Makefile    │
        │  • Or Ansible direct  │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │   Ansible Playbook    │
        │                       │
        │  • Check prerequisites│
        │  • Create namespace   │
        │  • Apply K8s configs  │
        │  • Deploy application │
        │  • Verify deployment  │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────────────────────┐
        │   Kubernetes Cluster (Docker Desktop) │
        │                                       │
        │   ┌─────────────────────────────┐    │
        │   │      Namespace: webapp      │    │
        │   │                             │    │
        │   │  ┌────────────────────┐    │    │
        │   │  │   ConfigMap        │    │    │
        │   │  │   • app-config     │    │    │
        │   │  └────────────────────┘    │    │
        │   │                             │    │
        │   │  ┌────────────────────┐    │    │
        │   │  │   Deployment       │    │    │
        │   │  │   • 2 Replicas     │    │    │
        │   │  │   • Rolling Update │    │    │
        │   │  │   • Health Checks  │    │    │
        │   │  └────────┬───────────┘    │    │
        │   │           │                │    │
        │   │           ▼                │    │
        │   │  ┌────────────────────┐    │    │
        │   │  │   Pod 1            │    │    │
        │   │  │   • nginx:alpine   │    │    │
        │   │  │   • Port 80        │    │    │
        │   │  │   • Resources      │    │    │
        │   │  └────────────────────┘    │    │
        │   │                             │    │
        │   │  ┌────────────────────┐    │    │
        │   │  │   Pod 2            │    │    │
        │   │  │   • nginx:alpine   │    │    │
        │   │  │   • Port 80        │    │    │
        │   │  │   • Resources      │    │    │
        │   │  └────────────────────┘    │    │
        │   │                             │    │
        │   │  ┌────────────────────┐    │    │
        │   │  │   Service          │    │    │
        │   │  │   • LoadBalancer   │    │    │
        │   │  │   • Port 80        │    │    │
        │   │  └────────────────────┘    │    │
        │   └─────────────┬───────────────┘    │
        └─────────────────┼───────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  http://localhost:80  │
              │                       │
              │  Your Web Application │
              └───────────────────────┘
```

---

## Components

### 1. **Application Code** (`app/`)

**Location:** `/app/src/index.html`

A simple, modern HTML5 web application with:
- Responsive design
- Gradient background
- Deployment information display
- Health status indicator

**Location:** `/app/Dockerfile`

The container definition that:
- Uses `nginx:alpine` as the base image (lightweight ~5MB)
- Copies the web application into nginx's document root
- Configures nginx with a custom configuration
- Adds a `/health` endpoint for Kubernetes health checks
- Exposes port 80
- Includes Docker HEALTHCHECK directive

### 2. **Ansible Automation** (`ansible/`)

#### **Inventory Configuration** (`ansible/inventory/`)

**File:** `group_vars/all.yml`
- Defines all configuration variables
- Application settings (name, version, replicas)
- Kubernetes settings (namespace, context)
- Resource limits (CPU, memory)
- Health check parameters
- Environment variables

**File:** `hosts.yml`
- Defines target hosts (localhost in this case)
- Uses local connection for deployment

#### **Playbooks** (`ansible/playbooks/`)

**File:** `deploy-webapp.yml`
- Main deployment playbook
- Pre-tasks: Verify kubectl and cluster
- Runs the `webapp` role
- Post-tasks: Display deployment status

**File:** `rollback.yml`
- Rollback to previous deployment
- Shows rollout history
- Prompts for confirmation
- Executes rollback using kubectl

#### **Roles** (`ansible/roles/webapp/`)

**File:** `tasks/main.yml`
- Installs required Python packages
- Creates Kubernetes namespace
- Creates ConfigMap for configuration
- Deploys application using templates
- Creates LoadBalancer service
- Waits for deployment to be ready
- Displays service information

**File:** `templates/deployment.yml.j2`
- Jinja2 template for Kubernetes Deployment
- Defines pod replicas (default: 2)
- Rolling update strategy (maxSurge: 1, maxUnavailable: 0)
- Container specification with resource limits
- Liveness and readiness probes
- Volume mounts for ConfigMap

**File:** `templates/service.yml.j2`
- Jinja2 template for Kubernetes Service
- Type: LoadBalancer (exposes on localhost)
- Port mapping: 80 (external) → 80 (container)
- Session affinity: ClientIP

### 3. **Automation Scripts**

#### **quickstart.sh** - Main Deployment Script
The most comprehensive script with these functions:
- `check_prerequisites()` - Verifies Docker, kubectl, Python3, and Kubernetes
- `setup_python_env()` - Creates venv, installs Ansible and dependencies
- `verify_ansible()` - Runs syntax check on playbooks
- `build_image()` - Builds Docker image locally
- `deploy_app()` - Executes Ansible playbook
- `wait_for_deployment()` - Waits for pods to be ready
- `show_status()` - Displays deployment, pods, and services
- `test_deployment()` - Tests application health via HTTP
- `show_access_info()` - Shows how to access the application

**Commands:**
- `./quickstart.sh deploy` - Full deployment
- `./quickstart.sh setup` - Only setup environment
- `./quickstart.sh build` - Only build image
- `./quickstart.sh status` - Show status
- `./quickstart.sh logs` - Stream logs
- `./quickstart.sh clean` - Delete all resources

#### **Makefile** - Make-based Automation
Provides organized targets for:
- `make help` - Show all available commands
- `make setup` - Setup Python environment
- `make build` - Build Docker image
- `make deploy` - Deploy to Kubernetes
- `make status` - Show deployment status
- `make scale REPLICAS=N` - Scale deployment
- `make rollback` - Rollback deployment
- `make logs` - Stream application logs
- `make clean` - Clean up all resources
- `make full-deploy` - Complete deployment from scratch

### 4. **CI/CD Pipeline** (`.github/workflows/deploy.yml`)

GitHub Actions workflow with 4 jobs:

#### **Job 1: Build**
- Checks out code
- Sets up Docker Buildx for multi-platform builds
- Logs into GitHub Container Registry (ghcr.io)
- Extracts metadata (tags, labels)
- Builds Docker image for linux/amd64 and linux/arm64
- Pushes to ghcr.io/psyunix/webapp-ansible-k8s
- Generates build attestation for security

#### **Job 2: Validate**
- Sets up Python 3.11
- Installs Ansible and dependencies
- Installs kubernetes.core collection
- Runs syntax check on all playbooks
- Creates validation summary in GitHub Actions

#### **Job 3: Security Scan**
- Runs Trivy vulnerability scanner
- Scans the Docker image for CVEs
- Uploads results to GitHub Security tab
- Creates SARIF report

#### **Job 4: Deployment Summary**
- Creates deployment instructions
- Shows image tag and version
- Provides commands for local deployment
- Only runs on push to main branch

---

## Deployment Workflow

### What Happens When You Run `./quickstart.sh deploy`

```
┌─────────────────────────────────────────────────────────┐
│                 DEPLOYMENT WORKFLOW                      │
└─────────────────────────────────────────────────────────┘

1. CHECK PREREQUISITES
   ├─ Verify Docker is installed
   ├─ Verify kubectl is installed
   ├─ Verify Python3 is installed
   └─ Verify Kubernetes cluster is running
      └─ Exit if any prerequisite is missing

2. SETUP PYTHON ENVIRONMENT
   ├─ Create virtual environment (venv/)
   ├─ Activate virtual environment
   ├─ Upgrade pip
   ├─ Install Ansible
   ├─ Install Kubernetes Python client
   ├─ Install openshift and PyYAML
   └─ Install kubernetes.core Ansible collection

3. VERIFY ANSIBLE
   ├─ Change to ansible/ directory
   ├─ Run syntax check on deploy-webapp.yml
   └─ Return to root directory

4. BUILD DOCKER IMAGE
   ├─ Change to app/ directory
   ├─ Run: docker build -t ghcr.io/psyunix/webapp:latest .
   │  ├─ Use nginx:alpine as base
   │  ├─ Remove default nginx content
   │  ├─ Create custom nginx config with /health endpoint
   │  ├─ Copy src/index.html to /usr/share/nginx/html/
   │  ├─ Add healthcheck
   │  └─ Set nginx to run in foreground
   └─ Return to root directory

5. DEPLOY APPLICATION
   ├─ Change to ansible/ directory
   ├─ Run: ansible-playbook playbooks/deploy-webapp.yml
   │  │
   │  ├─ PRE-TASKS
   │  │  ├─ Verify kubectl is installed
   │  │  ├─ Verify Kubernetes is running
   │  │  └─ Display cluster info
   │  │
   │  ├─ ROLE: webapp/tasks/main.yml
   │  │  ├─ Install Python kubernetes packages
   │  │  ├─ Create namespace "webapp"
   │  │  ├─ Create ConfigMap "webapp-config"
   │  │  ├─ Apply deployment.yml.j2
   │  │  │  └─ Creates Deployment with:
   │  │  │     ├─ 2 replicas
   │  │  │     ├─ Rolling update strategy
   │  │  │     ├─ Resource limits (CPU: 500m, Memory: 512Mi)
   │  │  │     ├─ Liveness probe (path: /, delay: 30s, period: 10s)
   │  │  │     ├─ Readiness probe (path: /, delay: 5s, period: 5s)
   │  │  │     └─ ConfigMap volume mount
   │  │  ├─ Apply service.yml.j2
   │  │  │  └─ Creates Service with:
   │  │  │     ├─ Type: LoadBalancer
   │  │  │     ├─ Port: 80
   │  │  │     └─ Session affinity: ClientIP
   │  │  ├─ Wait for deployment ready
   │  │  │  └─ Poll every 5s, max 60 retries (5 minutes)
   │  │  ├─ Get service info
   │  │  └─ Display access URL
   │  │
   │  └─ POST-TASKS
   │     ├─ Get all pods in namespace
   │     ├─ Display pod status
   │     └─ Show deployment summary
   └─ Return to root directory

6. WAIT FOR DEPLOYMENT
   ├─ Run: kubectl wait --for=condition=available deployment/webapp
   └─ Timeout: 300 seconds (5 minutes)

7. SHOW STATUS
   ├─ Display deployments: kubectl get deployment -n webapp
   ├─ Display pods: kubectl get pods -n webapp
   └─ Display services: kubectl get svc -n webapp

8. TEST DEPLOYMENT
   ├─ Start port-forward in background (port 8888)
   ├─ Wait 3 seconds for port-forward to establish
   ├─ Test: curl -s http://localhost:8888
   ├─ Report success or warning
   └─ Kill port-forward process

9. SHOW ACCESS INFORMATION
   ├─ Get service type and port
   ├─ Display access URL (http://localhost:80)
   ├─ Show logs command
   ├─ Show scale command
   └─ Show cleanup command

✓ DEPLOYMENT COMPLETE
```

---

## CI/CD Pipeline

### Trigger Events

The GitHub Actions workflow triggers on:
1. **Push to main or develop branches**
2. **Pull requests to main**
3. **Git tags matching 'v*'** (e.g., v1.0.0)
4. **Manual workflow dispatch** with environment selection

### Pipeline Flow

```
┌──────────────────────────────────────────────────────┐
│           GITHUB ACTIONS CI/CD PIPELINE              │
└──────────────────────────────────────────────────────┘

[Trigger: git push / PR / tag]
           │
           ▼
    ┌─────────────┐
    │ JOB: BUILD  │
    └─────┬───────┘
          │
          ├─► Checkout code
          ├─► Setup Docker Buildx
          ├─► Login to ghcr.io
          ├─► Extract metadata (tags, version)
          ├─► Build multi-platform image
          │   ├─ linux/amd64
          │   └─ linux/arm64
          ├─► Push to registry
          ├─► Generate attestation
          └─► Output: image-tag, image-version, image-digest
                │
                ├────────────────┬─────────────────┐
                ▼                ▼                 ▼
         ┌──────────┐    ┌──────────────┐  ┌─────────────┐
         │VALIDATE  │    │SECURITY SCAN │  │SUMMARY      │
         └────┬─────┘    └──────┬───────┘  └─────┬───────┘
              │                 │                 │
              ├─► Setup Python  ├─► Run Trivy    ├─► Create
              ├─► Install       ├─► Scan image   │   deployment
              │   Ansible       ├─► Generate     │   instructions
              ├─► Install       │   SARIF        ├─► Show image
              │   k8s.core      ├─► Upload to    │   details
              ├─► Syntax check  │   Security     └─► Show deploy
              │   all playbooks │   tab               commands
              └─► Create        └─► Alert on
                  summary           vulnerabilities

✓ Pipeline complete - Image ready for deployment
```

### What Gets Built

**Image Naming Convention:**
- Main branch: `ghcr.io/psyunix/webapp-ansible-k8s:latest`
- Branches: `ghcr.io/psyunix/webapp-ansible-k8s:main`
- PRs: `ghcr.io/psyunix/webapp-ansible-k8s:pr-123`
- Tags: `ghcr.io/psyunix/webapp-ansible-k8s:v1.0.0`
- SHA: `ghcr.io/psyunix/webapp-ansible-k8s:main-abc1234`

---

## File Structure Explained

```
webapp-ansible-k8s/
│
├── app/                           # Application source code
│   ├── Dockerfile                 # Container image definition
│   │   └─ Base: nginx:alpine
│   │   └─ Health endpoint: /health
│   │   └─ Copies src/ to /usr/share/nginx/html/
│   └── src/
│       └── index.html             # Web application HTML
│           └─ Modern responsive design
│           └─ Displays deployment info
│
├── ansible/                       # Ansible automation
│   ├── ansible.cfg                # Ansible configuration
│   ├── inventory/                 # Inventory and variables
│   │   ├── hosts.yml              # Target hosts (localhost)
│   │   └── group_vars/
│   │       └── all.yml            # Global variables
│   │           └─ app_name: webapp
│   │           └─ replicas: 2
│   │           └─ k8s_namespace: webapp
│   │           └─ resource limits, probes, etc.
│   ├── playbooks/                 # Ansible playbooks
│   │   ├── deploy-webapp.yml      # Main deployment playbook
│   │   │   └─ Pre-tasks: verify environment
│   │   │   └─ Roles: webapp
│   │   │   └─ Post-tasks: show status
│   │   └── rollback.yml           # Rollback playbook
│   │       └─ Shows history
│   │       └─ Prompts for confirmation
│   │       └─ Executes rollback
│   └── roles/                     # Ansible roles
│       └── webapp/
│           ├── tasks/
│           │   └── main.yml       # Main task list
│           │       └─ Install dependencies
│           │       └─ Create namespace
│           │       └─ Create ConfigMap
│           │       └─ Deploy application
│           │       └─ Create service
│           │       └─ Wait for ready
│           └── templates/         # Jinja2 templates
│               ├── deployment.yml.j2  # K8s Deployment
│               │   └─ 2 replicas
│               │   └─ Rolling update
│               │   └─ Health checks
│               │   └─ Resource limits
│               └── service.yml.j2     # K8s Service
│                   └─ Type: LoadBalancer
│                   └─ Port: 80
│
├── .github/                       # GitHub configuration
│   └── workflows/
│       └── deploy.yml             # CI/CD workflow
│           └─ Build multi-platform image
│           └─ Validate Ansible
│           └─ Security scan
│           └─ Generate summary
│
├── quickstart.sh                  # Main deployment script
│   └─ Full automated deployment
│   └─ Prerequisites check
│   └─ Environment setup
│   └─ Build, deploy, verify
│
├── Makefile                       # Make automation
│   └─ Organized targets
│   └─ Help system
│   └─ Build, deploy, scale, rollback
│
├── deploy-docker-desktop.sh       # Docker Desktop specific
│   └─ Multi-node deployment
│   └─ Load image to nodes
│
├── simple-deploy.sh               # Quick deployment
│   └─ Minimal script for fast redeploy
│
├── fix-and-deploy.sh              # Troubleshooting script
│   └─ Fixes ImagePullBackOff
│   └─ Clean deployment
│
├── diagnose.sh                    # Diagnostic tool
│   └─ Shows namespace, pods, services
│   └─ Recent events
│   └─ Pod logs
│
└── README.md                      # Main documentation
    └─ Quick start
    └─ Prerequisites
    └─ Usage examples
```

---

## Key Technologies

### 1. **Docker**
- **Purpose:** Containerize the web application
- **Base Image:** nginx:alpine (lightweight, ~5MB)
- **Benefits:** Consistent environments, easy deployment, isolation

### 2. **Kubernetes**
- **Purpose:** Container orchestration
- **Features Used:**
  - Namespaces (isolation)
  - Deployments (desired state)
  - Services (networking)
  - ConfigMaps (configuration)
  - Rolling updates (zero-downtime)
  - Health checks (liveness/readiness probes)
  - Resource management (CPU/memory limits)

### 3. **Ansible**
- **Purpose:** Infrastructure as Code automation
- **Why Ansible:**
  - Declarative configuration
  - Idempotent operations (safe to run multiple times)
  - No agents required
  - Easy to read YAML syntax
  - Built-in Kubernetes modules

### 4. **GitHub Actions**
- **Purpose:** CI/CD automation
- **Features:**
  - Automated builds on code changes
  - Multi-platform image building
  - Security scanning
  - Container registry integration
  - Workflow summaries

---

## Step-by-Step Deployment Process

### Phase 1: Image Building

```bash
cd app/
docker build -t ghcr.io/psyunix/webapp:latest .
```

**What happens:**
1. Docker reads the Dockerfile
2. Downloads nginx:alpine base image
3. Removes default nginx content
4. Creates custom nginx configuration
5. Copies index.html to /usr/share/nginx/html/
6. Sets up healthcheck
7. Tags the image
8. Image is ready in local Docker daemon

### Phase 2: Ansible Execution

```bash
cd ansible/
ansible-playbook playbooks/deploy-webapp.yml
```

**What happens:**
1. Ansible reads the playbook
2. Loads variables from group_vars/all.yml
3. Connects to localhost
4. Executes pre-tasks (verify kubectl, cluster)
5. Runs the webapp role
6. Processes Jinja2 templates with variables
7. Applies Kubernetes manifests via kubernetes.core modules
8. Waits for deployment to be ready
9. Executes post-tasks (display status)

### Phase 3: Kubernetes Deployment

**Namespace Creation:**
```bash
kubectl create namespace webapp
```

**ConfigMap Creation:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: webapp
data:
  app.conf: |
    server_name: webapp
    environment: production
```

**Deployment Creation:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: webapp:latest
        ports:
        - containerPort: 80
```

**Service Creation:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: webapp
spec:
  type: LoadBalancer
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
```

### Phase 4: Kubernetes Processing

1. **Deployment Controller** creates ReplicaSet
2. **ReplicaSet Controller** creates 2 Pods
3. **Scheduler** assigns Pods to nodes
4. **Kubelet** pulls image and starts containers
5. **Kubelet** runs liveness/readiness probes
6. **Service Controller** creates endpoint
7. **LoadBalancer Controller** (Docker Desktop) exposes on localhost:80

---

## Behind the Scenes

### Rolling Update Process

When you update the application:

```
Initial State:
  Pod-1 (v1.0) ───┐
                  ├── Service (load balancer)
  Pod-2 (v1.0) ───┘

Update Triggered (v2.0):

Step 1: Create new pod
  Pod-1 (v1.0) ───┐
  Pod-2 (v1.0) ───┤── Service
  Pod-3 (v2.0) ───┘  (creating...)

Step 2: Wait for new pod ready
  Pod-1 (v1.0) ───┐
  Pod-2 (v1.0) ───┤── Service
  Pod-3 (v2.0) ───┘  (ready!)

Step 3: Terminate old pod
  Pod-2 (v1.0) ───┐
                  ├── Service
  Pod-3 (v2.0) ───┘

Step 4: Create second new pod
  Pod-2 (v1.0) ───┐
  Pod-3 (v2.0) ───┤── Service
  Pod-4 (v2.0) ───┘  (creating...)

Step 5: Wait for ready
  Pod-2 (v1.0) ───┐
  Pod-3 (v2.0) ───┤── Service
  Pod-4 (v2.0) ───┘  (ready!)

Step 6: Terminate last old pod
  Pod-3 (v2.0) ───┐
                  ├── Service
  Pod-4 (v2.0) ───┘

Final State:
  Pod-3 (v2.0) ───┐
                  ├── Service (load balancer)
  Pod-4 (v2.0) ───┘
```

**Configuration:**
- `maxSurge: 1` - Allow 1 extra pod during update (3 total)
- `maxUnavailable: 0` - Always keep all pods available
- Result: Zero downtime deployment

### Health Checks

**Liveness Probe:**
- Tests if container is alive
- If fails, Kubernetes restarts the container
- Path: `/`
- Initial delay: 30 seconds
- Period: 10 seconds
- Used to recover from deadlock/hang

**Readiness Probe:**
- Tests if container can serve traffic
- If fails, removes from service endpoints
- Path: `/`
- Initial delay: 5 seconds
- Period: 5 seconds
- Used during startup and temporary issues

### Resource Management

Each container gets:
- **CPU Request:** 100m (0.1 cores) - guaranteed minimum
- **CPU Limit:** 500m (0.5 cores) - maximum allowed
- **Memory Request:** 128Mi - guaranteed minimum
- **Memory Limit:** 512Mi - maximum allowed

**Why this matters:**
- Prevents one app from starving others
- Enables efficient node scheduling
- Protects cluster stability

### Service Discovery

When a pod needs to connect to another service:

1. Pod queries Kubernetes DNS
2. DNS returns service cluster IP
3. Service load-balances to healthy pods
4. Connection established

Example:
```
Pod queries: webapp-service.webapp.svc.cluster.local
DNS returns: 10.96.1.100 (ClusterIP)
Service forwards to: Pod-1 (172.17.0.5) or Pod-2 (172.17.0.6)
```

---

## Summary

This repository demonstrates:

1. **Modern DevOps Practices**
   - Infrastructure as Code (Ansible)
   - Containerization (Docker)
   - Orchestration (Kubernetes)
   - CI/CD (GitHub Actions)

2. **Production-Ready Features**
   - Health checks
   - Resource limits
   - Rolling updates
   - Zero-downtime deployment
   - Automatic rollback capability
   - Security scanning

3. **Developer-Friendly**
   - One-command deployment
   - Multiple deployment options
   - Comprehensive documentation
   - Diagnostic tools
   - Easy customization

4. **Cloud-Native Architecture**
   - 12-factor app principles
   - Declarative configuration
   - Scalability
   - Self-healing
   - Service discovery

The entire workflow can be summarized as:
**Code → Build → Test → Deploy → Monitor** - all automated and repeatable.
