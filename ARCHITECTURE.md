# Architecture Deep Dive

## System Architecture

### High-Level Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPMENT ENVIRONMENT                          │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Developer's Machine                                                     │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                                                                 │    │
│  │  Source Code Repository                                        │    │
│  │  ├── app/                    (Application Code)                │    │
│  │  ├── ansible/                (Automation Scripts)              │    │
│  │  ├── .github/workflows/      (CI/CD Definitions)               │    │
│  │  └── Scripts                 (Helper Scripts)                  │    │
│  │                                                                 │    │
│  └─────────────────────┬───────────────────────────────────────────┘    │
│                        │                                                 │
│                        │ git push                                        │
│                        ▼                                                 │
└──────────────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         GITHUB REPOSITORY                                │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  GitHub.com/psyunix/webapp-ansible-k8s                                  │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                                                                 │    │
│  │  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐       │    │
│  │  │   Source    │    │   Issues &   │    │    Wiki     │       │    │
│  │  │   Control   │    │   Projects   │    │     &       │       │    │
│  │  │   (Git)     │    │              │    │    Docs     │       │    │
│  │  └─────────────┘    └──────────────┘    └─────────────┘       │    │
│  │                                                                 │    │
│  └─────────────────────┬───────────────────────────────────────────┘    │
│                        │                                                 │
│                        │ triggers                                        │
│                        ▼                                                 │
└──────────────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         GITHUB ACTIONS                                   │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  CI/CD Pipeline (Ubuntu Runner)                                         │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                                                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐      │    │
│  │  │ Job 1: Build                                         │      │    │
│  │  │  ├─ Setup Docker Buildx                              │      │    │
│  │  │  ├─ Build multi-arch image (amd64 + arm64)          │      │    │
│  │  │  ├─ Push to ghcr.io                                  │      │    │
│  │  │  └─ Generate attestation                             │      │    │
│  │  └──────────────────────────────────────────────────────┘      │    │
│  │                                                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐      │    │
│  │  │ Job 2: Validate                                      │      │    │
│  │  │  ├─ Install Ansible                                  │      │    │
│  │  │  ├─ Syntax check playbooks                           │      │    │
│  │  │  └─ Verify collection dependencies                   │      │    │
│  │  └──────────────────────────────────────────────────────┘      │    │
│  │                                                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐      │    │
│  │  │ Job 3: Security Scan                                 │      │    │
│  │  │  ├─ Run Trivy scanner                                │      │    │
│  │  │  ├─ Generate SARIF report                            │      │    │
│  │  │  └─ Upload to Security tab                           │      │    │
│  │  └──────────────────────────────────────────────────────┘      │    │
│  │                                                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐      │    │
│  │  │ Job 4: Summary                                       │      │    │
│  │  │  └─ Generate deployment instructions                 │      │    │
│  │  └──────────────────────────────────────────────────────┘      │    │
│  │                                                                 │    │
│  └─────────────────────┬───────────────────────────────────────────┘    │
│                        │                                                 │
│                        │ pushes image to                                 │
│                        ▼                                                 │
└──────────────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                  GITHUB CONTAINER REGISTRY                               │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ghcr.io/psyunix/webapp-ansible-k8s                                     │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                                                                 │    │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐               │    │
│  │  │   latest   │  │  v1.0.0    │  │    main    │               │    │
│  │  │            │  │            │  │            │               │    │
│  │  │  amd64 ✓   │  │  amd64 ✓   │  │  amd64 ✓   │               │    │
│  │  │  arm64 ✓   │  │  arm64 ✓   │  │  arm64 ✓   │               │    │
│  │  └────────────┘  └────────────┘  └────────────┘               │    │
│  │                                                                 │    │
│  └─────────────────────┬───────────────────────────────────────────┘    │
│                        │                                                 │
│                        │ pulls                                           │
│                        ▼                                                 │
└──────────────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    LOCAL DEPLOYMENT ENVIRONMENT                          │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Developer's Machine / Docker Desktop                                   │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                                                                 │    │
│  │  ┌─────────────────────────────────────────────────────┐       │    │
│  │  │ Deployment Tools (choose one)                       │       │    │
│  │  │                                                      │       │    │
│  │  │  Option 1: ./quickstart.sh deploy                   │       │    │
│  │  │  Option 2: make deploy                              │       │    │
│  │  │  Option 3: ansible-playbook playbooks/deploy-*.yml  │       │    │
│  │  │                                                      │       │    │
│  │  └──────────────────┬──────────────────────────────────┘       │    │
│  │                     │                                           │    │
│  │                     │ executes                                  │    │
│  │                     ▼                                           │    │
│  │  ┌─────────────────────────────────────────────────────┐       │    │
│  │  │ Ansible Engine                                      │       │    │
│  │  │  ├─ Reads playbooks/deploy-webapp.yml               │       │    │
│  │  │  ├─ Loads variables from group_vars/all.yml         │       │    │
│  │  │  ├─ Processes Jinja2 templates                      │       │    │
│  │  │  └─ Calls kubernetes.core modules                   │       │    │
│  │  └──────────────────┬──────────────────────────────────┘       │    │
│  │                     │                                           │    │
│  │                     │ manages                                   │    │
│  │                     ▼                                           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ Kubernetes Cluster (Docker Desktop)                            │    │
│  │                                                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐      │    │
│  │  │ Namespace: webapp                                    │      │    │
│  │  │                                                       │      │    │
│  │  │  ┌────────────────────────────────────────────┐      │      │    │
│  │  │  │ ConfigMap: webapp-config                   │      │      │    │
│  │  │  │  ├─ app.conf                                │      │      │    │
│  │  │  │  └─ environment: production                 │      │      │    │
│  │  │  └────────────────────────────────────────────┘      │      │    │
│  │  │                                                       │      │    │
│  │  │  ┌────────────────────────────────────────────┐      │      │    │
│  │  │  │ Deployment: webapp                         │      │      │    │
│  │  │  │  ├─ Strategy: RollingUpdate                │      │      │    │
│  │  │  │  ├─ Replicas: 2                            │      │      │    │
│  │  │  │  └─ Selector: app=webapp                   │      │      │    │
│  │  │  └───────────┬────────────────────────────────┘      │      │    │
│  │  │              │                                        │      │    │
│  │  │              ├──────────┬─────────────────┐           │      │    │
│  │  │              ▼          ▼                 ▼           │      │    │
│  │  │  ┌──────────────┐  ┌──────────────┐                  │      │    │
│  │  │  │ Pod 1        │  │ Pod 2        │                  │      │    │
│  │  │  │              │  │              │                  │      │    │
│  │  │  │ ┌──────────┐ │  │ ┌──────────┐ │                  │      │    │
│  │  │  │ │Container │ │  │ │Container │ │                  │      │    │
│  │  │  │ │          │ │  │ │          │ │                  │      │    │
│  │  │  │ │ nginx    │ │  │ │ nginx    │ │                  │      │    │
│  │  │  │ │ :alpine  │ │  │ │ :alpine  │ │                  │      │    │
│  │  │  │ │          │ │  │ │          │ │                  │      │    │
│  │  │  │ │ Port: 80 │ │  │ │ Port: 80 │ │                  │      │    │
│  │  │  │ │          │ │  │ │          │ │                  │      │    │
│  │  │  │ │ CPU:500m │ │  │ │ CPU:500m │ │                  │      │    │
│  │  │  │ │ Mem:512M │ │  │ │ Mem:512M │ │                  │      │    │
│  │  │  │ │          │ │  │ │          │ │                  │      │    │
│  │  │  │ │ Health ✓ │ │  │ │ Health ✓ │ │                  │      │    │
│  │  │  │ │ Ready  ✓ │ │  │ │ Ready  ✓ │ │                  │      │    │
│  │  │  │ └──────────┘ │  │ └──────────┘ │                  │      │    │
│  │  │  │              │  │              │                  │      │    │
│  │  │  │ IP:          │  │ IP:          │                  │      │    │
│  │  │  │ 172.17.0.5   │  │ 172.17.0.6   │                  │      │    │
│  │  │  └──────┬───────┘  └──────┬───────┘                  │      │    │
│  │  │         │                  │                          │      │    │
│  │  │         └────────┬─────────┘                          │      │    │
│  │  │                  │                                    │      │    │
│  │  │                  ▼                                    │      │    │
│  │  │  ┌────────────────────────────────────────────┐      │      │    │
│  │  │  │ Service: webapp-service                    │      │      │    │
│  │  │  │  ├─ Type: LoadBalancer                     │      │      │    │
│  │  │  │  ├─ ClusterIP: 10.96.1.100                 │      │      │    │
│  │  │  │  ├─ Port: 80 → TargetPort: 80              │      │      │    │
│  │  │  │  └─ Session Affinity: ClientIP             │      │      │    │
│  │  │  └───────────┬────────────────────────────────┘      │      │    │
│  │  │              │                                        │      │    │
│  │  └──────────────┼────────────────────────────────────────┘      │    │
│  │                 │                                                │    │
│  │                 │ exposes via                                    │    │
│  │                 ▼                                                │    │
│  │  ┌──────────────────────────────────────────────────────┐       │    │
│  │  │ Docker Desktop LoadBalancer                          │       │    │
│  │  │  └─ localhost:80                                     │       │    │
│  │  └──────────────────────────────────────────────────────┘       │    │
│  │                                                                  │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└──────────────────────────────┬───────────────────────────────────────────┘
                               │
                               │ accessible at
                               ▼
                    ┌──────────────────────┐
                    │   Web Browser        │
                    │                      │
                    │  http://localhost    │
                    │                      │
                    │  ┌────────────────┐  │
                    │  │   Web App UI   │  │
                    │  │                │  │
                    │  │   🚀 Deployed! │  │
                    │  └────────────────┘  │
                    └──────────────────────┘
