#!/bin/bash
# Quick script to get all service passwords

echo "==================================="
echo "Service Credentials"
echo "==================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\n${YELLOW}ArgoCD:${NC}"
echo -e "URL: http://192.168.68.204 or http://argocd.192.168.68.204.nip.io"
echo -e "Username: admin"
echo -n "Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "Not found"
echo ""

echo -e "\n${YELLOW}Grafana:${NC}"
echo -e "URL: http://192.168.68.202:3000 or http://grafana.192.168.68.202.nip.io"
echo -e "Username: admin"
echo -e "Password: admin123 (configured in values)"

echo -e "\n${YELLOW}Prometheus:${NC}"
echo -e "URL: http://192.168.68.201:9090"
echo -e "No authentication required"

echo -e "\n${YELLOW}AlertManager:${NC}"
echo -e "URL: http://192.168.68.203:9093"
echo -e "No authentication required"

echo -e "\n${YELLOW}PostgreSQL:${NC}"
echo -e "Host: postgresql.database.svc.cluster.local"
echo -e "Database: microservices"
echo -e "Username: admin"
echo -n "Password: "
kubectl get secret postgres-secret -n database -o jsonpath="{.data.POSTGRES_PASSWORD}" 2>/dev/null | base64 -d || echo "SuperSecurePassword123!"
echo ""

echo -e "\n${YELLOW}RabbitMQ:${NC}"
echo -e "Host: rabbitmq.database.svc.cluster.local"
echo -e "Management UI: http://[rabbitmq-service-ip]:15672"
echo -e "Username: admin"
echo -e "Password: admin123"

echo -e "\n${YELLOW}Longhorn UI:${NC}"
kubectl get svc -n longhorn-system longhorn-frontend 2>/dev/null || echo "Not deployed yet"

echo -e "\n${GREEN}To get service IPs:${NC}"
echo "kubectl get svc --all-namespaces | grep LoadBalancer"