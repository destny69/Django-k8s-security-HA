# Kubernetes Deployment Guide

## Quick Start

### 1. Prerequisites

Install required tools:

```bash
# kubectl - Kubernetes CLI
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# kustomize - Kubernetes manifest generator
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/

# Docker - For building images
# https://docs.docker.com/install/
```

### 2. Configure kubectl

```bash
# Point kubectl to your cluster
kubectl config use-context your-cluster-context

# Verify connection
kubectl cluster-info
```

### 3. Build and Push Docker Image

```bash
# Build the Django app image
docker build -t your-registry/django-app:latest .

# Push to registry
docker push your-registry/django-app:latest

# Update image reference in kustomization files if using a different registry
# Edit: k8s/overlays/production/kustomization.yaml
# Edit: k8s/overlays/staging/kustomization.yaml
# Edit: k8s/overlays/dev/kustomization.yaml
```

### 4. Update Secrets

```bash
# Edit secret file with real values
nano k8s/secret.yaml

# Apply secrets (will be created with namespace)
# kubectl apply -f k8s/secret.yaml
```

### 5. Deploy

#### Option A: Using deployment script (recommended)

```bash
chmod +x deploy.sh
./deploy.sh production    # Deploy to production
./deploy.sh staging       # Deploy to staging
./deploy.sh dev           # Deploy to dev
```

#### Option B: Manual deployment

```bash
# Production
kubectl apply -k k8s/overlays/production

# Staging
kubectl apply -k k8s/overlays/staging

# Development
kubectl apply -k k8s/overlays/dev
```

### 6. Verify Deployment

```bash
chmod +x status.sh
./status.sh production

# Or manually
kubectl get all -n django-auth
kubectl get pods -n django-auth -w
```

## Environment-Specific Configurations

### Development Environment

**Namespace**: `django-auth-dev`
**Replicas**: 1 (Django), 1 (Postgres), 1 (Traefik)
**Debug**: Enabled
**Auto-scaling**: 1-2 replicas

Deploy:

```bash
./deploy.sh dev
```

### Staging Environment

**Namespace**: `django-auth-staging`
**Replicas**: 2 (Django), 1 (Postgres), 1 (Traefik)
**Debug**: Disabled
**Auto-scaling**: 2-5 replicas

Deploy:

```bash
./deploy.sh staging
```

### Production Environment

**Namespace**: `django-auth`
**Replicas**: 3 (Django), 1 (Postgres), 1 (Traefik)
**Debug**: Disabled
**Auto-scaling**: 3-10 replicas
**Features**: PDB, higher resource limits, strict metrics

Deploy:

```bash
./deploy.sh production
```

## Common Operations

### View Logs

```bash
# Real-time logs
kubectl logs -n django-auth deployment/django-app -f

# Specific pod
kubectl logs -n django-auth pod/django-app-xxxxx -f

# Previous instance (for crash debugging)
kubectl logs -n django-auth pod/django-app-xxxxx --previous

# WAF logs
kubectl logs -n django-auth deployment/waf -f

# Traefik logs
kubectl logs -n django-auth deployment/traefik -f
```

### Access Services

```bash
# Django app
kubectl port-forward -n django-auth svc/django-app 8000:8000
# Access at http://localhost:8000

# Traefik dashboard
kubectl port-forward -n django-auth svc/traefik 8080:8080
# Access at http://localhost:8080/dashboard

# PostgreSQL
kubectl port-forward -n django-auth svc/postgres 5432:5432
# Connect at localhost:5432
```

### Scale Deployments

```bash
# Scale manually
kubectl scale deployment/django-app --replicas=5 -n django-auth

# HPA will auto-scale based on metrics
kubectl get hpa -n django-auth -w

# Edit HPA settings
kubectl edit hpa django-app-hpa -n django-auth
```

### Database Operations

```bash
# Backup database
chmod +x backup-db.sh
./backup-db.sh production

# Restore database
./restore-db.sh production backups/django_production_20240101_120000.sql

# Connect to database shell
kubectl exec -it -n django-auth postgres-xxxxx -- psql -U django django_auth

# Run migrations
kubectl exec -n django-auth deployment/django-app -- python manage.py migrate

# Create superuser
kubectl exec -it -n django-auth deployment/django-app -- python manage.py createsuperuser
```

### Update Configuration

