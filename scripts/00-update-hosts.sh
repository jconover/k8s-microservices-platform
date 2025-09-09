#!/bin/bash
# Run this on ALL nodes to set up hostname resolution

echo "==================================="
echo "Updating /etc/hosts for Kubernetes Cluster"
echo "Current hostname: $(hostname)"
echo "==================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Backup existing hosts file
sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}Backed up existing hosts file${NC}"

# Remove any existing k8s entries to avoid duplicates
sudo sed -i '/k8s-master-01/d' /etc/hosts
sudo sed -i '/k8s-worker-01/d' /etc/hosts
sudo sed -i '/k8s-worker-02/d' /etc/hosts

# Add cluster nodes to hosts file
cat <<EOF | sudo tee -a /etc/hosts

# Kubernetes Cluster Nodes
192.168.68.86  k8s-master-01
192.168.68.88  k8s-worker-01
192.168.68.83  k8s-worker-02
EOF

echo -e "${GREEN}Hosts file updated successfully!${NC}"

# Verify the entries
echo -e "\n${YELLOW}Verifying hosts entries:${NC}"
grep "k8s-" /etc/hosts

# Test connectivity (will only work after network is configured)
echo -e "\n${YELLOW}Testing name resolution:${NC}"
for host in k8s-master-01 k8s-worker-01 k8s-worker-02; do
    if ping -c 1 -W 1 $host > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $host is reachable"
    else
        echo -e "  $host resolution works (not reachable yet)"
    fi
done

echo -e "\n${GREEN}Hosts configuration complete!${NC}"