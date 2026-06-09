# Kubernetes Deployment Checklist and Timeline

## Pre-Deployment Checklist

### Infrastructure Setup
- [ ] Kubernetes cluster provisioned (v1.24+)
- [ ] kubectl configured and working
- [ ] kustomize installed
- [ ] Docker registry access configured
- [ ] Storage class available (default or custom)
- [ ] LoadBalancer service available (cloud provider or MetalLB)

### Configuration Files
- [ ] **k8s/secret.yaml** - Updated with real secrets
  - [ ] DJANGO_SECRET_KEY: Generated new secure key
  - [ ] POSTGRES_PASSWORD: Set secure password
  - [ ] DB_PASSWORD: Set secure password
- [ ] **k8s/overlays/production/kustomization.yaml** - Image registry updated
- [ ] **k8s/traefik-deployment.yaml** - Email and domain updated
- [ ] **k8s/ingress.yaml** - Domain updated to match DNS
- [ ] **docker-compose.prod.yml** - Reviewed compatibility

### Docker Image
- [ ] Docker image built: `docker build -t your-registry/django-app:latest .`
- [ ] Image pushed: `docker push your-registry/django-app:latest`
- [ ] Image pull tested: `docker pull your-registry/django-app:latest`

### Network and Domain
- [ ] Domain registered and DNS configured
- [ ] SSL certificate ready (or cert-manager setup)
- [ ] Firewall rules allow 80/443 traffic
- [ ] LoadBalancer IP assigned and accessible

### Team & Documentation
- [ ] Team trained on deployment scripts
- [ ] Backup procedures documented
- [ ] Runbook created for common operations
- [ ] Escalation procedures defined

---

## Deployment Timeline

### Phase 1: Pre-Flight (30 minutes)

**Time: T-30min**

```
1. Verify infrastructure (5 min)
   - kubectl cluster-info
   - kustomize version
   - Docker registry login

2. Review and update secrets (10 min)
   - nano k8s/secret.yaml
   - Update with production values
   - Review for typos

3. Validate manifests (10 min)
   - kustomize build k8s/overlays/production
   - Review output for correctness
   - Dry-run if possible

4. Final backup (5 min)
   - If migrating from Docker Compose:
     - docker-compose down (backup)
     - docker run ... pg_dump > backup.sql
```

### Phase 2: Deployment (15-30 minutes)

**Time: T-0min** - Start deployment

```
Step 1: Deploy to cluster (5 min)
  Command: ./deploy.sh production
  What happens:
    - Confirms deployment with user
    - Creates namespace
    - Applies ConfigMaps and Secrets
    - Deploys PostgreSQL (waits for healthy)
    - Deploys Django app (runs migrations)
    - Deploys Traefik and WAF
    - Waits for all pods ready

Step 2: Monitor rollout (10-15 min)
  Command: ./status.sh production
  Watch: kubectl get pods -n django-auth -w
  
  Expected sequence:
    - namespace created ✓
    - postgres pod pending → running → ready (2-3 min)
    - django-app pods pending → running → ready (1-2 min)
    - traefik pod pending → running → ready (1 min)
    - waf pod pending → running → ready (1 min)

Step 3: Verify services (5 min)
  Checks:
    - kubectl get svc -n django-auth
    - kubectl get ingress -n django-auth
    - Check LoadBalancer IP assigned
```

### Phase 3: Validation (20-30 minutes)

**Time: T+30min** - Start validation

