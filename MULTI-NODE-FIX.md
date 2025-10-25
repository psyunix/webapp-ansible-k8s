# Multi-Node Docker Desktop Kubernetes Issue - SOLVED

## The Problem We Found

Your Docker Desktop Kubernetes cluster has **3 nodes**:
- `desktop-control-plane` (control plane, NotReady)
- `desktop-worker` (worker node)
- `desktop-worker2` (worker node)

### What Was Happening

1. You build Docker image: `docker build -t webapp:latest ./app`
   - Image is stored in your **Mac's Docker daemon**
   
2. You deploy to Kubernetes
   - Kubernetes tries to run pods on **worker nodes**
   - Worker nodes have their **own containerd image cache**
   - Worker nodes DON'T have access to your Mac's Docker images!
   
3. Result: Pods use old cached images from worker nodes, not your new build

### The Root Cause

```
┌─────────────────┐
│   Your Mac      │  ← You build image here
│  Docker Daemon  │
└─────────────────┘
        ↓
        ✗ Images NOT automatically shared
        ↓
┌──────────────────────────────────────┐
│    Kubernetes Worker Nodes           │
│  ┌─────────────┐  ┌─────────────┐   │
│  │desktop-     │  │desktop-     │   │
│  │worker       │  │worker2      │   │  ← Pods run here
│  │(containerd) │  │(containerd) │   │  ← Need images here!
│  └─────────────┘  └─────────────┘   │
└──────────────────────────────────────┘
```

## The Solution

The updated `redeploy-now.sh` script now:

1. **Builds** the Docker image on your Mac
2. **Loads** the image into EACH worker node's containerd:
   ```bash
   docker save webapp:latest | docker exec -i desktop-worker ctr -n k8s.io images import -
   docker save webapp:latest | docker exec -i desktop-worker2 ctr -n k8s.io images import -
   ```
3. **Deploys** with Ansible
4. **Restarts** pods to pick up the new image

## Why This Happened

Docker Desktop Kubernetes can run in two modes:
- **Single node** (older setup) - shares Docker daemon directly
- **Multi-node** (your setup) - separate worker nodes with containerd

Multi-node is more realistic (like production), but requires image loading.

## Verification

After deployment, verify the new image is being used:
```bash
kubectl describe pod -n webapp | grep "Image ID:"
```

You should see the NEW SHA matching your fresh build!

## Alternative Solutions

### Option 1: Use Registry (Production-like)
- Push images to GHCR/Docker Hub
- Use `imagePullPolicy: Always`
- Workers pull from registry
- Best for production workflows

### Option 2: Single-node Mode
- Reset Docker Desktop Kubernetes to single-node
- Simpler for local dev
- Less realistic

### Option 3: Current Approach (Best for You)
- Keep multi-node (realistic)
- Use `redeploy-now.sh` to handle image loading
- Fast local iteration
- No registry needed