```

---

## Data Flow

### Request Flow (User accessing the application)

```
┌─────────────────────────────────────────────────────────────────┐
│                    HTTP REQUEST FLOW                             │
└─────────────────────────────────────────────────────────────────┘

1. User Browser
   │
   │ HTTP GET http://localhost/
   │
   ▼
2. Docker Desktop Network
   │
   │ Routes to localhost:80
   │
   ▼
3. LoadBalancer Service (webapp-service)
   │
   │ Receives on ClusterIP:80
   │ Selects endpoint based on:
   │   - Round-robin (default)
   │   - Session affinity (ClientIP)
   │
   ├─ Option A ──────────┐
   │                     │
   ▼                     ▼
4a. Pod 1              4b. Pod 2
   │                     │
   │ Container Port 80   │ Container Port 80
   │                     │
   ▼                     ▼
5. nginx Process       nginx Process
   │                     │
   │ Checks request path │
   │                     │
   ├─ / ──────────────── Serves /usr/share/nginx/html/index.html
   ├─ /health ────────── Returns "healthy\n"
   └─ other ──────────── 404 Not Found
   │                     │
   ▼                     ▼
6. HTTP Response       HTTP Response
   │                     │
   │ Status: 200 OK      │
   │ Content-Type: text/html
   │ Body: index.html content
   │                     │
   └─────────┬───────────┘
             │
             ▼
