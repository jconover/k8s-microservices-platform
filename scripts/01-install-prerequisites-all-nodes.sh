#!/bin/bash
set -e

echo "==================================="
echo "Installing Kubernetes Prerequisites"
echo "Ubuntu 24.04 LTS on Beelink SER5 Max"
echo "Node: $(hostname)"
echo "==================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo" 
   exit 1
fi

# Display system info
echo -e "${YELLOW}System Information:${NC}"
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "Ubuntu Version: $(lsb_release -ds)"
echo "Kernel: $(uname -r)"
echo "CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo ""

# Clean up any broken repositories first
echo -e "${GREEN}Cleaning up repositories...${NC}"
rm -f /etc/apt/sources.list.d/helm-stable-debian.list 2>/dev/null || true
rm -f /usr/share/keyrings/helm.gpg 2>/dev/null || true

# Update system
echo -e "${GREEN}Updating system packages...${NC}"
apt-get update || {
    echo -e "${YELLOW}Fixing any broken repositories...${NC}"
    # Remove problematic sources
    find /etc/apt/sources.list.d/ -name "*.list" -exec grep -l "baltocdn.com" {} \; | xargs rm -f 2>/dev/null || true
    apt-get update
}
apt-get upgrade -y

# Install essential packages
echo -e "${GREEN}Installing essential packages...${NC}"
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    net-tools \
    wget \
    vim \
    htop \
    iotop \
    nfs-common \
    open-iscsi \
    systemd-timesyncd

# Set timezone (adjust as needed)
timedatectl set-timezone America/Chicago

# Disable swap
echo -e "${GREEN}Disabling swap...${NC}"
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo 0 | tee /sys/module/zswap/parameters/enabled

# Remove old Docker installations if any
echo -e "${GREEN}Cleaning up old Docker installations...${NC}"
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
    apt-get remove -y $pkg 2>/dev/null || true
done

# Install Docker
echo -e "${GREEN}Installing Docker...${NC}"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
usermod -aG docker $SUDO_USER 2>/dev/null || true

# Configure containerd
echo -e "${GREEN}Configuring containerd...${NC}"
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml > /dev/null

# Update containerd config for systemd cgroup driver and snapshotter
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sed -i 's/snapshotter = "overlayfs"/snapshotter = "native"/' /etc/containerd/config.toml 2>/dev/null || true

systemctl restart containerd
systemctl enable containerd

# Configure kernel modules
echo -e "${GREEN}Configuring kernel modules...${NC}"
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF

# Load modules
modprobe overlay
modprobe br_netfilter
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe nf_conntrack

# Configure sysctl
echo -e "${GREEN}Configuring sysctl parameters...${NC}"
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.forwarding        = 1
net.netfilter.nf_conntrack_max      = 524288
fs.inotify.max_user_watches         = 524288
fs.inotify.max_user_instances       = 512
vm.swappiness                        = 0
vm.overcommit_memory                 = 1
kernel.panic                         = 10
kernel.panic_on_oops                 = 1
EOF

sysctl --system

# Install Kubernetes
echo -e "${GREEN}Installing Kubernetes components...${NC}"
KUBE_VERSION="1.30"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl enable --now kubelet

# Install Helm using the official script method (more reliable)
echo -e "${GREEN}Installing Helm...${NC}"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

# Verify Helm installation
if command -v helm &> /dev/null; then
    echo -e "${GREEN}Helm installed successfully: $(helm version --short)${NC}"
else
    echo -e "${YELLOW}Helm installation may have failed, trying alternative method...${NC}"
    # Alternative: Download binary directly
    wget https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz
    tar -zxvf helm-v3.14.0-linux-amd64.tar.gz
    mv linux-amd64/helm /usr/local/bin/helm
    rm -rf helm-v3.14.0-linux-amd64.tar.gz linux-amd64
fi

# Install additional tools
echo -e "${GREEN}Installing additional tools...${NC}"
# k9s
if [ ! -f /usr/local/bin/k9s ]; then
    echo "Installing k9s..."
    wget -q https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
    tar -xzf k9s_Linux_amd64.tar.gz
    mv k9s /usr/local/bin/
    rm k9s_Linux_amd64.tar.gz
    echo -e "${GREEN}k9s installed${NC}"
fi

# kubectl autocomplete for the actual user
if [ -n "$SUDO_USER" ]; then
    echo 'source <(kubectl completion bash)' >> /home/$SUDO_USER/.bashrc
    echo 'alias k=kubectl' >> /home/$SUDO_USER/.bashrc
    echo 'complete -F __start_kubectl k' >> /home/$SUDO_USER/.bashrc
fi

# Configure firewall
echo -e "${GREEN}Configuring firewall...${NC}"
# Check if ufw is active
if systemctl is-active --quiet ufw; then
    ufw allow 6443/tcp  # Kubernetes API server
    ufw allow 2379:2380/tcp  # etcd server client API
    ufw allow 10250/tcp  # Kubelet API
    ufw allow 10259/tcp  # kube-scheduler
    ufw allow 10257/tcp  # kube-controller-manager
    ufw allow 30000:32767/tcp  # NodePort Services
    ufw allow 10244/udp  # Flannel VXLAN
    ufw allow 8472/udp   # Cilium VXLAN
    ufw allow 4240/tcp   # Cilium health checks
    ufw allow 4244/tcp   # Cilium Hubble
    ufw allow 179/tcp    # BGP for MetalLB (if using BGP mode)
    echo -e "${GREEN}Firewall rules added${NC}"
else
    echo -e "${YELLOW}UFW is not active, skipping firewall configuration${NC}"
fi

# Performance optimizations
echo -e "${GREEN}Applying performance optimizations for Ryzen 7 6800U...${NC}"
# Set CPU governor to performance
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true

# Increase limits
cat <<EOF | tee -a /etc/security/limits.conf
* soft nofile 65536
* hard nofile 65536
* soft memlock unlimited
* hard memlock unlimited
EOF

# Network optimizations for 2.5GbE
cat <<EOF | tee /etc/sysctl.d/k8s-network-optimizations.conf
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
EOF

sysctl -p /etc/sysctl.d/k8s-network-optimizations.conf

echo -e "${GREEN}==================================="
echo -e "Prerequisites installation complete!"
echo -e "===================================${NC}"
echo ""
echo -e "${YELLOW}Installed versions:${NC}"
echo "Docker: $(docker --version)"
echo "Kubernetes: $(kubeadm version -o short)"
echo "Helm: $(helm version --short 2>/dev/null || echo 'Check after reboot')"
echo ""
echo -e "${YELLOW}Node configured:${NC} $(hostname) - $(hostname -I | awk '{print $1}')"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Reboot this system: sudo reboot"
echo "2. After reboot:"
echo "   - On k8s-master-01: Run setup-master.sh"
echo "   - On worker nodes: Run the join command from master"