```
Step 1: Health checks (10 min)
  Commands:
    - kubectl get pods -n django-auth
    - kubectl logs django-app-xxxxx -n django-auth
    - kubectl logs postgres-xxxxx -n django-auth
  
  Look for:
    - All pods in "Running" status
    - No crash loops
    - Migration logs successful

Step 2: Database connectivity (5 min)
  Command:
    - kubectl port-forward -n django-auth svc/postgres 5432:5432
    - psql -h localhost -U django -d django_auth
  
  Verify:
    - Can connect to database
    - Tables exist
    - Data intact (if migrating)

Step 3: API endpoint test (5 min)
  Command:
    - kubectl port-forward -n django-auth svc/django-app 8000:8000
    - curl http://localhost:8000/api/
  
  Verify:
    - API responds
    - No 500 errors
    - Authentication working

Step 4: Ingress/DNS test (10 min)
  Steps:
    1. Get LoadBalancer IP:
       kubectl get svc traefik -n django-auth
    2. Point DNS to this IP (A record)
    3. Wait for DNS propagation (5 min)
    4. Test: https://django-auth.manjilgautam.com.np
    5. Verify SSL certificate
```

### Phase 4: Production Validation (30-60 minutes)

**Time: T+60min** - Full production test

```
Step 1: Performance baseline (15 min)
  Load test:
    - Use Apache Bench or Wrk
    - Generate 100 requests
    - Monitor: kubectl top pods -n django-auth

Step 2: Auto-scaling test (15 min)
  Watch HPA:
    - kubectl get hpa -n django-auth -w
    - Monitor as traffic increases
    - Verify pods scale up/down

Step 3: Backup test (10 min)
  Command: ./backup-db.sh production
  Verify:
    - Backup file created
    - Backup size reasonable (>1MB)
    - Timestamp correct

Step 4: Logging and monitoring (20 min)
  Verify:
    - Logs aggregation working
    - Metrics collection working
    - Alerts configured
    - Dashboards populated
```

### Phase 5: Post-Deployment (Ongoing)

**Time: T+2 hours** - Stabilization phase

```
Hour 1-2: Active monitoring
  - Watch: kubectl logs -n django-auth -f
  - Monitor: kubectl top nodes
  - Check: kubectl get events -n django-auth

Hour 2-4: Soak testing
  - Continuous light load
  - Monitor memory leaks
  - Watch for any errors

Hour 4+: Regular operations
  - Set up monitoring dashboards
  - Configure alerting
  - Schedule backups
  - Document any issues
```

---

## Rollback Plan (If Needed)

### Immediate Rollback (< 5 minutes)

```bash
# If deployment fails during rollout:
kubectl rollout undo deployment/django-app -n django-auth

# If pod won't start:
kubectl delete pod <pod-name> -n django-auth
# (Deployment will restart it)

# If database migration failed:
kubectl exec -n django-auth postgres-xxxxx -- \
  psql -U django django_auth -f /path/to/previous.sql

# If database connection broken:
./cleanup.sh production
./deploy.sh production
```

### Full Rollback (5-15 minutes)

```bash
# 1. Revert to Docker Compose
./cleanup.sh production

# 2. Restore database from backup
docker-compose down
docker-compose -f docker-compose.prod.yml up -d

# 3. Restore database from backup
docker exec postgres-prod pg_restore < backup.sql
```

### DNS Rollback

```bash
# Point DNS back to old IP
# Or update LoadBalancer IP if keeping K8s but reverting app version
kubectl set image deployment/django-app \
  django-app=your-registry/django-app:old-version \
  -n django-auth --record
```

---

## Post-Deployment Setup

### Day 1 Tasks

- [ ] Verify all containers running smoothly
- [ ] Check application logs for any errors
- [ ] Test backup/restore procedures
- [ ] Create first backup
- [ ] Verify monitoring and alerting

### Week 1 Tasks

- [ ] Set up automatic backup schedule (cron)
- [ ] Configure CloudFlare/CDN if needed
- [ ] Set up log aggregation (ELK/Splunk)
- [ ] Configure Prometheus monitoring
- [ ] Create runbooks for common issues
- [ ] Document any customizations

### Week 2 Tasks

- [ ] Load test the application
- [ ] Test disaster recovery procedures
- [ ] Optimize resource allocation
- [ ] Set up autoscaling policies
- [ ] Review security settings

### Month 1 Tasks

- [ ] Implement horizontal pod autoscaler tuning
- [ ] Evaluate database optimization needs
- [ ] Plan for upgrades
- [ ] Review cost optimization
- [ ] Schedule disaster recovery drill