7. Service forwards response
   │
   ▼
8. Docker Desktop Network
   │
   ▼
9. User Browser
   │
   └─ Displays webpage
```

---

## Deployment State Machine

```
┌─────────────────────────────────────────────────────────────────┐
│             KUBERNETES DEPLOYMENT STATES                         │
└─────────────────────────────────────────────────────────────────┘

[INITIAL STATE]
     │
     │ kubectl apply / Ansible creates Deployment
     ▼
┌─────────────────┐
│   CREATING      │  Deployment object created
│                 │  ReplicaSet controller triggered
└────────┬────────┘
         │
         │ ReplicaSet creates Pods
         ▼
┌─────────────────┐
│   PENDING       │  Pods created, waiting for scheduling
│                 │  Scheduler assigns pods to nodes
└────────┬────────┘
         │
         │ Node assigned, kubelet notified
         ▼
┌─────────────────┐
│  PULLING IMAGE  │  Kubelet pulls container image
│                 │  docker pull webapp:latest
└────────┬────────┘
         │
         │ Image pulled successfully
         ▼
┌─────────────────┐
│   STARTING      │  Container starting
│                 │  nginx process launches
└────────┬────────┘
         │
         │ Container running
         ▼
┌─────────────────┐
│   RUNNING       │  Container is running
│  (not ready)    │  Waiting for readiness probe
│                 │  
│                 │  Readiness probe checks:
│                 │  ├─ Initial delay: 5s
│                 │  ├─ Period: 5s
│                 │  └─ HTTP GET http://pod-ip:80/
└────────┬────────┘
         │
         │ Readiness probe succeeds
         ▼
