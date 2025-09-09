### /scripts/99-verify-cluster.sh
```bash
#!/bin/bash

echo "==================================="
echo "Kubernetes Cluster Verification"
echo "==================================="

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\n${YELLOW}Node Status:${NC}"
kubectl get nodes -o wide

echo -e "\n${YELLOW}System Pods:${NC}"
kubectl get pods -n kube-system

echo -e "\n${YELLOW}Cilium Status:${NC}"
cilium status

echo -e "\n${YELLOW}Storage Classes:${NC}"
kubectl get storageclass

echo -e "\n${YELLOW}All Namespaces:${NC}"
kubectl get namespaces

echo -e "\n${YELLOW}All Services with LoadBalancer:${NC}"
kubectl get svc -A | grep LoadBalancer

echo -e "\n${YELLOW}Resource Usage:${NC}"
kubectl top nodes || echo "Metrics server may still be initializing..."

echo -e "\n${YELLOW}Cluster Info:${NC}"
kubectl cluster-info

echo -e "\n${GREEN}Verification Complete!${NC}"