#!/bin/bash

# Cleanup Script for Django Auth Kubernetes Deployment
# Usage: ./cleanup.sh [dev|staging|production]

set -e

ENVIRONMENT=${1:-production}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|production)$ ]]; then
    echo "Invalid environment: $ENVIRONMENT"
    echo "Usage: ./cleanup.sh [dev|staging|production]"
    exit 1
fi

if [ "$ENVIRONMENT" = "production" ]; then
    NAMESPACE="django-auth"
else
    NAMESPACE="django-auth-$ENVIRONMENT"
fi

echo "⚠️  This will delete all resources in namespace: $NAMESPACE"
read -p "Are you sure? (yes/no) " -n 3 -r
echo
if [[ ! $REPLY =~ ^[Yy] ]]; then
    echo "❌ Cleanup cancelled."
    exit 1
fi

echo "🗑️  Deleting namespace $NAMESPACE..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true --wait=true

echo "✅ Cleanup complete!"
