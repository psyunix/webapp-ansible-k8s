# Web App Deployment with Ansible on Kubernetes

Complete automation workflow for deploying web applications to Kubernetes using Ansible, Docker Desktop, and GitHub Actions.

[![Build and Deploy](https://github.com/psyunix/webapp-ansible-k8s/actions/workflows/deploy.yml/badge.svg)](https://github.com/psyunix/webapp-ansible-k8s/actions/workflows/deploy.yml)

## 🚀 Quick Start

```bash
# Clone repository test
git clone https://github.com/psyunix/webapp-ansible-k8s.git
cd webapp-ansible-k8s

# Deploy in one command
./quickstart.sh deploy

# Access application
curl http://localhost
```

## 📋 Prerequisites

- **macOS** (Monterey or later)
- **Docker Desktop** with Kubernetes enabled
- **Python 3.9+**
- **kubectl**

### Install Prerequisites

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install tools
brew install python@3.11 kubectl

# Verify installations
docker --version
kubectl version --client
python3 --version
```

### Enable Kubernetes in Docker Desktop

1. Open Docker Desktop
2. Go to **Settings** → **Kubernetes**
3. Check **Enable Kubernetes**
4. Click **Apply & Restart**

## 🏗️ Architecture

```
Developer Machine → Ansible → Kubernetes (Docker Desktop)
                                  ↓
                        Deployment (2 pods)
                                  ↓
                          LoadBalancer Service
                                  ↓
                        http://localhost:80
```

## 📦 Project Structure

```
webapp-ansible-k8s/
├── ansible/                  # Ansible automation
│   ├── inventory/           # Configuration
│   ├── playbooks/           # Deploy & rollback
│   └── roles/webapp/        # Kubernetes templates
├── app/                     # Web application
│   ├── src/index.html      # App code
│   └── Dockerfile          # Container config
├── .github/workflows/       # GitHub Actions CI/CD
├── Makefile                # Automation commands
└── quickstart.sh           # Quick deployment script
```

## 🎯 Usage

### Option 1: Quickstart Script (Recommended)

```bash
./quickstart.sh deploy    # Full deployment
./quickstart.sh status    # Check status
./quickstart.sh logs      # View logs
./quickstart.sh clean     # Clean up
```

### Option 2: Makefile

```bash
make help                 # Show all commands
make full-deploy         # Complete deployment
make status              # Check status
make logs                # Stream logs
make scale REPLICAS=5    # Scale deployment
make rollback            # Rollback deployment
make clean               # Clean up
```

### Option 3: Manual Deployment

```bash
# Setup environment
python3 -m venv venv
source venv/bin/activate
pip install ansible kubernetes openshift PyYAML
ansible-galaxy collection install kubernetes.core

# Build image
cd app
docker build -t ghcr.io/psyunix/webapp:latest .
cd ..

# Deploy
cd ansible
ansible-playbook playbooks/deploy-webapp.yml
```

## 🔑 Key Commands

```bash
# Check deployment
kubectl get all -n webapp

# View logs
kubectl logs -n webapp -l app=webapp -f

# Scale
kubectl scale deployment/webapp -n webapp --replicas=3

# Rollback
kubectl rollout undo deployment/webapp -n webapp

# Access app
curl http://localhost
```

## ⚙️ Configuration

Edit `ansible/inventory/group_vars/all.yml`:

```yaml
# Scale replicas
replicas: 2

# Resource limits
cpu_limit: "500m"
memory_limit: "512Mi"

# Service type
service_type: LoadBalancer

# Environment variables
app_env_vars:
  - name: ENVIRONMENT
    value: "production"
```

## 🔄 Common Workflows

### Deploy Update

```bash
# Edit application
vim app/src/index.html

# Rebuild and deploy
make build deploy VERSION=v2.0.0

# Or use quickstart
./quickstart.sh deploy
```

### Scale Application

```bash
# Using make
make scale REPLICAS=5

# Using kubectl
kubectl scale deployment/webapp -n webapp --replicas=5
```

### Rollback

```bash
# Using make
make rollback

# Using Ansible
cd ansible
ansible-playbook playbooks/rollback.yml

# Using kubectl
kubectl rollout undo deployment/webapp -n webapp
```

## 🤖 GitHub Actions CI/CD

The project includes automated CI/CD:

- **Triggers**: Push to main, pull requests, tags
- **Build**: Multi-platform Docker images (amd64, arm64)
- **Security**: Trivy vulnerability scanning
- **Deploy**: Ansible deployment (dry-run in CI)

### Setup GitHub Container Registry

```bash
# Generate token at https://github.com/settings/tokens
# Scopes: write:packages, read:packages

# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u psyunix --password-stdin

# Push image
docker push ghcr.io/psyunix/webapp:latest
```

### Create Release

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

## 🐛 Troubleshooting

### Kubernetes Not Running

```bash
# Check cluster
kubectl cluster-info

# Enable in Docker Desktop:
# Settings → Kubernetes → Enable Kubernetes
```

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n webapp

# Describe pod
kubectl describe pod -n webapp <pod-name>

# Check logs
kubectl logs -n webapp <pod-name>
```

### Service Not Accessible

```bash
# Port forward
kubectl port-forward -n webapp svc/webapp-service 8080:80

# Test
curl http://localhost:8080
```

### Image Pull Errors

```bash
# Make package public
# Go to: https://github.com/psyunix?tab=packages
# Click package → Settings → Change visibility

# Or create secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=psyunix \
  --docker-password=$GITHUB_TOKEN \
  -n webapp
```

## 📚 Documentation

- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Step-by-step deployment instructions
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Architecture and overview
- **[SETUP_CHECKLIST.md](SETUP_CHECKLIST.md)** - Pre-deployment verification
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - 30-minute quick start guide

## ✨ Features

- ✅ Automated deployment with Ansible
- ✅ Kubernetes orchestration
- ✅ Rolling updates with zero downtime
- ✅ Automatic rollback capability
- ✅ Health checks (liveness & readiness)
- ✅ Resource management
- ✅ LoadBalancer service
- ✅ GitHub Actions CI/CD
- ✅ Security scanning
- ✅ Multi-platform builds

## 🎓 Learning Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [GitHub Actions Documentation](https://docs.github.com/actions)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📝 License

MIT License - See LICENSE file for details

## 👤 Author

**psyunix**
- GitHub: [@psyunix](https://github.com/psyunix)
- Organization: University of Hawaii at Manoa - ITS

## 🙏 Acknowledgments

- Built with experience from 20 years of IT leadership
- Leveraging Azure, AWS, and cloud-native technologies
- Focus on DevOps automation and infrastructure as code

---

**Happy Deploying! 🚀**
