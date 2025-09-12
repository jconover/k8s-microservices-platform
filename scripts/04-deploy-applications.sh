#!/bin/bash
set -e

echo "==================================="
echo "Deploying Applications Stack"
echo "==================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Base directory for manifests
MANIFEST_DIR="k8s-manifests"

# Function to apply manifests from a directory
apply_manifests() {
    local dir=$1
    local namespace=$2
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}Applying manifests from $dir...${NC}"
        for file in $dir/*.yaml; do
            if [ -f "$file" ]; then
                echo "  Applying $(basename $file)..."
                kubectl apply -f "$file" 2>&1 | grep -v "unchanged" || true
            fi
        done
    else
        echo -e "${YELLOW}Directory $dir not found${NC}"
    fi
}

# Function to wait for deployments
wait_for_deployment() {
    local name=$1
    local namespace=$2
    local timeout=${3:-60}
    
    echo -e "${YELLOW}Waiting for deployment $name in namespace $namespace...${NC}"
    kubectl rollout status deployment/$name -n $namespace --timeout=${timeout}s 2>/dev/null || {
        echo -e "${YELLOW}Warning: $name may not be ready yet${NC}"
        return 1
    }
}

# Function to check if StatefulSet exists
statefulset_exists() {
    kubectl get statefulset $1 -n $2 &> /dev/null
    return $?
}

# ===========================
# SECTION 1: NAMESPACES
# ===========================
echo -e "\n${BLUE}=== Creating Namespaces ===${NC}"
apply_manifests "$MANIFEST_DIR/00-namespaces" "default"

# ===========================
# SECTION 2: STORAGE
# ===========================
echo -e "\n${BLUE}=== Setting up Storage ===${NC}"
apply_manifests "$MANIFEST_DIR/01-storage" "default"

# ===========================
# SECTION 3: NETWORKING
# ===========================
echo -e "\n${BLUE}=== Configuring Networking ===${NC}"
apply_manifests "$MANIFEST_DIR/02-networking" "metallb-system"

# ===========================
# SECTION 4: DATABASES
# ===========================
echo -e "\n${BLUE}=== Deploying Databases ===${NC}"

# Apply database secrets first (CRITICAL for microservices)
echo -e "${YELLOW}Creating database secrets...${NC}"
kubectl apply -f "$MANIFEST_DIR/03-databases/db-secret.yaml"

# Check if PostgreSQL StatefulSet already exists
if statefulset_exists postgresql database; then
    echo -e "${YELLOW}PostgreSQL StatefulSet already exists, skipping...${NC}"
    # Apply only ConfigMap and Secret updates
    kubectl apply -f "$MANIFEST_DIR/03-databases/postgresql.yaml" --dry-run=client -o yaml | \
        kubectl apply -l '!app' -f - 2>/dev/null || true
else
    kubectl apply -f "$MANIFEST_DIR/03-databases/postgresql.yaml"
fi

# Apply other database manifests
kubectl apply -f "$MANIFEST_DIR/03-databases/redis.yaml"
kubectl apply -f "$MANIFEST_DIR/03-databases/rabbitmq.yaml"

# Wait for databases to be ready
echo -e "${YELLOW}Waiting for databases...${NC}"
kubectl wait --for=condition=ready pod -l app=postgresql -n database --timeout=180s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=redis -n database --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=rabbitmq -n database --timeout=120s 2>/dev/null || true

# ===========================
# SECTION 5: MICROSERVICES
# ===========================
echo -e "\n${BLUE}=== Deploying Microservices ===${NC}"

# Apply all microservice manifests (secrets already created in database section)
apply_manifests "$MANIFEST_DIR/04-microservices" "microservices"

# Wait for key deployments
wait_for_deployment frontend microservices 120
wait_for_deployment api-gateway microservices 120

# ===========================
# SECTION 6: MONITORING (if exists)
# ===========================
if [ -d "$MANIFEST_DIR/05-monitoring" ]; then
    echo -e "\n${BLUE}=== Deploying Monitoring Stack ===${NC}"
    apply_manifests "$MANIFEST_DIR/05-monitoring" "monitoring"
fi

# ===========================
# SECTION 7: SECURITY POLICIES
# ===========================
if [ -d "$MANIFEST_DIR/07-security" ]; then
    echo -e "\n${BLUE}=== Applying Security Policies ===${NC}"
    apply_manifests "$MANIFEST_DIR/07-security" "default"
fi

# ===========================
# VERIFICATION
# ===========================
echo -e "\n${BLUE}=== Deployment Status ===${NC}"

# Show pod status
echo -e "\n${YELLOW}Database Pods:${NC}"
kubectl get pods -n database

echo -e "\n${YELLOW}Microservice Pods:${NC}"
kubectl get pods -n microservices

# Show services
echo -e "\n${YELLOW}LoadBalancer Services:${NC}"
kubectl get svc -A | grep LoadBalancer

# ===========================
# ACCESS INFORMATION
# ===========================
echo -e "\n${BLUE}=== Access Information ===${NC}"

echo -e "${GREEN}Application URLs:${NC}"
echo "----------------------------------------"
echo "Frontend:          http://192.168.68.210"
echo "API Gateway:       http://192.168.68.211:8080"
echo "RabbitMQ Mgmt:     http://192.168.68.205:15672 (admin/admin123)"

echo -e "\n${GREEN}Quick Tests:${NC}"
echo "----------------------------------------"
echo "curl http://192.168.68.210                    # Frontend"
echo "curl http://192.168.68.211:8080/health        # API Gateway Health"
echo "curl http://192.168.68.211:8080/api/users     # User Service via Gateway"

echo -e "\n${GREEN}==================================="
echo -e "Deployment Complete!"
echo -e "===================================${NC}"

# Check for issues
PENDING_PODS=$(kubectl get pods -A | grep -E "Pending|CrashLoop|Error" | wc -l)
if [ $PENDING_PODS -gt 0 ]; then
    echo -e "\n${YELLOW}⚠ Warning: Some pods have issues:${NC}"
    kubectl get pods -A | grep -E "Pending|CrashLoop|Error"
fi