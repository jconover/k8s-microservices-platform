#!/bin/bash

echo "==================================="
echo "Fixing ArgoCD Access"
echo "==================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Wait for ArgoCD to be fully deployed
echo -e "${YELLOW}Waiting for ArgoCD pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Check if secret exists (it might take a moment)
echo -e "${YELLOW}Checking for ArgoCD admin secret...${NC}"
for i in {1..30}; do
    if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        echo -e "${GREEN}Secret found!${NC}"
        break
    fi
    echo "Waiting for secret... ($i/30)"
    sleep 5
done

# Get the password
if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
    echo -e "${GREEN}ArgoCD Admin Credentials:${NC}"
    echo "Username: admin"
    echo -n "Password: "
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    echo ""
else
    echo -e "${YELLOW}Initial admin secret not found. Creating a new password...${NC}"
    # For newer ArgoCD versions, you might need to create/reset the password
    # Get the argocd-server pod name
    ARGOCD_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}')
    
    # Generate a new password
    NEW_PASSWORD=$(openssl rand -base64 12)
    
    # Update the password using argocd CLI in the pod
    kubectl -n argocd exec $ARGOCD_POD -- argocd admin initial-password 2>/dev/null || \
    kubectl -n argocd exec $ARGOCD_POD -- argocd account update-password \
        --current-password admin \
        --new-password $NEW_PASSWORD \
        --account admin 2>/dev/null || \
    echo -e "${RED}Manual password reset needed${NC}"
    
    echo -e "${GREEN}New Password: $NEW_PASSWORD${NC}"
fi

echo ""
echo -e "${GREEN}Access ArgoCD at: http://192.168.68.204${NC}"
