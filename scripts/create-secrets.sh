#!/bin/bash

# Create Kubernetes Secrets
# This script creates the necessary secrets for the microservices platform

set -e

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