┌─────────────────┐
│   READY         │  Pod added to Service endpoints
│                 │  Can receive traffic
│                 │  
│                 │  Liveness probe checks:
│                 │  ├─ Initial delay: 30s
│                 │  ├─ Period: 10s
│                 │  └─ HTTP GET http://pod-ip:80/
└────────┬────────┘
         │
         │ All replicas ready
         ▼
┌─────────────────┐
│   AVAILABLE     │  Deployment fully available
│                 │  Ready for traffic
│                 │  Min replicas met
└─────────────────┘

Failure States:
┌─────────────────┐
│ IMAGE PULL ERR  │ ← Can't pull image
└─────────────────┘

┌─────────────────┐
│ CRASH LOOP BACK │ ← Container crashes repeatedly
└─────────────────┘

┌─────────────────┐
│    EVICTED      │ ← Not enough resources
└─────────────────┘
```

---

## Component Interaction Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                      COMPONENT INTERACTIONS                          │
└──────────────────────────────────────────────────────────────────────┘

Developer
    │
    │ 1. Runs ./quickstart.sh deploy
    ▼
quickstart.sh
    │
    ├─ 2. Checks prerequisites
    │     ├─ Docker installed?
    │     ├─ kubectl installed?
    │     └─ K8s cluster running?
    │
    ├─ 3. Setup Python environment
    │     ├─ python3 -m venv venv
    │     ├─ pip install ansible
    │     └─ ansible-galaxy collection install kubernetes.core
    │
    ├─ 4. Build Docker image
    │     │
    │     └──► Docker Engine
    │              │
    │              ├─ Reads Dockerfile
    │              ├─ Pulls nginx:alpine
    │              ├─ Runs build steps
    │              └─ Tags image: webapp:latest
    │
    └─ 5. Run Ansible playbook
          │
          └──► Ansible Engine
                   │
                   ├─ 6. Loads playbooks/deploy-webapp.yml
                   │
                   ├─ 7. Loads group_vars/all.yml
                   │     ├─ app_name: webapp
                   │     ├─ replicas: 2
                   │     ├─ k8s_namespace: webapp
                   │     └─ ... (other variables)
                   │
                   ├─ 8. Executes pre-tasks
                   │     ├─ kubectl version --client
                   │     └─ kubectl cluster-info
                   │
                   ├─ 9. Runs role: webapp
                   │     │
                   │     └──► webapp/tasks/main.yml
                   │              │
                   │              ├─ 10. Install Python packages
                   │              │      pip install kubernetes openshift PyYAML
                   │              │
                   │              ├─ 11. Create namespace
                   │              │      kubernetes.core.k8s
                   │              │         └──► Kubernetes API Server
                   │              │                  │
                   │              │                  └─ Creates namespace: webapp
                   │              │
                   │              ├─ 12. Create ConfigMap
                   │              │      kubernetes.core.k8s
                   │              │         └──► Kubernetes API Server
                   │              │                  │
                   │              │                  └─ Creates ConfigMap: webapp-config
                   │              │
                   │              ├─ 13. Process deployment template
                   │              │      ├─ Read templates/deployment.yml.j2
                   │              │      ├─ Replace {{ variables }}
                   │              │      └─ Generate YAML
                   │              │
                   │              ├─ 14. Deploy application
                   │              │      kubernetes.core.k8s
                   │              │         └──► Kubernetes API Server
                   │              │                  │
                   │              │                  ├─ Creates Deployment: webapp
                   │              │                  │
                   │              │                  └──► Deployment Controller
                   │              │                           │
                   │              │                           └─ Creates ReplicaSet
                   │              │                                    │
                   │              │                                    └──► ReplicaSet Controller
                   │              │                                             │
                   │              │                                             └─ Creates 2 Pods
                   │              │                                                      │
                   │              │                                                      └──► Scheduler
                   │              │                                                               │
                   │              │                                                               └─ Assigns to nodes
                   │              │                                                                        │
                   │              │                                                                        └──► Kubelet
                   │              │                                                                                 │
                   │              │                                                                                 ├─ Pulls image
                   │              │                                                                                 ├─ Starts container
                   │              │                                                                                 └─ Runs probes
                   │              │
                   │              ├─ 15. Process service template
                   │              │      ├─ Read templates/service.yml.j2
                   │              │      ├─ Replace {{ variables }}
                   │              │      └─ Generate YAML
                   │              │
                   │              ├─ 16. Create service
                   │              │      kubernetes.core.k8s
                   │              │         └──► Kubernetes API Server
                   │              │                  │
                   │              │                  └─ Creates Service: webapp-service
                   │              │                           │
                   │              │                           └──► Service Controller
                   │              │                                    │
                   │              │                                    ├─ Creates endpoints
                   │              │                                    └─ Configures LoadBalancer
                   │              │
                   │              └─ 17. Wait for deployment ready
                   │                     kubernetes.core.k8s_info
                   │                        │
                   │                        └─ Poll deployment status
                   │                           (retries: 60, delay: 5s)
                   │
                   └─ 18. Executes post-tasks
                         ├─ Get pods
                         ├─ Display pod status
                         └─ Show deployment summary

Final State:
    ├─ Namespace created ✓
    ├─ ConfigMap created ✓
    ├─ Deployment created ✓
    ├─ 2 Pods running ✓
    ├─ Service exposed ✓
    └─ Application accessible at http://localhost ✓
```

