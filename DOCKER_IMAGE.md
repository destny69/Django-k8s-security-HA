# Docker Image for Kubernetes

To use these Kubernetes manifests, you need to build and push the Docker image to your registry.

## Building the Image

```bash
# Build the image
docker build -t your-registry/django-app:latest .
docker build -t your-registry/django-app:v1.0.0 .

# Push to registry
docker push your-registry/django-app:latest
docker push your-registry/django-app:v1.0.0
```

## Docker Registry Options

### Docker Hub

```bash
docker build -t yourusername/django-app:latest .
docker push yourusername/django-app:latest
```

### AWS ECR

```bash
# Authenticate
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

# Build and push
docker build -t 123456789012.dkr.ecr.us-east-1.amazonaws.com/django-app:latest .
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/django-app:latest
```

### Google Container Registry

```bash
# Authenticate
gcloud auth configure-docker

# Build and push
docker build -t gcr.io/your-project/django-app:latest .
docker push gcr.io/your-project/django-app:latest
```

### Azure Container Registry

```bash
# Authenticate
az acr login --name myregistry

# Build and push
docker build -t myregistry.azurecr.io/django-app:latest .
docker push myregistry.azurecr.io/django-app:latest
```

## Updating Image Reference in Kubernetes

Edit the Kustomization files to use your registry:

**k8s/kustomization.yaml**:
```yaml
images:
  - name: django-app
    newName: your-registry/django-app
    newTag: latest
```

Or for specific environments:

**k8s/overlays/production/kustomization.yaml**:
```yaml
images:
  - name: django-app
    newName: your-registry/django-app
    newTag: v1.0.0
```

## Image Pull Secrets

If your registry requires authentication:

```bash
# Create secret for private registry
kubectl create secret docker-registry regcred \
  --docker-server=your-registry.com \
  --docker-username=yourusername \
  --docker-password=yourpassword \
  --docker-email=your@email.com \
  -n django-auth

# Update deployment to use the secret
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "regcred"}]}' -n django-auth
```

Or in the deployment manifest:

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
      - name: regcred
      containers:
      - name: django-app
        image: your-registry/django-app:latest
```

## Tags and Versions

Use semantic versioning for production:

```bash
# Build with version tag
docker build -t your-registry/django-app:1.0.0 .
docker push your-registry/django-app:1.0.0

# Update deployment
kubectl set image deployment/django-app \
  django-app=your-registry/django-app:1.0.0 \
  -n django-auth --record
```

## Monitoring Image Updates

```bash
# Watch rollout
kubectl rollout status deployment/django-app -n django-auth -w

# View rollout history
kubectl rollout history deployment/django-app -n django-auth

# Rollback if needed
kubectl rollout undo deployment/django-app -n django-auth
```
