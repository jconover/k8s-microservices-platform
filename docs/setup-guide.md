# 📖 Detailed Setup Guide

This guide provides comprehensive step-by-step instructions for setting up the Kubernetes Microservices Platform.

## Prerequisites

- 3 Ubuntu 24.04 machines (physical or VMs)
- Network connectivity between nodes
- Basic knowledge of Kubernetes and Linux
- Minimum hardware requirements:
  - 8GB RAM per node
  - 2 CPU cores per node
  - 50GB storage per node

## Step 1: Prepare All Nodes

### Update Host Files
Run this on ALL nodes to ensure proper hostname resolution:

```bash
sudo ./scripts/00-update-hosts.sh
```

### Install Prerequisites
Run this on ALL nodes:

```bash
sudo ./scripts/01-install-prerequisites-all-nodes.sh
sudo reboot
```

This script installs:
- Docker container runtime
- kubeadm, kubelet, kubectl
- Necessary kernel modules
- System optimizations

## Step 2: Initialize Control Plane

On the control plane node (after reboot):

```bash
sudo kubeadm init \
  --apiserver-advertise-address=192.168.68.86 \
  --pod-network-cidr=10.244.0.0/16 \
  --upload-certs
```

**Important**: Save the join command output for worker nodes!

### Configure kubectl

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Install CNI and Core Components

```bash
./scripts/02-setup-master.sh
```

This installs:
- Cilium CNI with eBPF
- MetalLB load balancer
- Longhorn storage system

## Step 3: Join Worker Nodes

On each worker node, run the join command from Step 2:

```bash
sudo kubeadm join 192.168.68.86:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

Verify nodes are ready:
```bash
kubectl get nodes
```

## Step 4: Deploy Core Services

```bash
./scripts/03-deploy-core-services.sh
```

This deploys:
- Monitoring stack (Prometheus, Grafana, AlertManager)
- ArgoCD for GitOps
- Database services (PostgreSQL, Redis, RabbitMQ)

## Step 5: Deploy Applications

```bash
./scripts/04-deploy-applications.sh
```

This deploys:
- Frontend React application
- API Gateway (NGINX)
- Microservices (User, Product, Order, Notification)

## Step 6: Verify Installation

```bash
./scripts/99-verify-cluster.sh
```

## Configuration Details

### Network Configuration
| Node | Hostname | IP Address |
|------|----------|------------|
| Control Plane | k8s-master-01 | 192.168.68.86 |
| Worker 1 | k8s-worker-01 | 192.168.68.88 |
| Worker 2 | k8s-worker-02 | 192.168.68.83 |

### Service IP Assignments
| Service | LoadBalancer IP | Port |
|---------|----------------|------|
| NGINX Ingress | 192.168.68.200 | 80/443 |
| Prometheus | 192.168.68.201 | 9090 |
| Grafana | 192.168.68.202 | 3000 |
| AlertManager | 192.168.68.203 | 9093 |
| ArgoCD | 192.168.68.204 | 80 |
| RabbitMQ Management | 192.168.68.205 | 15672 |
| Longhorn UI | 192.168.68.206 | 80 |
| Frontend App | 192.168.68.210 | 80 |
| API Gateway | 192.168.68.211 | 8080 |

## Post-Installation Steps

### 1. Configure ArgoCD
```bash
# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Login via CLI
argocd login 192.168.68.204 --username admin --password <password>

# Add repository
argocd repo add https://github.com/jconover/k8s-microservices-platform

# Create application
argocd app create microservices \
  --repo https://github.com/jconover/k8s-microservices-platform \
  --path k8s-manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace microservices \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

### 2. Configure Grafana Dashboards
1. Access Grafana: http://192.168.68.202:3000
2. Login: admin / admin123
3. Import recommended dashboards:
   - **Kubernetes Cluster**: Dashboard ID `7249`
   - **Node Exporter**: Dashboard ID `1860`
   - **PostgreSQL**: Dashboard ID `9628`
   - **Redis**: Dashboard ID `11835`
   - **RabbitMQ**: Dashboard ID `10991`

### 3. Set up Monitoring Alerts
```yaml
# Create custom alerting rules
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: microservices-alerts
  namespace: monitoring
spec:
  groups:
  - name: microservices
    rules:
    - alert: HighCPUUsage
      expr: sum(rate(container_cpu_usage_seconds_total[5m])) by (pod) > 0.8
      for: 5m
      annotations:
        summary: "High CPU usage detected for pod {{ $labels.pod }}"
```

## Customization Options

### Scaling Configuration
```bash
# Scale frontend replicas
kubectl scale deployment frontend --replicas=5 -n microservices

# Configure HPA
kubectl autoscale deployment frontend --min=3 --max=10 --cpu-percent=70 -n microservices
```

### Resource Limits
Edit the deployment files in `k8s-manifests/04-microservices/` to adjust resource requests and limits:

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### Storage Configuration
Modify `k8s-manifests/01-storage/storage-class.yaml` for different storage classes:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-nvme
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "2"
  dataLocality: "best-effort"
```

## Troubleshooting Setup Issues

### Common Issues

#### 1. Kubeadm Init Fails
```bash
# Reset and try again
sudo kubeadm reset
sudo rm -rf /etc/cni/net.d
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
```

#### 2. Pods Stuck in Pending
```bash
# Check node resources
kubectl describe nodes
kubectl top nodes

# Check for taints
kubectl describe node k8s-master-01 | grep Taints
```

#### 3. CNI Issues
```bash
# Check Cilium status
cilium status
kubectl logs -n kube-system -l k8s-app=cilium
```

#### 4. Storage Issues
```bash
# Check Longhorn
kubectl get pods -n longhorn-system
kubectl logs -n longhorn-system -l app=longhorn-manager
```

For more detailed troubleshooting, see [troubleshooting.md](troubleshooting.md).

## Next Steps

After successful installation:
1. Review the [Quick Reference Guide](quick-reference.md) for daily operations
2. Set up monitoring alerts and dashboards
3. Configure backup and disaster recovery
4. Review the [Production Checklist](production-checklist.md)
5. Explore GitOps workflows with ArgoCD
