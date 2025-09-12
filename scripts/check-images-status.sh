#!/bin/bash

# Check Docker Images Status
# This script checks which images exist locally and remotely

DOCKER_REGISTRY="jconover"
SERVICES=("frontend" "user-service" "product-service" "order-service" "notification-service")

echo "🔍 Checking Docker images status..."
echo "Registry: $DOCKER_REGISTRY"
echo ""

# Function to check if image exists locally
check_local_image() {
    local service=$1
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$DOCKER_REGISTRY/$service:latest"; then
        echo "✅ Local"
    else
        echo "❌ Missing"
    fi
}

# Function to check if image exists remotely
check_remote_image() {
    local service=$1
    if docker manifest inspect "$DOCKER_REGISTRY/$service:latest" >/dev/null 2>&1; then
        echo "✅ Remote"
    else
        echo "❌ Missing"
    fi
}

echo "📋 Image Status:"
printf "%-20s %-15s %-15s\n" "Service" "Local" "Remote"
printf "%-20s %-15s %-15s\n" "-------" "-----" "------"

for service in "${SERVICES[@]}"; do
    local_status=$(check_local_image "$service")
    remote_status=$(check_remote_image "$service")
    printf "%-20s %-15s %-15s\n" "$service" "$local_status" "$remote_status"
done

echo ""
echo "🛠️  Commands to fix missing images:"
echo "  Build all: ./scripts/build-all-images.sh"
echo "  Push all: ./scripts/push-all-images.sh"
echo "  Build single: cd applications/<service> && docker build -t $DOCKER_REGISTRY/<service>:latest ."
echo "  Push single: docker push $DOCKER_REGISTRY/<service>:latest"