---

## Network Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                     NETWORK ARCHITECTURE                             │
└──────────────────────────────────────────────────────────────────────┘

Host Network (Docker Desktop)
├─ Interface: en0
└─ IP: 192.168.1.x (DHCP)

       │
       │ Port mapping
       ▼

Docker Bridge Network
├─ Interface: docker0
├─ Subnet: 172.17.0.0/16
└─ Gateway: 172.17.0.1

       │
       │ CNI (Container Network Interface)
       ▼

Kubernetes Pod Network
├─ CNI Plugin: Docker Desktop default
├─ Pod CIDR: 10.244.0.0/16
└─ Pods:
    ├─ webapp-xxxxx-1: 10.244.0.5
    └─ webapp-xxxxx-2: 10.244.0.6

       │
       │ Service abstraction
       ▼

Kubernetes Service Network
├─ Service CIDR: 10.96.0.0/12
└─ Services:
    ├─ kubernetes (default): 10.96.0.1
    ├─ kube-dns: 10.96.0.10
    └─ webapp-service: 10.96.1.100

       │
       │ Load balancing
       ▼

LoadBalancer (Docker Desktop)
├─ External IP: localhost
└─ Port: 80

       │
       │ Client access
       ▼

User Browser
└─ URL: http://localhost


Traffic Flow Details:

1. Browser Request
   └─ http://localhost:80

2. Docker Desktop LoadBalancer
   ├─ Receives on localhost:80
   └─ Routes to Service ClusterIP: 10.96.1.100:80

3. Service (webapp-service)
   ├─ ClusterIP: 10.96.1.100
   ├─ Selector: app=webapp
   ├─ Endpoints:
   │  ├─ 10.244.0.5:80 (Pod 1)
   │  └─ 10.244.0.6:80 (Pod 2)
   └─ Load balances using iptables rules

4. Pod (selected by Service)
   ├─ Pod IP: 10.244.0.5 or 10.244.0.6
   ├─ Container Port: 80
   └─ nginx listening on 0.0.0.0:80

5. Response
   └─ Flows back through same path in reverse


DNS Resolution:

