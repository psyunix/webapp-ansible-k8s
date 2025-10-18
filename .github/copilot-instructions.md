# AI Agent Instructions for webapp-ansible-k8s

## Project Overview
This project automates web application deployment to Kubernetes using Ansible and Docker Desktop. The architecture flows from developer machine → Ansible → Kubernetes (Docker Desktop) → LoadBalancer Service.

## Key Architecture Components

### 1. Ansible Automation (`ansible/`)
- **Playbooks**: Core deployment logic in `playbooks/deploy-webapp.yml`
- **Roles**: Kubernetes resource templates in `roles/webapp/templates/`
- **Variables**: Configuration in `inventory/group_vars/all.yml`

### 2. Application (`app/`)
- Single-container web application defined in `Dockerfile`
- Source code in `src/index.html`

### 3. Kubernetes Resources
- Created from Jinja2 templates (`roles/webapp/templates/`)
- Uses RollingUpdate strategy with zero-downtime deployments
- Includes ConfigMap for app configuration
- Exposes service via LoadBalancer

## Development Workflows

### Local Development
```bash
# Quick deployment
./quickstart.sh deploy

# Check deployment
./quickstart.sh status
./quickstart.sh logs

# Clean up
./quickstart.sh clean
```

### Advanced Operations (via Makefile)
- `make scale REPLICAS=5` - Scale deployment
- `make rollback` - Rollback to previous version
- `make full-deploy` - Complete deployment pipeline

## Project Conventions

### Kubernetes Configuration
- Uses Docker Desktop's built-in Kubernetes
- Default namespace: Defined in `inventory/group_vars/all.yml`
- Resource templates use variables from `roles/webapp/defaults/`
- RollingUpdate strategy ensures zero-downtime deployments

### Ansible Patterns
- Local connection for Kubernetes operations
- Pre-flight checks for dependencies
- Post-deployment validation of pod status
- Uses kubernetes.core collection for k8s operations

### Error Handling
- Validates prerequisites before deployment
- Waits for deployment readiness
- Includes rollback capabilities via `playbooks/rollback.yml`

## Integration Points
1. Kubernetes API (via kubectl)
2. Docker Desktop for local cluster
3. Container registry (local Docker daemon)
4. LoadBalancer service (port 80)

## Common Issues & Solutions
1. **Issue**: Kubernetes not running
   - Check Docker Desktop → Settings → Kubernetes
   - Run `kubectl cluster-info` for status

2. **Issue**: Port conflicts
   - Default port 80 configurable in `inventory/group_vars/all.yml`
   - Use `netstat -an | grep LISTEN` to check ports

3. **Issue**: Deployment failures
   - Check logs: `./quickstart.sh logs`
   - Verify Python dependencies: `pip install kubernetes openshift PyYAML`