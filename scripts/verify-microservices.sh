#!/bin/bash

# Microservices Platform Verification Script
# This script checks if all components are running properly

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "🚀 Microservices Platform Verification"
echo "=========================================="

# Function to check if a service is healthy
check_service_health() {
    local service_name=$1
    local namespace=$2
    local port=$3
    local health_path=${4:-"/health"}
    
    echo -n "  Checking $service_name... "
    
    # Get service IP
    local service_ip=$(kubectl get svc $service_name -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -z "$service_ip" ] || [ "$service_ip" = "null" ]; then
        service_ip=$(kubectl get svc $service_name -n $namespace -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
        if [ -z "$service_ip" ]; then
            echo -e "${RED}❌ Service not found${NC}"
            return 1
        fi
    fi
    
    # Test health endpoint
    if kubectl run test-$service_name --image=busybox --rm -i --restart=Never -- wget -qO- http://$service_ip:$port$health_path >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Healthy${NC}"
        return 0
    else
        echo -e "${RED}❌ Unhealthy${NC}"
        return 1
    fi
}

# Check nodes
echo -e "\n${BLUE}📊 Cluster Status:${NC}"
echo "Nodes:"
kubectl get nodes -o wide

# Check namespaces
echo -e "\n${BLUE}📁 Namespaces:${NC}"
kubectl get namespaces

# Check all pods status
echo -e "\n${BLUE}🏃 Pod Status:${NC}"
echo "Database Pods:"
kubectl get pods -n database 2>/dev/null || echo "  Database namespace not found"

echo "Microservices Pods:"
kubectl get pods -n microservices 2>/dev/null || echo "  Microservices namespace not found"

echo "Monitoring Pods:"
kubectl get pods -n monitoring 2>/dev/null || echo "  Monitoring namespace not found"

echo "ArgoCD Pods:"
kubectl get pods -n argocd 2>/dev/null || echo "  ArgoCD namespace not found"

# Check services with LoadBalancer IPs
echo -e "\n${BLUE}🌐 LoadBalancer Services:${NC}"
kubectl get svc -A -o wide | grep LoadBalancer

# Check ingress
echo -e "\n${BLUE}🚪 Ingress Status:${NC}"
kubectl get ingress -A 2>/dev/null || echo "  No ingress resources found"

# Test service health endpoints
echo -e "\n${BLUE}🏥 Service Health Checks:${NC}"

# Database services
echo "Database Services:"
check_service_health "postgresql" "database" "5432" "/" || true
check_service_health "redis" "database" "6379" "/" || true
check_service_health "rabbitmq" "database" "15672" "/" || true

# Microservices
echo "Microservices:"
check_service_health "user-service" "microservices" "3000" "/health" || true
check_service_health "product-service" "microservices" "5000" "/health" || true
check_service_health "order-service" "microservices" "8080" "/actuator/health" || true
check_service_health "notification-service" "microservices" "5001" "/health" || true
check_service_health "frontend" "microservices" "80" "/" || true

# Monitoring services
echo "Monitoring Services:"
check_service_health "prometheus" "monitoring" "9090" "/-/healthy" || true
check_service_health "grafana" "monitoring" "3000" "/api/health" || true

# Check storage
echo -e "\n${BLUE}💾 Storage Status:${NC}"
echo "Persistent Volumes:"
kubectl get pv 2>/dev/null || echo "  No persistent volumes found"

echo "Persistent Volume Claims:"
kubectl get pvc -A 2>/dev/null || echo "  No PVCs found"

# Check secrets
echo -e "\n${BLUE}🔐 Secrets Status:${NC}"
kubectl get secrets -n microservices 2>/dev/null || echo "  Microservices namespace not found"

# Resource usage
echo -e "\n${BLUE}📈 Resource Usage:${NC}"
kubectl top nodes 2>/dev/null || echo "  Metrics server not available"
echo ""
kubectl top pods -A 2>/dev/null | head -10 || echo "  Pod metrics not available"

# Service URLs
echo -e "\n${BLUE}🔗 Service URLs:${NC}"
echo "Frontend: http://192.168.68.210"
echo "API Gateway: http://192.168.68.211:8080"
echo "Grafana: http://192.168.68.202:3000 (admin/admin123)"
echo "Prometheus: http://192.168.68.201:9090"
echo "ArgoCD: http://192.168.68.204 (admin/get-password)"
echo "RabbitMQ: http://192.168.68.205:15672 (admin/admin123)"
echo "Longhorn: http://192.168.68.206"

# Final status
echo -e "\n${GREEN}=========================================="
echo "✅ Verification Complete!"
echo "==========================================${NC}"

echo -e "\n${YELLOW}💡 Next Steps:${NC}"
echo "1. Test the frontend: curl http://192.168.68.210"
echo "2. Test API endpoints: curl http://192.168.68.211:8080/api/users"
echo "3. Access monitoring dashboards"
echo "4. Set up GitOps with ArgoCD"
echo "5. Configure alerts and backup strategies"