Internal K8s DNS:
├─ webapp-service.webapp.svc.cluster.local → 10.96.1.100
├─ webapp-service.webapp.svc → 10.96.1.100
├─ webapp-service.webapp → 10.96.1.100
└─ webapp-service → 10.96.1.100 (if in same namespace)
```

---

## Storage Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                     STORAGE ARCHITECTURE                             │
└──────────────────────────────────────────────────────────────────────┘

Container Image Storage
└─ Docker Desktop Storage
   ├─ Location: ~/Library/Containers/com.docker.docker/
   ├─ Images:
   │  ├─ nginx:alpine
   │  └─ webapp:latest
   └─ Layers (shared):
      ├─ Layer 1: nginx base
      ├─ Layer 2: nginx config
      ├─ Layer 3: app files (index.html)
      └─ Total size: ~8MB


ConfigMap Storage (Kubernetes etcd)
└─ webapp-config
   ├─ Namespace: webapp
   ├─ Data:
   │  └─ app.conf: |
   │     server_name: webapp
   │     environment: production
   └─ Mounted in Pod at: /etc/config/


Pod Storage
├─ Pod 1: webapp-xxxxx-1
│  └─ Volumes:
│     ├─ config (ConfigMap)
│     │  ├─ Source: webapp-config
│     │  └─ Mount: /etc/config/
│     │
│     └─ Container filesystem (ephemeral)
│        ├─ /usr/share/nginx/html/index.html (from image)
│        ├─ /etc/nginx/conf.d/default.conf (from image)
│        └─ /var/log/nginx/ (ephemeral)
│
└─ Pod 2: webapp-xxxxx-2
   └─ (same structure as Pod 1)


Kubernetes Metadata Storage (etcd)
└─ Cluster state database
   ├─ Namespaces
   │  └─ webapp
   ├─ ConfigMaps
   │  └─ webapp/webapp-config
   ├─ Deployments
   │  └─ webapp/webapp
   ├─ ReplicaSets
   │  └─ webapp/webapp-xxxxxxxxx
   ├─ Pods
   │  ├─ webapp/webapp-xxxxx-1
   │  └─ webapp/webapp-xxxxx-2
   └─ Services
      └─ webapp/webapp-service


Note: This deployment uses ephemeral storage only.
For persistent data, you would add:
├─ PersistentVolume (PV)
├─ PersistentVolumeClaim (PVC)
└─ Mount PVC in Pod spec
```

---

## Security Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                     SECURITY ARCHITECTURE                            │
└──────────────────────────────────────────────────────────────────────┘

GitHub Level Security
├─ Repository Access Control
│  ├─ Branch protection (main)
│  ├─ Required reviews
│  └─ Status checks
│
├─ Secrets Management
│  ├─ GITHUB_TOKEN (automatic)
│  └─ No hardcoded credentials
│
└─ Security Scanning (GitHub Actions)
   ├─ Trivy vulnerability scan
   ├─ SARIF report generation
   └─ Security tab alerts


Container Image Security
├─ Base Image: nginx:alpine
│  ├─ Minimal attack surface
│  ├─ Official image (trusted)
│  └─ Regularly updated
│
├─ Image Scanning (Trivy)
│  ├─ CVE detection
│  ├─ Dependency checking
│  └─ Configuration issues
│
└─ Image Attestation
   ├─ Build provenance
   └─ Signature verification


Kubernetes Security
├─ Namespace Isolation
│  └─ webapp namespace (logical isolation)
│
├─ Resource Limits
│  ├─ CPU: 500m max
│  ├─ Memory: 512Mi max
│  └─ Prevents resource exhaustion
│
├─ Network Policies (not configured)
│  └─ Default: All traffic allowed
│
├─ Pod Security (not configured)
│  └─ Default: Permissive
│
└─ RBAC (default)
   └─ Uses default service account


Application Security
├─ nginx Configuration
│  ├─ No directory listing
│  ├─ Custom error pages
│  └─ Access logging
│
├─ Health Endpoint
│  └─ /health (no sensitive data)
│
└─ Static Content Only
   └─ No dynamic code execution


Network Security
├─ Service Type: LoadBalancer
│  ├─ Exposed on localhost only
│  └─ Not internet-facing
│
├─ No TLS/HTTPS
│  └─ OK for local development
│  └─ SHOULD add for production
│
└─ Session Affinity
   └─ ClientIP (prevents session hijacking)


