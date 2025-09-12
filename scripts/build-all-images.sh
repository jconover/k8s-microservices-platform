#!/bin/bash

# Build All Microservice Docker Images
# This script builds all Docker images for the microservices platform

set -e

DOCKER_REGISTRY="jconover"
SERVICES=("frontend" "user-service" "product-service" "order-service" "notification-service")

echo "🚀 Building all microservice Docker images..."
echo "Registry: $DOCKER_REGISTRY"
echo "Services: ${SERVICES[*]}"
echo ""

# Function to build a single service
build_service() {
    local service=$1
    echo "📦 Building $service..."
    
    cd "applications/$service"
    
    if docker build -t "$DOCKER_REGISTRY/$service:latest" .; then
        echo "✅ Successfully built $DOCKER_REGISTRY/$service:latest"
    else
        echo "❌ Failed to build $service"
        return 1
    fi
    
    cd - > /dev/null
    echo ""
}

# Build all services
for service in "${SERVICES[@]}"; do
    build_service "$service"
done

echo "🎉 All images built successfully!"
echo ""
echo "📋 Built images:"
for service in "${SERVICES[@]}"; do
    echo "  - $DOCKER_REGISTRY/$service:latest"
done

echo ""
echo "🚀 To push all images to Docker Hub, run:"
echo "  ./scripts/push-all-images.sh"
