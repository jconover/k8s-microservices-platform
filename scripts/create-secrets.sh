#!/bin/bash

# Create Kubernetes Secrets (Manual Utility)
# This script manually creates secrets for troubleshooting or custom setups
# 
# NOTE: The 04-deploy-applications.sh script automatically creates secrets,
# so this script is typically only needed for troubleshooting or custom deployments.

set -e

echo "🔐 Manual Secret Creation Utility"
echo "=================================="
echo ""
echo "⚠️  WARNING: This script is for manual secret management."
echo "    The deployment scripts automatically handle secrets."
echo "    Only use this if you need to recreate secrets manually."
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "🔐 Creating Kubernetes secrets..."

# Database password (should match your PostgreSQL setup)
DB_PASSWORD="SuperSecurePassword123!"

# Create the db-secret
echo "📝 Creating db-secret..."
kubectl create secret generic db-secret \
  --from-literal=password="$DB_PASSWORD" \
  --namespace=microservices \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ db-secret created successfully"

# Verify the secret was created
echo ""
echo "🔍 Verifying secrets..."
kubectl get secrets -n microservices

echo ""
echo "🎉 All secrets created successfully!"
echo ""
echo "💡 To restart deployments and pick up the new secret:"
echo "  kubectl rollout restart deployment/order-service -n microservices"
echo "  kubectl rollout restart deployment/product-service -n microservices" 
echo "  kubectl rollout restart deployment/user-service -n microservices"

echo ""
echo "📚 For normal deployments, use:"
echo "  ./scripts/04-deploy-applications.sh  # Handles secrets automatically"