---

## Common Timings

| Operation | Typical Duration | Max Duration |
|-----------|------------------|--------------|
| Pod startup | 30-60 seconds | 5 minutes |
| Database initialization | 2-3 minutes | 10 minutes |
| Deployment rollout | 5 minutes | 15 minutes |
| DNS propagation | 5-30 minutes | 48 hours |
| SSL certificate issuance | 1-5 minutes | 24 hours |
| Database backup | 1-2 minutes | 10 minutes |
| Database restore | 5-10 minutes | 30 minutes |
| HPA scale-up | 1-3 minutes | 5 minutes |
| HPA scale-down | 3-5 minutes | 10 minutes |

---

## Monitoring Dashboard Setup

After deployment, set up monitoring:

### Prometheus Metrics to Track

```
django_requests_total{}
django_request_duration_seconds{}
django_request_exceptions_total{}
postgresql_up{}
postgresql_database_size_bytes{}
traefik_router_requests_total{}
traefik_router_request_duration_seconds{}
container_memory_usage_bytes{}
container_cpu_usage_seconds_total{}
```

### Key Alerts

```
- Pod CrashLoopBackOff
- High CPU usage > 80%
- High memory usage > 85%
- Database connection errors
- HTTP 5xx errors > 1%
- Pod restart rate > 5/min
- Disk space < 10%
- Response time > 2 seconds
```

### Grafana Dashboards to Create

1. Django Application Dashboard
   - Request rate
   - Response times
   - Error rate
   - Database queries

2. PostgreSQL Dashboard
   - Connections
   - Cache hit ratio
   - Disk usage
   - Replication lag

3. Kubernetes Cluster Dashboard
   - Node usage
   - Pod usage
   - Network I/O
   - Storage usage

4. Traefik Dashboard
   - Router requests
   - Service latency
   - Backend availability
   - Certificate expiry

---

## Estimated Deployment Effort

| Phase | Duration | Effort |
|-------|----------|--------|
| Planning & Preparation | 1-2 hours | High |
| Infrastructure Setup | 1-2 hours | Medium |
| Configuration & Secrets | 30 min | High |
| Deployment | 15-30 min | Low |
| Validation | 30-60 min | High |
| Monitoring Setup | 1-2 hours | Medium |
| **Total** | **4-7 hours** | **Varies** |

---

## Success Criteria

✅ Deployment successful when:

- [ ] All pods in "Running" state
- [ ] No pods in "CrashLoopBackOff"
- [ ] Database migrations completed
- [ ] API endpoints responding (< 500ms)
- [ ] Static files serving correctly
- [ ] Django admin accessible
- [ ] SSL certificate valid
- [ ] DNS resolving correctly
- [ ] Load test passes (100 req/s)
- [ ] Database backup works
- [ ] Logs aggregating correctly
- [ ] Alerts firing correctly

---

## Emergency Contacts and Escalation

| Level | Trigger | Action |
|-------|---------|--------|
| **P1 - Critical** | Application down, 5xx errors > 50%, DB unreachable | Page on-call, Start incident, Prepare rollback |
| **P2 - High** | Response time > 5s, Memory > 90%, Pod restart loop | Alert team, Start investigation |
| **P3 - Medium** | Response time > 2s, Pod crash occasionally | Log issue, Monitor closely |
| **P4 - Low** | Minor performance degradation | Document, Plan for next sprint |

---

## Success Story

After successful deployment, you should see:

```
✅ Production deployment complete at 2024-01-15 14:30 UTC
✅ All services healthy (12 pods, 3 nodes)
✅ Average response time: 120ms
✅ Database size: 1.2 GB
✅ Daily backup: 256 MB
✅ SSL certificate valid until: 2024-04-15
✅ Zero errors in first 24 hours
✅ Auto-scaled to 5 pods under load
✅ WAF blocked 5 suspicious requests
✅ Load balancer distributing traffic evenly
```

Congratulations on a successful Kubernetes deployment! 🎉
