# Deployment Modes

## Local Development Mode (Current Setup)

**What it does:**
- Builds Docker image locally on your Mac
- Deploys directly to Docker Desktop Kubernetes  
- Uses imagePullPolicy: Never (only uses local images)

**When to use:**
- Active development and testing
- Quick iteration cycles
- No internet required

**How to deploy:**
```bash
./redeploy-now.sh
```

## Remote Registry Mode (GHCR)

**What it does:**
- Pulls images from GitHub Container Registry (ghcr.io)
- Uses images built by GitHub Actions
- Uses imagePullPolicy: Always (always pulls latest)

**When to use:**
- Production deployments
- Staging environments  
- Team collaboration

## Your Current Workflow

1. Make changes to your code
2. Commit and push to GitHub
3. GitHub Actions builds and validates (pushes to GHCR)
4. Local deployment: Run ./redeploy-now.sh
   - Builds fresh Docker image locally
   - Deploys to your local Kubernetes

## Why You Werent Seeing Changes

**Problem:** imagePullPolicy: IfNotPresent + cached local image
- Kubernetes cached the webapp:latest image
- Even after rebuilding, it used the old cached version

**Solution:** imagePullPolicy: Never + explicit rebuild
- Forces Kubernetes to use only local Docker images
- Ensures fresh build every time via ./redeploy-now.sh

