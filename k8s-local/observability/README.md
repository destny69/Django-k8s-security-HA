# Kubernetes Observability Stack

## Overview

This document describes the observability architecture used for the Kubernetes cluster.

The goal is to keep monitoring, logging, metrics, dashboards, and alerting completely isolated from application workloads.

---

# Architecture

```text
Kubernetes Cluster
│
├── django-auth namespace
│   ├── Django Application
│   ├── PostgreSQL
│   ├── PgBouncer
│   ├── Fail2Ban
│   └── Traefik Ingress
│
└── observability namespace
    ├── Promtail
    ├── Grafana Agent (optional)
    ├── Future Metrics Exporters
    └── Monitoring Components

External Monitoring Server
│
├── Loki
├── Grafana
└── Alertmanager (future)
```

---

# Why a Separate Namespace?

Using a dedicated namespace for observability provides:

### Security

Monitoring components are isolated from application workloads.

### Easier Management

All monitoring resources can be listed, updated, backed up, or removed independently.

### Future Scalability

Allows adding:

* Prometheus
* Grafana Agent
* OpenTelemetry
* Tempo
* Alertmanager
* Node Exporter

without affecting application namespaces.

### Cleaner RBAC

Permissions can be scoped specifically for monitoring workloads.

---

# Namespace Creation

Create the namespace:

```bash
kubectl create namespace observability
```

Verify:

```bash
kubectl get ns
```

Expected:

```text
NAME
cert-manager
django-auth
kube-system
observability
```

---

# Directory Structure

```text
observability/
├── README.md
│
├── promtail
│   ├── serviceaccount.yaml
│   ├── rbac.yaml
│   ├── configmap.yaml
│   └── daemonset.yaml
│
├── grafana
│
├── loki
│
└── alerts
```

---

# Promtail Purpose

Promtail runs on every Kubernetes node and collects:

* Django logs
* PostgreSQL logs
* PgBouncer logs
* Traefik logs
* Kubernetes pod logs
* System logs (optional)

It forwards logs to Loki.

---

# Loki Endpoint

Current external Loki endpoint:

```text
https://logs.manjilgautam.com.np
```

Authentication:

```text
Username: lokiadmin
Password: <configured on Loki server>
```

Promtail sends logs using HTTP push.

---

# Deployment Order

Deploy resources in the following order:

## Service Account

```bash
kubectl apply -f promtail/serviceaccount.yaml
```

## RBAC

```bash
kubectl apply -f promtail/rbac.yaml
```

## ConfigMap

```bash
kubectl apply -f promtail/configmap.yaml
```

## DaemonSet

```bash
kubectl apply -f promtail/daemonset.yaml
```

---

# Verify Deployment

Check DaemonSet:

```bash
kubectl get daemonset -n observability
```

Expected:

```text
NAME       DESIRED   CURRENT   READY
promtail   1         1         1
```

Check Pods:

```bash
kubectl get pods -n observability
```

Check Logs:

```bash
kubectl logs -n observability daemonset/promtail
```

---

# Troubleshooting

## Verify Namespace

```bash
kubectl get ns observability
```

## Verify Service Account

```bash
kubectl get sa -n observability
```

## Verify RBAC

```bash
kubectl get clusterrole | grep promtail
```

```bash
kubectl get clusterrolebinding | grep promtail
```

## Verify Promtail Pod

```bash
kubectl describe pod \
-n observability \
$(kubectl get pods -n observability -o name | head -1)
```

---

# Useful Commands

## Show All Observability Resources

```bash
kubectl get all -n observability
```

## View Promtail Logs

```bash
kubectl logs -f -n observability daemonset/promtail
```

## Restart Promtail

```bash
kubectl rollout restart daemonset promtail -n observability
```

## Check DaemonSet Status

```bash
kubectl rollout status daemonset promtail -n observability
```

## Delete Promtail

```bash
kubectl delete -f promtail/
```

---

# Verify Logs Reach Loki

Open Grafana.

Navigate to:

```text
Explore → Loki
```

Example query:

```logql
{namespace="django-auth"}
```

Show all logs:

```logql
{}
```

Show Traefik logs:

```logql
{container="traefik"}
```

Show Django logs:

```logql
{namespace="django-auth", container="django-auth"}
```

---

# Future Expansion

The observability namespace is reserved for:

* Promtail
* Grafana Agent
* OpenTelemetry Collector
* Node Exporter
* Kube State Metrics
* Alertmanager
* Prometheus
* Tempo
* Mimir

This allows the cluster to evolve into a complete production-grade monitoring platform without modifying application namespaces.

---

# Maintenance

View namespace resource usage:

```bash
kubectl top pods -n observability
```

View events:

```bash
kubectl get events -n observability --sort-by=.metadata.creationTimestamp
```

Backup manifests:

```bash
kubectl get all -n observability -o yaml > observability-backup.yaml
```

---

# Production Recommendation

Keep application workloads and observability workloads separated:

```text
django-auth namespace
└── Business Applications

observability namespace
└── Monitoring and Logging

kube-system namespace
└── Kubernetes Infrastructure
```

This separation simplifies operations, upgrades, troubleshooting, security reviews, and future scaling.