```bash
# Update ConfigMap
kubectl edit configmap django-config -n django-auth

# Restart deployment to apply changes
kubectl rollout restart deployment/django-app -n django-auth

# Update Secret
kubectl patch secret django-secret -n django-auth --type merge \
  -p '{"data":{"DJANGO_SECRET_KEY":"base64-encoded-value"}}'
```

### Update Application

```bash
# Update image
kubectl set image deployment/django-app \
  django-app=your-registry/django-app:v1.2.3 \
  -n django-auth

# Watch rollout
kubectl rollout status deployment/django-app -n django-auth

# Rollback if needed
kubectl rollout undo deployment/django-app -n django-auth
```

## Troubleshooting

### Pod not starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n django-auth

# Check events
kubectl get events -n django-auth --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n django-auth
```

### Database connection failed

```bash
# Verify postgres service
kubectl get svc postgres -n django-auth
kubectl get endpoints postgres -n django-auth

# Test connectivity
kubectl run -it --rm debug --image=python:3.12 --restart=Never -- \
  psql postgresql://django:password@postgres.django-auth.svc.cluster.local/django_auth

# Check postgres logs
kubectl logs deployment/postgres -n django-auth
```

### Persistent Volume not mounting

```bash
# Check PVC status
kubectl get pvc -n django-auth

# Describe PVC for events
kubectl describe pvc postgres-pvc -n django-auth

# Check storage class
kubectl get storageclass
kubectl describe storageclass <name>
```

### High resource usage

```bash
# Check pod resource usage
kubectl top pods -n django-auth

# Check node usage
kubectl top nodes

# Check HPA status
kubectl describe hpa django-app-hpa -n django-auth

# View metrics
kubectl get hpa django-app-hpa -n django-auth --watch
```

## Monitoring

### Prometheus Metrics

Add ServiceMonitor for Prometheus:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: django-app
  namespace: django-auth
spec:
  selector:
    matchLabels:
      app: django-app
  endpoints:
  - port: http
    interval: 30s
```

### Loki Logs

Scrape pod logs:

```yaml
apiVersion: loki.grafana.com/v1
kind: LokiStack
metadata:
  name: django-auth
  namespace: django-auth
spec:
  size: 1x.small
  storage:
    schemas:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      index:
        prefix: index_
        period: 24h
```

## Security Best Practices

1. **Network Policies**: Restrict pod-to-pod communication
2. **Pod Security Standards**: Apply baseline or restricted PSS
3. **RBAC**: Use least privilege service accounts
4. **Secrets Management**: Use Sealed Secrets or External Secrets Operator
5. **Image Security**: Scan images for vulnerabilities
6. **Resource Quotas**: Set namespace-level resource limits

## Backup and Disaster Recovery

### Database Backups

```bash
# Daily backup (add to crontab)
0 2 * * * cd /path/to/django && ./backup-db.sh production >> /var/log/k8s-backup.log 2>&1

# Restore from backup
./restore-db.sh production backups/django_production_20240101_000000.sql
```

### Manifest Backups

```bash
# Backup current manifests
kubectl get all -n django-auth -o yaml > backup-manifests.yaml

# Restore from backup
kubectl apply -f backup-manifests.yaml
```

## Performance Tuning

### Database Optimization

```bash
# Connect to PostgreSQL
kubectl exec -it postgres-xxxxx -- psql -U django django_auth

# Analyze tables
ANALYZE;

# Check indexes
\d

# Monitor slow queries
ALTER SYSTEM SET log_min_duration_statement = 1000;
SELECT pg_reload_conf();
```

### Application Optimization

- Increase gunicorn workers: Edit deployment `--workers` argument
- Enable caching: Configure Django cache backend
- Use CDN: Configure static file serving through CloudFront/Cloudflare
- Database connection pooling: Use PgBouncer

## Cleanup

```bash
# Remove all resources for environment
chmod +x cleanup.sh
./cleanup.sh production    # Removes django-auth namespace
./cleanup.sh staging       # Removes django-auth-staging namespace
./cleanup.sh dev           # Removes django-auth-dev namespace
```

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Guide](https://kustomize.io/)
- [Traefik Kubernetes](https://doc.traefik.io/traefik/providers/kubernetes-crd/)
- [Django Deployment Checklist](https://docs.djangoproject.com/en/6.0/howto/deployment/checklist/)
