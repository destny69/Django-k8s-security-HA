#!/bin/bash

# Status Check Script for Django Auth Kubernetes Deployment
# Usage: ./status.sh [dev|staging|production]

ENVIRONMENT=${1:-production}

if [ "$ENVIRONMENT" = "production" ]; then
    NAMESPACE="django-auth"
else
    NAMESPACE="django-auth-$ENVIRONMENT"
fi

echo "📊 Status for $ENVIRONMENT environment (namespace: $NAMESPACE)"
echo ""

echo "🏢 Deployments:"
kubectl get deployments -n "$NAMESPACE"

echo ""
echo "🔄 Pods:"
kubectl get pods -n "$NAMESPACE"

echo ""
echo "📦 Services:"
kubectl get services -n "$NAMESPACE"

echo ""
echo "🔌 Ingress:"
kubectl get ingress -n "$NAMESPACE"

echo ""
echo "📈 HPA Status:"
kubectl get hpa -n "$NAMESPACE"

echo ""
echo "💾 PVC Status:"
kubectl get pvc -n "$NAMESPACE"

echo ""
echo "⚙️  Events (last 10):"
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -n 10

echo ""
echo "📝 Detailed Pod Info:"
kubectl describe pods -n "$NAMESPACE" | grep -A 5 "^Name:"
