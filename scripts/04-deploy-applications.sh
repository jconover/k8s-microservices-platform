#!/bin/bash
# Run this after core services are deployed

set -e

echo "==================================="
echo "Deploying Microservices Applications"
echo "==================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running on master node
if [[ $(hostname) != "k8s-master-01" ]]; then
    echo -e "${RED}This script should be run on k8s-master-01${NC}"
    exit 1
fi

# Deploy databases first
echo -e "${YELLOW}Deploying databases...${NC}"
kubectl apply -f k8s-manifests/03-databases/postgresql.yaml
kubectl apply -f k8s-manifests/03-databases/redis.yaml
kubectl apply -f k8s-manifests/03-databases/rabbitmq.yaml

# Wait for databases to be ready
echo -e "${YELLOW}Waiting for databases to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=postgresql -n database --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n database --timeout=120s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n database --timeout=120s

echo -e "${GREEN}Databases are ready!${NC}"

# Create database secret for microservices
kubectl create secret generic db-secret \
  --from-literal=password="SuperSecurePassword123!" \
  -n microservices --dry-run=client -o yaml | kubectl apply -f -

# Deploy microservices
echo -e "${YELLOW}Deploying microservices...${NC}"
kubectl apply -f k8s-manifests/04-microservices/

# Wait for deployments to be ready
echo -e "${YELLOW}Waiting for microservices to be ready...${NC}"
kubectl wait --for=condition=available deployment --all -n microservices --timeout=300s

# Show deployment status
echo -e "\n${GREEN}Application Deployment Status:${NC}"
kubectl get deployments -n microservices
echo ""
kubectl get pods -n microservices
echo ""
kubectl get svc -n microservices

echo -e "\n${GREEN}Applications deployed successfully!${NC}"