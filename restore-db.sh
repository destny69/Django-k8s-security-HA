#!/bin/bash

# Restore Script for Django Auth Kubernetes Database
# Usage: ./restore-db.sh [dev|staging|production] [backup-file]

ENVIRONMENT=${1:-production}
BACKUP_FILE=$2

if [ "$ENVIRONMENT" = "production" ]; then
    NAMESPACE="django-auth"
else
    NAMESPACE="django-auth-$ENVIRONMENT"
fi

if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "⚠️  This will restore the database from: $BACKUP_FILE"
echo "⚠️  This will overwrite the existing database in $ENVIRONMENT"
read -p "Are you sure? (yes/no) " -n 3 -r
echo
if [[ ! $REPLY =~ ^[Yy] ]]; then
    echo "❌ Restore cancelled."
    exit 1
fi

# Get postgres pod
POSTGRES_POD=$(kubectl get pod -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POSTGRES_POD" ]; then
    echo "❌ PostgreSQL pod not found in namespace $NAMESPACE"
    exit 1
fi

echo "🔄 Restoring database..."

# Restore database
kubectl exec -i -n "$NAMESPACE" "$POSTGRES_POD" -- \
    psql -U django django_auth \
    < "$BACKUP_FILE" 2>/dev/null

echo "✅ Restore complete!"
echo "⚠️  You may need to restart the Django app:"
echo "    kubectl rollout restart deployment/django-app -n $NAMESPACE"
