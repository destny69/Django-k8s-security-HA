# Kubernetes Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Internet / Users                            │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Traefik Ingress Controller                     │
│  (SSL/TLS Termination, Routing, Rate Limiting, Load Balancing)  │
│                  LoadBalancer Service (80/443)                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                ┌──────────┴──────────┐
                │                     │
                ▼                     ▼
      ┌──────────────────┐  ┌──────────────────┐
      │   WAF Pod        │  │   WAF Pod        │
      │ (ModSecurity)    │  │ (ModSecurity)    │
      │   Port 8080      │  │   Port 8080      │
      └────────┬─────────┘  └─────────┬────────┘
               │                      │
               └──────────┬───────────┘
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ▼                ▼                ▼
   ┌──────────┐    ┌──────────┐    ┌──────────┐
   │ Django   │    │ Django   │    │ Django   │
   │ Pod 1    │    │ Pod 2    │    │ Pod 3    │
   │ :8000    │    │ :8000    │    │ :8000    │
   └─────┬────┘    └─────┬────┘    └─────┬────┘
         │                │                │
         └────────────────┼────────────────┘
                          │
                ClusterIP Service (:8000)
                          │
         ┌────────────────┴────────────────┐
         │                                 │
         ▼                                 ▼
   ┌──────────────────┐            ┌──────────────────┐
   │  PostgreSQL Pod  │            │  Persistent Vol. │
   │  :5432           │◄──────────►│  Storage (10Gi)  │
   └──────────────────┘            └──────────────────┘
