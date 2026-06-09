#!/bin/bash

# Backup Script for Django Auth Kubernetes Database
# Usage: ./backup-db.sh [dev|staging|production] [backup-dir]

ENVIRONMENT=${1:-production}
BACKUP_DIR=${2:-./backups}

if [ "$ENVIRONMENT" = "production" ]; then
    NAMESPACE="django-auth"
else
    NAMESPACE="django-auth-$ENVIRONMENT"
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Get postgres pod
POSTGRES_POD=$(kubectl get pod -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POSTGRES_POD" ]; then
    echo "❌ PostgreSQL pod not found in namespace $NAMESPACE"
    exit 1
fi

echo "🗄️  Backing up database from $POSTGRES_POD..."

# Backup database
BACKUP_FILE="$BACKUP_DIR/django_${ENVIRONMENT}_$(date +%Y%m%d_%H%M%S).sql"

kubectl exec -n "$NAMESPACE" "$POSTGRES_POD" -- \
    pg_dump -U django django_auth \
    > "$BACKUP_FILE" 2>/dev/null

echo "✅ Backup complete: $BACKUP_FILE"
echo "📊 Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Keep only last 7 backups
echo "🧹 Cleaning up old backups (keeping last 7)..."
ls -t "$BACKUP_DIR"/django_${ENVIRONMENT}_*.sql 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null || true

echo "✅ Done!"
