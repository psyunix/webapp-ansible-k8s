# GitHub Container Registry (GHCR) Setup Guide

This guide explains how to push and manage Docker images in GitHub Container Registry for the `webapp-ansible-k8s` project.

## Quick Start

### Option 1: Using the Setup Script (Recommended)

```bash
# Run the complete setup (login, build, and push)
./scripts/ghcr-setup.sh

# Or run individual steps
./scripts/ghcr-setup.sh login   # Login to GHCR
./scripts/ghcr-setup.sh build   # Build the image
./scripts/ghcr-setup.sh push    # Push to GHCR
```

### Option 2: Manual Steps

#### 1. Create GitHub Personal Access Token

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Name: `GHCR_TOKEN` (or any name you prefer)
4. Select scopes:
   - ✅ `write:packages`
   - ✅ `read:packages`
   - ✅ `delete:packages` (optional)
5. Click "Generate token"
6. **Copy the token** (you won't see it again!)

#### 2. Login to GHCR

```bash
# Set your token as an environment variable (recommended)
export GITHUB_TOKEN=ghp_your_token_here

# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u psyunix --password-stdin
```

#### 3. Build the Docker Image

```bash
# Navigate to project root
cd /Users/psyunix/Documents/git/claude/ansible/webapp-ansible-k8s

# Build with proper tags
docker build -t ghcr.io/psyunix/webapp-ansible-k8s:latest ./app
docker build -t ghcr.io/psyunix/webapp-ansible-k8s:$(git rev-parse --short HEAD) ./app
```

#### 4. Push to GHCR

```bash
# Push the latest tag
docker push ghcr.io/psyunix/webapp-ansible-k8s:latest

# Push the commit-specific tag
docker push ghcr.io/psyunix/webapp-ansible-k8s:$(git rev-parse --short HEAD)
```

## Using GitHub Actions (Automatic)

Your workflow is already configured! Images are automatically built and pushed when you:

- Push to `main` or `develop` branches
- Create a tag (e.g., `v1.0.0`)
- Manually trigger the workflow

The workflow is at: `.github/workflows/deploy.yml`

### Trigger Workflow Manually

```bash
# Via GitHub CLI
gh workflow run deploy.yml

# Or go to: https://github.com/psyunix/webapp-ansible-k8s/actions
```

## Managing GHCR Packages

### View Your Packages

Visit: https://github.com/psyunix?tab=packages

### Make Package Public

1. Go to: https://github.com/users/psyunix/packages/container/webapp-ansible-k8s/settings
2. Scroll to "Danger Zone"
3. Click "Change visibility" → Select "Public"
4. Confirm the change

**Note:** Public packages can be pulled without authentication.

### Pull the Image

```bash
# If public
docker pull ghcr.io/psyunix/webapp-ansible-k8s:latest

# If private (requires login first)
echo $GITHUB_TOKEN | docker login ghcr.io -u psyunix --password-stdin
docker pull ghcr.io/psyunix/webapp-ansible-k8s:latest
```

## Using GHCR Images in Kubernetes

### For Public Images

Update your deployment to use the GHCR image:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  template:
    spec:
      containers:
      - name: webapp
        image: ghcr.io/psyunix/webapp-ansible-k8s:latest
```

### For Private Images

Create an image pull secret:

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=psyunix \
  --docker-password=$GITHUB_TOKEN \
  --docker-email=your-email@example.com
```

Then reference it in your deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  template:
    spec:
      imagePullSecrets:
      - name: ghcr-secret
      containers:
      - name: webapp
        image: ghcr.io/psyunix/webapp-ansible-k8s:latest
```

## Image Tagging Strategy

Your GitHub Actions workflow automatically creates these tags:

| Tag Type | Example | When Created |
|----------|---------|--------------|
| Latest | `latest` | On push to main branch |
| Branch | `main`, `develop` | On push to any branch |
| Commit SHA | `main-a1b2c3d` | Every commit |
| Semantic Version | `v1.0.0`, `1.0` | On git tags matching `v*` |
| PR | `pr-123` | On pull requests |

## Troubleshooting

### Error: "invalid tag format"

**Problem:** Tag contains invalid characters (e.g., `:-6f56fee`)

**Solution:** Ensure tag has no leading dashes or colons:
```bash
# ❌ Wrong
docker build -t ghcr.io/psyunix/webapp-ansible-k8s:-6f56fee

# ✅ Correct
docker build -t ghcr.io/psyunix/webapp-ansible-k8s:6f56fee
```

### Error: "unauthorized: unauthenticated"

**Problem:** Not logged in to GHCR

**Solution:**
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u psyunix --password-stdin
```

### Error: "denied: permission_denied"

**Problem:** Token doesn't have `write:packages` scope

**Solution:** Create a new token with the correct scopes (see step 1 above)

### Error: "Name does not match the repository"

**Problem:** Image name doesn't match repository structure

**Solution:** Use the full path:
```bash
ghcr.io/psyunix/webapp-ansible-k8s:tag
```

## Best Practices

1. **Use specific tags in production:** Avoid using `:latest` in production
2. **Keep packages private initially:** Test thoroughly before making public
3. **Use GitHub Actions:** Automate builds for consistency
4. **Tag semantically:** Use semantic versioning for releases (v1.0.0, v1.0.1)
5. **Clean up old images:** Delete unused tags to save space

## Resources

- [GitHub Packages Documentation](https://docs.github.com/en/packages)
- [Docker Documentation](https://docs.docker.com/)
- [Your Packages](https://github.com/psyunix?tab=packages)
- [Repository Actions](https://github.com/psyunix/webapp-ansible-k8s/actions)
