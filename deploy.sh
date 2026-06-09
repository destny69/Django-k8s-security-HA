#!/bin/bash

# Kubernetes Deployment Script for Django Auth Application
# Usage: ./deploy.sh [dev|staging|production]

set -e

ENVIRONMENT=${1:-production}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/k8s"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|production)$ ]]; then
    echo "Invalid environment: $ENVIRONMENT"
    echo "Usage: ./deploy.sh [dev|staging|production]"
    exit 1
fi

echo "🚀 Deploying Django Auth to $ENVIRONMENT environment..."

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if kustomize is installed
if ! command -v kustomize &> /dev/null; then
    echo "❌ kustomize is not installed. Please install kustomize first."
    exit 1
fi

# Get current context
CONTEXT=$(kubectl config current-context)
echo "📍 Current context: $CONTEXT"

# Confirm deployment
read -p "⚠️  Are you sure you want to deploy to $ENVIRONMENT using context '$CONTEXT'? (yes/no) " -n 3 -r
echo
if [[ ! $REPLY =~ ^[Yy] ]]; then
    echo "❌ Deployment cancelled."
    exit 1
fi

# Build manifest
echo "🔨 Building manifest for $ENVIRONMENT..."
if [ "$ENVIRONMENT" = "production" ]; then
    OVERLAY_PATH="$K8S_DIR/overlays/production"
    NAMESPACE="django-auth"
else
    OVERLAY_PATH="$K8S_DIR/overlays/$ENVIRONMENT"
    NAMESPACE="django-auth-$ENVIRONMENT"
fi

# Apply manifests
echo "📦 Applying manifests..."
kustomize build "$OVERLAY_PATH" | kubectl apply -f -

# Wait for deployments
echo "⏳ Waiting for deployments to be ready..."
kubectl rollout status deployment/django-app -n "$NAMESPACE" --timeout=5m || true
kubectl rollout status deployment/postgres -n "$NAMESPACE" --timeout=5m || true
kubectl rollout status deployment/traefik -n "$NAMESPACE" --timeout=5m || true

# Show status
echo "✅ Deployment complete!"
echo ""
echo "📊 Deployment Status:"
kubectl get all -n "$NAMESPACE"

echo ""
echo "🔗 Useful commands:"
echo "  # View logs"
echo "  kubectl logs -n $NAMESPACE deployment/django-app -f"
echo "  kubectl logs -n $NAMESPACE deployment/postgres -f"
echo ""
echo "  # Port forward"
echo "  kubectl port-forward -n $NAMESPACE svc/django-app 8000:8000"
echo "  kubectl port-forward -n $NAMESPACE svc/traefik 8080:8080"
echo ""
echo "  # Watch status"
echo "  kubectl get pods -n $NAMESPACE -w"
echo "  kubectl get hpa -n $NAMESPACE -w"
