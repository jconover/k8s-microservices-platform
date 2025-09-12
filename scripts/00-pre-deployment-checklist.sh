#!/bin/bash

# Pre-Deployment Checklist Script
# This script helps users prepare for deployment by checking prerequisites

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "🔍 Pre-Deployment Checklist"
echo "=========================================="

# Function to check if command exists
check_command() {
    local cmd=$1
    local name=$2
    
    if command -v $cmd >/dev/null 2>&1; then
        echo -e "  ✅ $name: $(which $cmd)"
        return 0
    else
        echo -e "  ❌ $name: Not found"
        return 1
    fi
}

# Function to check Docker Hub connectivity
check_docker_hub() {
    echo -n "  Checking Docker Hub connectivity... "
    if docker search nginx >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Connected${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed${NC}"
        return 1
    fi
}

# Function to check if user is logged into Docker Hub
check_docker_login() {
    echo -n "  Checking Docker Hub login... "
    if docker info | grep -q "Username"; then
        local username=$(docker info | grep "Username:" | awk '{print $2}')
        echo -e "${GREEN}✅ Logged in as: $username${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Not logged in${NC}"
        return 1
    fi
}

# Check system requirements
echo -e "\n${BLUE}🖥️  System Requirements:${NC}"
check_command "docker" "Docker"
check_command "kubectl" "kubectl" 
check_command "kubeadm" "kubeadm"
check_command "cilium" "Cilium CLI"

# Check Docker status
echo -e "\n${BLUE}🐳 Docker Status:${NC}"
if systemctl is-active --quiet docker 2>/dev/null || pgrep -x "Docker Desktop" >/dev/null 2>&1; then
    echo -e "  ✅ Docker daemon: Running"
    
    # Check Docker Hub connectivity
    check_docker_hub
    
    # Check Docker Hub login
    if ! check_docker_login; then
        echo -e "  ${YELLOW}💡 Run 'docker login' to authenticate${NC}"
    fi
    
else
    echo -e "  ❌ Docker daemon: Not running"
    echo -e "  ${RED}Please start Docker daemon${NC}"
fi

# Check Kubernetes cluster
echo -e "\n${BLUE}☸️  Kubernetes Cluster:${NC}"
if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "  ✅ Cluster: Connected"
    
    # Check nodes
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    echo -e "  ✅ Nodes: $node_count available"
    
    # Check namespaces
    kubectl get namespaces >/dev/null 2>&1 && echo -e "  ✅ Namespaces: Accessible"
    
else
    echo -e "  ❌ Cluster: Not accessible"
    echo -e "  ${YELLOW}💡 Run kubeadm init and join worker nodes first${NC}"
fi

# Check image configuration
echo -e "\n${BLUE}🏗️  Image Configuration:${NC}"
local docker_registry="jconover"
echo -e "  📋 Current Docker registry: $docker_registry"

if [ "$docker_registry" = "jconover" ]; then
    echo -e "  ${YELLOW}⚠️  Using default registry 'jconover'${NC}"
    echo -e "  ${YELLOW}💡 Consider updating to your own Docker Hub username${NC}"
    echo -e "  ${YELLOW}💡 Files to update:${NC}"
    echo -e "     - k8s-manifests/04-microservices/*.yaml"
    echo -e "     - scripts/build-all-images.sh"
    echo -e "     - scripts/push-all-images.sh"
fi

# Check if images exist
echo -e "\n${BLUE}🎯 Docker Images Status:${NC}"
./scripts/check-images-status.sh 2>/dev/null || echo -e "  ${YELLOW}⚠️  Image status check failed - run after building images${NC}"

# Check storage
echo -e "\n${BLUE}💾 Storage Requirements:${NC}"
local available_space=$(df -h . | awk 'NR==2 {print $4}')
echo -e "  💿 Available disk space: $available_space"

if [ "${available_space%G*}" -lt 20 ] 2>/dev/null; then
    echo -e "  ${YELLOW}⚠️  Low disk space - recommend 20GB+ available${NC}"
else
    echo -e "  ✅ Sufficient disk space"
fi

# Summary and recommendations
echo -e "\n${BLUE}📋 Pre-Deployment Summary:${NC}"

echo -e "\n${YELLOW}🔧 Required Actions:${NC}"
echo "1. Ensure Docker daemon is running"
echo "2. Login to Docker Hub: docker login"
echo "3. Update image registry in YAML files (optional)"
echo "4. Build and push images: ./scripts/build-all-images.sh"
echo "5. Verify images: ./scripts/check-images-status.sh"

echo -e "\n${YELLOW}📚 Documentation:${NC}"
echo "- Setup Guide: docs/setup-guide.md"
echo "- Post-Deployment: docs/post-deployment-guide.md"
echo "- Troubleshooting: docs/troubleshooting.md"

echo -e "\n${GREEN}=========================================="
echo "✅ Pre-Deployment Check Complete!"
echo "==========================================${NC}"

echo -e "\n${BLUE}🚀 Ready to deploy? Run:${NC}"
echo "  ./scripts/01-install-prerequisites-all-nodes.sh"
echo "  # ... follow setup guide steps ..."
echo "  ./scripts/build-all-images.sh"
echo "  ./scripts/03-deploy-core-services.sh"
echo "  ./scripts/04-deploy-applications.sh"