```

## Kubernetes Components

### Namespace
- `django-auth` (production)
- `django-auth-staging` (staging)
- `django-auth-dev` (development)

### Core Services

1. **Traefik (Ingress Controller)**
   - Image: `traefik:v3.7`
   - Replicas: 1
   - Purpose: Route external traffic, TLS termination, load balancing
   - Exposed via: LoadBalancer Service (ports 80, 443, 8080)
   - Config: ACME Let's Encrypt, rate limiting

2. **Django Application**
   - Image: `django-app:latest`
   - Replicas: 3 (production), 2 (staging), 1 (dev)
   - Purpose: Run Django WSGI application via Gunicorn
   - Exposed via: ClusterIP Service (port 8000)
   - Init Container: Runs migrations before app startup
   - Auto-scaling: HPA (3-10 replicas on CPU/memory metrics)

3. **PostgreSQL Database**
   - Image: `postgres:16-alpine`
   - Replicas: 1
   - Purpose: Primary database
   - Exposed via: ClusterIP Service (port 5432)
   - Storage: PersistentVolumeClaim (10Gi production, 5Gi staging, 1Gi dev)
   - Health: Liveness and readiness probes

4. **ModSecurity WAF**
   - Image: `owasp/modsecurity-crs:nginx`
   - Replicas: 1
   - Purpose: Web Application Firewall with OWASP CRS
   - Exposed via: ClusterIP Service (port 8080)
   - Config: Paranoia level 1, rate limiting
   - Logs: Mounted to PersistentVolumeClaim (5Gi)

### Supporting Components

1. **Persistent Volumes**
   - PostgreSQL data: 10Gi (production)
   - Traefik Let's Encrypt: 1Gi
   - WAF logs: 5Gi

2. **ConfigMap**
   - Django settings (non-sensitive)
   - Database configuration
   - Feature flags

3. **Secrets**
   - Django SECRET_KEY
   - Database passwords
   - API keys (if any)

4. **RBAC (Role-Based Access Control)**
   - ServiceAccount: `django-app`
   - Permissions: Read ConfigMaps and Secrets
   - ServiceAccount: `traefik`
   - Permissions: Read all networking resources

5. **HorizontalPodAutoscaler (HPA)**
   - Scales Django deployment based on:
     - CPU utilization > 70% (or 60% in production)
     - Memory utilization > 80% (or 75% in production)
   - Min replicas: 3 (production), 2 (staging), 1 (dev)
   - Max replicas: 10 (production), 5 (staging), 2 (dev)

6. **Pod Disruption Budget (PDB)** - Production only
   - django-app: min 2 available replicas
   - postgres: min 1 available replica
   - traefik: min 1 available replica

### Probes and Health Checks

**Liveness Probe** (restarts unhealthy pods):
- Django: `GET /api/` HTTP 200 (30s delay, 10s period)
- PostgreSQL: `pg_isready` command (30s delay, 10s period)
- WAF: `GET /` HTTP 200 (30s delay, 10s period)

**Readiness Probe** (removes from service):
- Django: `GET /api/` HTTP 200 (10s delay, 5s period)
- PostgreSQL: `pg_isready` command (5s delay, 5s period)
- WAF: `GET /` HTTP 200 (10s delay, 5s period)

## Data Flow

1. **Incoming Request**
   - User request arrives at Traefik LoadBalancer
   - TLS terminated at Traefik

2. **Routing**
   - Traefik routes to WAF service
   - WAF inspects request (OWASP rules)
   - WAF proxies to Django

3. **Application Processing**
   - Django pod receives request
   - Gunicorn worker processes it
   - Database queries go through ClusterIP DNS (postgres.django-auth.svc.cluster.local)

4. **Database**
   - PostgreSQL processes query
   - Data persisted to PVC
   - Response returned to Django

5. **Response**
   - Django returns response through WAF
   - WAF applies output filters
   - Traefik returns to user

## Scaling Strategy

### Horizontal Pod Autoscaler (HPA)
- Monitors CPU and memory usage every 15 seconds
- Scales up when thresholds exceeded
- Scales down after 5 minutes of low usage

### Manual Scaling
```bash
kubectl scale deployment/django-app --replicas=5 -n django-auth
```

### Database Scaling
- Single PostgreSQL pod (not replicated)
- Backup/restore for disaster recovery
- Consider PostgreSQL HA setup for production

## Resource Allocation

### Development
- Django: 256Mi req / 512Mi limit per pod
- Postgres: 256Mi req / 512Mi limit

### Staging
- Django: 512Mi req / 1Gi limit per pod
- Postgres: 512Mi req / 1Gi limit

### Production
- Django: 512Mi req / 1Gi limit per pod
- Postgres: 1Gi req / 2Gi limit

## Networking

### Service Discovery
- DNS: `<service-name>.<namespace>.svc.cluster.local`
- Example: `postgres.django-auth.svc.cluster.local:5432`

### Network Policies (Not configured, can be added)
```
- Ingress from Traefik to WAF: Allow
- Ingress from WAF to Django: Allow
- Ingress from Django to Postgres: Allow
- All other traffic: Deny
```

## High Availability Considerations

### Current Setup (Single Points of Failure)
1. Single PostgreSQL pod
2. Single Traefik pod
3. Single WAF pod

### Production HA Recommendations
1. PostgreSQL replication with failover
2. Multiple Traefik replicas with node affinity
3. Multiple WAF replicas
4. Distributed storage backend (e.g., NFS, EBS)
5. Multi-zone deployment

## Backup and Recovery

### Backup Strategy
- Daily database backups via script
- Manifest backups via `kubectl get all -o yaml`
- PVC snapshots (depends on storage provider)

### Recovery Procedures
1. Database restore: `./restore-db.sh production backup.sql`
2. Manifest restore: `kubectl apply -f backup-manifests.yaml`
3. Pod recreation: `kubectl delete pod <pod-name>` (automatic via deployment)

## Security Implementation

1. **Network Isolation**: Namespace separation
2. **Access Control**: RBAC with minimal permissions
3. **Secrets Management**: K8s secrets (consider Sealed Secrets)
4. **WAF Protection**: ModSecurity with OWASP CRS
5. **Rate Limiting**: Traefik middleware
6. **Container Security**: Non-root users, no privileged mode
7. **Resource Limits**: CPU/memory limits prevent resource exhaustion