Deployment Security
├─ Ansible Execution
│  ├─ Runs on localhost
│  ├─ No remote SSH
│  └─ Uses kubectl authentication
│
├─ Image Pull Policy: IfNotPresent
│  └─ Uses local image if available
│
└─ No Secrets in Git
   ├─ .gitignore configured
   └─ Secrets should use K8s Secrets


Security Recommendations for Production:
├─ Add TLS/HTTPS
├─ Implement Network Policies
├─ Enable Pod Security Standards
├─ Use non-root user in container
├─ Add image signing
├─ Implement RBAC policies
├─ Use Secrets for sensitive data
├─ Enable audit logging
└─ Regular security scans
```

---

## Monitoring & Observability

```
┌──────────────────────────────────────────────────────────────────────┐
│              MONITORING & OBSERVABILITY ARCHITECTURE                 │
└──────────────────────────────────────────────────────────────────────┘

Built-in Kubernetes Monitoring
├─ kubectl get pods -n webapp
│  └─ Shows: NAME, READY, STATUS, RESTARTS, AGE
│
├─ kubectl describe pod <pod-name> -n webapp
│  └─ Shows: Events, Conditions, Volumes, etc.
│
├─ kubectl logs -n webapp -l app=webapp -f
│  └─ Shows: nginx access logs, error logs
│
└─ kubectl top pods -n webapp (requires metrics-server)
   └─ Shows: CPU, Memory usage


Health Checks (Built-in)
├─ Liveness Probe
│  ├─ Type: HTTP GET
│  ├─ Path: /
│  ├─ Port: 80
│  ├─ Initial Delay: 30s
│  ├─ Period: 10s
│  └─ Purpose: Restart if unhealthy
│
└─ Readiness Probe
   ├─ Type: HTTP GET
   ├─ Path: /
   ├─ Port: 80
   ├─ Initial Delay: 5s
   ├─ Period: 5s
   └─ Purpose: Remove from service if not ready


Prometheus Annotations (Ready for scraping)
└─ Pod annotations:
   ├─ prometheus.io/scrape: "true"
   ├─ prometheus.io/port: "80"
   └─ prometheus.io/path: "/metrics" (would need implementation)


Logging Architecture
├─ nginx Access Logs
│  ├─ Location: /var/log/nginx/access.log
│  ├─ Format: combined
│  └─ Captured by: kubectl logs
│
├─ nginx Error Logs
│  ├─ Location: /var/log/nginx/error.log
│  ├─ Level: error
│  └─ Captured by: kubectl logs
│
└─ Container stdout/stderr
   └─ Captured by: Docker logging driver


Events
├─ Kubernetes Events
│  ├─ kubectl get events -n webapp
│  └─ Shows: Scheduling, Pulling, Started, Killing, etc.
│
└─ Event Retention
   └─ Default: 1 hour


Diagnostic Tools (Included)
├─ diagnose.sh
│  ├─ Shows namespace status
│  ├─ Shows deployment status
│  ├─ Shows pod details
│  ├─ Shows recent events
│  └─ Shows pod logs
│
└─ quickstart.sh test
   └─ Tests application health via HTTP


Metrics Available (via kubectl)
├─ Deployment Metrics
│  ├─ Replicas (desired vs available)
│  ├─ Updated replicas
│  └─ Ready replicas
│
├─ Pod Metrics
│  ├─ Status (Running, Pending, Failed)
│  ├─ Restart count
│  └─ Age
│
└─ Service Metrics
   ├─ Type
   ├─ ClusterIP
   └─ External IP


Observability Enhancements (Not Implemented)
Could add:
├─ Prometheus
│  └─ Metrics collection and storage
│
├─ Grafana
│  └─ Visualization dashboards
│
├─ Elasticsearch, Fluentd, Kibana (EFK)
│  └─ Centralized logging
│
├─ Jaeger or Zipkin
│  └─ Distributed tracing
│
└─ Alertmanager
   └─ Alert routing and silencing
```

This architecture provides a complete picture of how all components work together to deliver a production-ready deployment workflow.
