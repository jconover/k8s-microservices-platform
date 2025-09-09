#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}==================================="
echo "Kubernetes Master Setup"
echo "Node: k8s-master-01 (192.168.68.86)"
echo "===================================${NC}"

# Configuration
CONTROL_PLANE_IP="192.168.68.86"
POD_NETWORK_CIDR="10.244.0.0/16"
SERVICE_CIDR="10.96.0.0/12"
CLUSTER_NAME="beelink-k8s-cluster"

# Verify we're on the master node
CURRENT_IP=$(hostname -I | awk '{print $1}')
if [[ "$CURRENT_IP" != "$CONTROL_PLANE_IP" ]]; then
    echo -e "${RED}Error: This script must be run on k8s-master-01 (192.168.68.86)${NC}"
    echo "Current IP: $CURRENT_IP"
    exit 1
fi

# Detect the installed kubeadm version and use appropriate Kubernetes version
echo -e "${GREEN}Detecting kubeadm version...${NC}"
KUBEADM_VERSION=$(kubeadm version -o short)
echo "Installed kubeadm version: $KUBEADM_VERSION"

# Extract major.minor version (e.g., v1.34.0 -> 1.34)
KUBE_VERSION=$(echo $KUBEADM_VERSION | sed 's/v\([0-9]*\.[0-9]*\).*/\1/')
echo "Will use Kubernetes version: v${KUBE_VERSION}"

# Check if cluster is already initialized
if [ -f /etc/kubernetes/admin.conf ]; then
    echo -e "${YELLOW}Kubernetes appears to be already initialized.${NC}"
    echo "If you want to reinitialize, first run:"
    echo "  sudo kubeadm reset -f"
    echo "  sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet"
    exit 1
fi

echo -e "${GREEN}Creating kubeadm configuration...${NC}"
# Using v1beta4 API version for newer kubeadm
cat <<EOF | sudo tee /tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${CONTROL_PLANE_IP}
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  kubeletExtraArgs:
    node-ip: ${CONTROL_PLANE_IP}
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: ${KUBEADM_VERSION}
clusterName: ${CLUSTER_NAME}
controlPlaneEndpoint: "${CONTROL_PLANE_IP}:6443"
networking:
  serviceSubnet: ${SERVICE_CIDR}
  podSubnet: ${POD_NETWORK_CIDR}
  dnsDomain: cluster.local
apiServer:
  extraArgs:
    advertise-address: ${CONTROL_PLANE_IP}
controllerManager:
  extraArgs:
    bind-address: 0.0.0.0
    node-cidr-mask-size: "24"
scheduler:
  extraArgs:
    bind-address: 0.0.0.0
etcd:
  local:
    dataDir: "/var/lib/etcd"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
serverTLSBootstrap: true
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
evictionHard:
  memory.available: "2Gi"
  nodefs.available: "10%"
  imagefs.available: "15%"
systemReserved:
  cpu: "1"
  memory: "2Gi"
kubeReserved:
  cpu: "1"
  memory: "2Gi"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
clusterCIDR: ${POD_NETWORK_CIDR}
mode: "ipvs"
ipvs:
  strictARP: true
EOF

# Show the config for verification
echo -e "${YELLOW}Configuration to be used:${NC}"
grep "kubernetesVersion" /tmp/kubeadm-config.yaml

# Initialize the cluster
echo -e "${GREEN}Initializing Kubernetes cluster...${NC}"
sudo kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs

# Setup kubectl for the current user
echo -e "${GREEN}Configuring kubectl...${NC}"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify cluster is up
echo -e "${GREEN}Verifying cluster status...${NC}"
kubectl get nodes
kubectl get pods -n kube-system

# Install Cilium CNI
echo -e "${GREEN}Installing Cilium CNI...${NC}"
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64

if [ ! -f /usr/local/bin/cilium ]; then
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
fi

# Install Cilium with optimizations for your network
cilium install \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=${CONTROL_PLANE_IP} \
  --set k8sServicePort=6443

# Wait for Cilium to be ready
echo -e "${YELLOW}Waiting for Cilium to be ready...${NC}"
cilium status --wait

# Optional: Allow scheduling on control plane (for small clusters)
echo -e "${GREEN}Configuring control plane for workloads (optional)...${NC}"
kubectl taint nodes k8s-master-01 node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true

# Install MetalLB
echo -e "${GREEN}Installing MetalLB...${NC}"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
echo -e "${YELLOW}Waiting for MetalLB to be ready...${NC}"
kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --selector=app=metallb \
    --timeout=120s

# Configure MetalLB with your network range
echo -e "${GREEN}Configuring MetalLB IP pool...${NC}"
sleep 10  # Give MetalLB CRDs time to be registered
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.68.200-192.168.68.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF

# Install metrics-server
echo -e "${GREEN}Installing metrics-server...${NC}"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics-server for self-signed certificates
kubectl patch deployment metrics-server -n kube-system --type='json' \
    -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Generate join command for workers
echo -e "${GREEN}Generating join command for worker nodes...${NC}"
kubeadm token create --print-join-command > /tmp/join-command.sh
chmod +x /tmp/join-command.sh

echo -e "${GREEN}==================================="
echo -e "Master Setup Complete!"
echo -e "===================================${NC}"
echo ""
echo -e "${YELLOW}Cluster Information:${NC}"
kubectl cluster-info
echo ""
echo -e "${YELLOW}Kubernetes Version:${NC}"
kubectl version --short
echo ""
echo -e "${YELLOW}Join Command for Worker Nodes:${NC}"
echo -e "${RED}Run this command with sudo on k8s-worker-01 and k8s-worker-02:${NC}"
echo ""
cat /tmp/join-command.sh
echo ""
echo -e "${YELLOW}Save this join command! You'll need it for the worker nodes.${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Copy the join command above"
echo "2. Run it with sudo on both worker nodes"
echo "3. Then run: kubectl get nodes (to verify all nodes joined)"