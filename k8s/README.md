# Kubernetes Deployment for Django Auth

This directory contains Kubernetes manifests for deploying the Django authentication application to a Kubernetes cluster.

## Architecture

The deployment includes:

- **PostgreSQL Database** - 16-alpine with persistent storage
- **Django Application** - 3 replicas with auto-scaling (HPA)
- **Traefik Ingress Controller** - Edge routing and TLS termination
- **ModSecurity WAF** - OWASP CRS for web application firewall
- **Persistent Storage** - For database and logs

## Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured to access your cluster
- Docker registry access (for pulling the django-app image)
- Storage provisioner (for PVC support)

## Installation

### 1. Build and Push Docker Image

```bash
docker build -t your-registry/django-app:latest .
docker push your-registry/django-app:latest
```

### 2. Update Secrets

Edit `secret.yaml` and replace placeholder values:

```bash
kubectl create secret generic django-secret \
  --from-literal=DJANGO_SECRET_KEY='your-secret-key' \
  --from-literal=POSTGRES_PASSWORD='your-db-password' \
  --from-literal=DB_PASSWORD='your-db-password' \
  -n django-auth
```

Or edit the file directly:

```bash
kubectl apply -f k8s/secret.yaml
```

### 3. Apply Manifests

#### Option A: Apply individual files

```bash
# Create namespace and base resources
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# Deploy PostgreSQL
kubectl apply -f k8s/postgres-pvc.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/postgres-service.yaml

# Deploy Django App
kubectl apply -f k8s/django-rbac.yaml
kubectl apply -f k8s/django-app-deployment.yaml
kubectl apply -f k8s/django-app-service.yaml
kubectl apply -f k8s/django-app-hpa.yaml

# Deploy Traefik
kubectl apply -f k8s/traefik-pvc.yaml
kubectl apply -f k8s/traefik-rbac.yaml
kubectl apply -f k8s/traefik-deployment.yaml
kubectl apply -f k8s/traefik-service.yaml

# Deploy WAF
kubectl apply -f k8s/waf-pvc.yaml
kubectl apply -f k8s/waf-deployment.yaml
kubectl apply -f k8s/waf-service.yaml

# Deploy Ingress
kubectl apply -f k8s/ingress.yaml
```

#### Option B: Use Kustomize

```bash
kubectl apply -k k8s/
```

## Verification

### Check all resources

```bash
kubectl get all -n django-auth
```

### Check pod status

```bash
kubectl get pods -n django-auth -w
```

### Check logs

```bash
# Django app logs
kubectl logs -n django-auth deployment/django-app

# PostgreSQL logs
kubectl logs -n django-auth deployment/postgres

# Traefik logs
kubectl logs -n django-auth deployment/traefik
```

### Port forwarding for testing

```bash
# Access Django admin
kubectl port-forward -n django-auth svc/django-app 8000:8000

# Access Traefik dashboard
kubectl port-forward -n django-auth svc/traefik 8080:8080
```

## Configuration

### Update Django settings

- Edit `configmap.yaml` for non-sensitive configuration
- Edit `secret.yaml` for sensitive data (SECRET_KEY, DB passwords)
- Restart deployments after changes:

```bash
kubectl rollout restart deployment/django-app -n django-auth
```

### Scale Django replicas

```bash
kubectl scale deployment/django-app --replicas=5 -n django-auth
```

Or let HPA manage it automatically based on CPU/memory metrics.

### Database backups

Create a backup:

```bash
kubectl exec -n django-auth postgres-<pod-id> -- pg_dump -U django django_auth > backup.sql
```

Restore from backup:

```bash
kubectl exec -n django-auth postgres-<pod-id> -- psql -U django django_auth < backup.sql
```

## Monitoring

### View HPA status

```bash
kubectl get hpa -n django-auth -w
```

### Check resource usage

```bash
kubectl top pods -n django-auth
kubectl top nodes
```

## Troubleshooting

### Pod fails to start

```bash
# Check pod status
kubectl describe pod <pod-name> -n django-auth

# Check logs
kubectl logs <pod-name> -n django-auth
```

### Database connection issues

```bash
# Test database connectivity
kubectl exec -n django-auth deployment/django-app -- python manage.py dbshell

# Check postgres service
kubectl get svc postgres -n django-auth
```

### Ingress not working

```bash
# Check ingress status
kubectl describe ingress django-ingress -n django-auth

# Check traefik logs
kubectl logs -n django-auth deployment/traefik
```

## Environment Variables

### Django ConfigMap

- `DJANGO_DEBUG`: Debug mode (0 for production)
- `DJANGO_ALLOWED_HOSTS`: Allowed hostnames
- `USE_X_FORWARDED_HOST`: Trust X-Forwarded-Host header
- `SECURE_PROXY_SSL_HEADER`: SSL header for reverse proxy
- `POSTGRES_HOST`: PostgreSQL hostname
- `POSTGRES_PORT`: PostgreSQL port
- `POSTGRES_DB`: Database name
- `POSTGRES_USER`: Database user

### Django Secrets

- `DJANGO_SECRET_KEY`: Django secret key
- `POSTGRES_PASSWORD`: PostgreSQL password
- `DB_PASSWORD`: Alternative DB password reference

## Security Considerations

1. **Secrets**: Use proper secret management (Vault, Sealed Secrets, etc.)
2. **RBAC**: Service accounts have minimal required permissions
3. **Network Policies**: Consider adding NetworkPolicies for pod-to-pod communication
4. **Pod Security Standards**: Review PSA labels for namespace
5. **Resource Limits**: All containers have CPU/memory limits
6. **Non-root Users**: Django app runs as non-root where possible

## Production Checklist

- [ ] Replace placeholder secrets with real values
- [ ] Configure StorageClass for your infrastructure
- [ ] Set up monitoring and logging (Prometheus, ELK, etc.)
- [ ] Configure backup strategy for PostgreSQL
- [ ] Review and adjust resource requests/limits
- [ ] Test database failover and recovery procedures
- [ ] Set up cert-manager for certificate management
- [ ] Configure ingress domain and TLS certificates
- [ ] Implement pod disruption budgets (PDB)
- [ ] Set up horizontal and vertical pod autoscaling
- [ ] Test disaster recovery procedures

## Cleanup

To remove all resources:

```bash
kubectl delete namespace django-auth
```

This will delete all resources in the namespace.

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Guide](https://kustomize.io/)
- [Traefik Kubernetes](https://doc.traefik.io/traefik/providers/kubernetes-crd/)
- [ModSecurity Documentation](https://github.com/coreruleset/coreruleset)
