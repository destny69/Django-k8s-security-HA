# Kubernetes Deployment Package - Summary

This directory contains a complete Kubernetes deployment solution for the Django Auth application.

## 📦 What's Included

### Core Manifests (`k8s/`)
- **namespace.yaml** - Kubernetes namespace creation
- **configmap.yaml** - Django configuration (non-sensitive)
- **secret.yaml** - Sensitive data (SECRET_KEY, passwords)
- **postgres-*.yaml** - PostgreSQL database (deployment, service, PVC)
- **django-app-*.yaml** - Django application (deployment, service, HPA, RBAC)
- **traefik-*.yaml** - Traefik ingress controller (deployment, service, RBAC, PVC)
- **waf-*.yaml** - ModSecurity WAF (deployment, service, PVC)
- **ingress.yaml** - Kubernetes Ingress resource
- **kustomization.yaml** - Base Kustomize configuration

### Environment Overlays (`k8s/overlays/`)
- **dev/** - Development environment (1 replica, debug enabled)
- **staging/** - Staging environment (2 replicas, debug disabled)
- **production/** - Production environment (3 replicas, PDB, higher resources)

### Deployment Scripts
- **deploy.sh** - Deploy to any environment with safety checks
- **cleanup.sh** - Remove all resources for an environment
- **status.sh** - Check deployment status
- **backup-db.sh** - Backup PostgreSQL database
- **restore-db.sh** - Restore database from backup

### Documentation
- **KUBERNETES_GUIDE.md** - Comprehensive deployment and operations guide
- **KUBERNETES_ARCHITECTURE.md** - System architecture and component overview
- **DOCKER_IMAGE.md** - Docker image building and registry configuration
- **k8s/README.md** - Quick reference and troubleshooting

## 🚀 Quick Start

### 1. Prerequisites
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
```

### 2. Build Docker Image
```bash
docker build -t your-registry/django-app:latest .
docker push your-registry/django-app:latest
```

### 3. Update Configuration
```bash
# Edit secrets with real values
nano k8s/secret.yaml

# Edit ConfigMap if needed
nano k8s/configmap.yaml
```

### 4. Deploy
```bash
# Production
./deploy.sh production

# Staging
./deploy.sh staging

# Development
./deploy.sh dev
```

### 5. Monitor
```bash
./status.sh production
kubectl logs -n django-auth deployment/django-app -f
```

## 📊 File Structure

```
django/
├── k8s/
│   ├── base manifests (20 files)
│   ├── overlays/
│   │   ├── dev/
│   │   │   ├── kustomization.yaml
│   │   │   └── configmap-dev.yaml
│   │   ├── staging/
│   │   │   ├── kustomization.yaml
│   │   │   └── configmap-staging.yaml
│   │   └── production/
│   │       ├── kustomization.yaml
│   │       ├── configmap-prod.yaml
│   │       └── pdb.yaml
│   └── README.md (detailed guide)
├── deploy.sh (deployment automation)
├── cleanup.sh (resource cleanup)
├── status.sh (status monitoring)
├── backup-db.sh (database backup)
├── restore-db.sh (database restore)
├── KUBERNETES_GUIDE.md (operations manual)
├── KUBERNETES_ARCHITECTURE.md (system design)
└── DOCKER_IMAGE.md (image building guide)
```

## 🎯 Key Features

### ✅ Complete Setup
- PostgreSQL database with persistence
- Django application with 3 replicas (production)
- Traefik ingress controller
- ModSecurity WAF protection
- Automatic scaling (HPA)

### ✅ Environment Management
- Development (1 replica, debugging enabled)
- Staging (2 replicas, staging domain)
- Production (3 replicas, PDB, high availability)

### ✅ Security
- RBAC with minimal permissions
- Secret management for sensitive data
- Non-root container users
- Pod security context
- WAF protection

### ✅ High Availability
- Pod replicas for horizontal scaling
- Health checks (liveness & readiness probes)
- PersistentVolumes for data durability
- Automatic pod restart on failure
- Pod Disruption Budgets (production)

### ✅ Operations Tools
- Deployment automation scripts
- Database backup/restore
- Status monitoring
- Cleanup procedures
- Comprehensive documentation

## 📋 Deployment Checklist

- [ ] Install kubectl and kustomize
- [ ] Have access to Kubernetes cluster
- [ ] Build and push Docker image
- [ ] Update k8s/secret.yaml with real credentials
- [ ] Configure Django ALLOWED_HOSTS if needed
- [ ] Update Docker image registry in kustomization files
- [ ] Run `./deploy.sh production` (or dev/staging)
- [ ] Verify deployment with `./status.sh production`
- [ ] Test application access
- [ ] Set up monitoring and logging
- [ ] Configure backup schedule
- [ ] Document environment-specific settings

## 🔧 Common Commands

```bash
# Deploy
./deploy.sh production

# Check status
./status.sh production

# View logs
kubectl logs -n django-auth deployment/django-app -f

# Port forward
kubectl port-forward -n django-auth svc/django-app 8000:8000

# Backup database
./backup-db.sh production

# Restore database
./restore-db.sh production backups/django_production_20240101_000000.sql

# Scale manually
kubectl scale deployment/django-app --replicas=5 -n django-auth

# Update image
kubectl set image deployment/django-app django-app=your-registry/django-app:v1.1.0 -n django-auth

# Cleanup
./cleanup.sh production
```

## 📚 Documentation Links

1. **[KUBERNETES_GUIDE.md](KUBERNETES_GUIDE.md)** - Complete operations guide
   - Quick start instructions
   - Common operations
   - Troubleshooting
   - Monitoring setup

2. **[KUBERNETES_ARCHITECTURE.md](KUBERNETES_ARCHITECTURE.md)** - System design
   - Architecture overview
   - Component descriptions
   - Data flow
   - Scaling strategy

3. **[DOCKER_IMAGE.md](DOCKER_IMAGE.md)** - Image building
   - Building Docker images
   - Registry options
   - Image tagging

4. **[k8s/README.md](k8s/README.md)** - Quick reference
   - Installation steps
   - Verification procedures
   - Configuration details

## 🆘 Troubleshooting

### Pod won't start
```bash
kubectl describe pod <pod-name> -n django-auth
kubectl logs <pod-name> -n django-auth
```

### Database connection failed
```bash
kubectl exec -it postgres-xxxxx -- psql -U django django_auth
```

### Service not accessible
```bash
kubectl get svc -n django-auth
kubectl describe ingress django-ingress -n django-auth
```

See [KUBERNETES_GUIDE.md](KUBERNETES_GUIDE.md#troubleshooting) for detailed troubleshooting.

## 📝 Notes

- Update `secret.yaml` with real credentials before deployment
- Configure your Docker registry in kustomization files
- Traefik uses Let's Encrypt for automatic SSL certificates
- WAF (ModSecurity) with OWASP CRS rules is enabled
- Database backups should be scheduled via cron or external backup service

## 📞 Support

For issues, refer to:
- Kubernetes docs: https://kubernetes.io/docs/
- Kustomize guide: https://kustomize.io/
- Traefik docs: https://doc.traefik.io/traefik/
- Django deployment: https://docs.djangoproject.com/en/6.0/howto/deployment/

---

**Generated for**: Django Auth Application  
**Date**: 2024  
**Version**: 1.0
