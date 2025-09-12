#!/bin/bash

# Push All Microservice Docker Images
# This script pushes all Docker images to Docker Hub

set -e

DOCKER_REGISTRY="jconover"
SERVICES=("frontend" "user-service" "product-service" "order-service" "notification-service")

echo "🚀 Pushing all microservice Docker images to Docker Hub..."
echo "Registry: $DOCKER_REGISTRY"
echo "Services: ${SERVICES[*]}"
echo ""

# Check if logged in to Docker Hub
if ! docker info | grep -q "Username"; then
    echo "🔐 Please login to Docker Hub first:"
    echo "  docker login"
    exit 1
fi

# Function to push a single service
push_service() {
    local service=$1
    echo "📤 Pushing $service..."
    
    if docker push "$DOCKER_REGISTRY/$service:latest"; then
        echo "✅ Successfully pushed $DOCKER_REGISTRY/$service:latest"
    else
        echo "❌ Failed to push $service"
        return 1
    fi
    
    echo ""
}

# Push all services
for service in "${SERVICES[@]}"; do
    push_service "$service"
done

echo "🎉 All images pushed successfully!"
echo ""
echo "📋 Pushed images:"
for service in "${SERVICES[@]}"; do
    echo "  - $DOCKER_REGISTRY/$service:latest"
done

echo ""
echo "🔄 To update your Kubernetes deployments, run:"
echo "  kubectl rollout restart deployment/frontend -n microservices"
echo "  kubectl rollout restart deployment/user-service -n microservices"
echo "  kubectl rollout restart deployment/product-service -n microservices"
echo "  kubectl rollout restart deployment/order-service -n microservices"
echo "  kubectl rollout restart deployment/notification-service -n microservices"
