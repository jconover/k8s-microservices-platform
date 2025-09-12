#!/bin/bash
# Use this to reset a node if you need to start over

echo "==================================="
echo "WARNING: This will reset Kubernetes on this node!"
echo "==================================="
read -p "Are you sure you want to continue? (yes/no): " confirmation

if [[ "$confirmation" != "yes" ]]; then
    echo "Aborting cleanup."
    exit 0
fi

# Reset kubeadm
sudo kubeadm reset -f

# Clean up iptables
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# Remove CNI configuration
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/cni/
sudo rm -rf /var/lib/calico/
sudo rm -rf /etc/cilium/
sudo rm -rf /sys/fs/bpf/cilium/

# Remove kubelet configuration
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/kubelet/
sudo rm -rf /var/lib/etcd/

# Clean up container runtime
sudo crictl rm $(sudo crictl ps -aq) 2>/dev/null || true
sudo crictl rmi $(sudo crictl images -q) 2>/dev/null || true

# Remove kubectl config
rm -rf $HOME/.kube

echo "Node has been reset. You can now rejoin it to a cluster."