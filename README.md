# 🚀 Kubernetes Microservices Platform

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.34-blue?logo=kubernetes)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-v3-blue?logo=helm)](https://helm.sh/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-orange?logo=argo)](https://argoproj.github.io/cd/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

A production-ready Kubernetes platform demonstrating microservices architecture, GitOps deployment, comprehensive observability, and cloud-native best practices. Built on a 3-node bare-metal cluster using Beelink SER5 Max mini PCs.

## 📋 Table of Contents
- [🏗️ Architecture Overview](#️-architecture-overview)
- [✨ Features](#-features)
- [💻 Hardware Specifications](#-hardware-specifications)
- [🚀 Quick Start](#-quick-start)
- [🧪 Testing](#-testing)
- [🌐 Accessing Services](#-accessing-services)
- [⚓ Using Helm Charts](#-using-helm-charts)
- [🔄 GitOps with ArgoCD](#-gitops-with-argocd)
- [📊 Monitoring & Observability](#-monitoring--observability)
- [🎓 KCNA Exam Coverage](#-kcna-exam-coverage)
- [🤝 Contributing](#-contributing)
- [📞 Contact & Support](#-contact--support)

### 📚 Documentation
- [📖 Detailed Setup Guide](docs/setup-guide.md)
- [🎯 Post-Deployment Guide](docs/post-deployment-guide.md)
- [🔧 Troubleshooting Guide](docs/troubleshooting.md)
- [📚 Quick Reference](docs/quick-reference.md)

## 🏗️ Architecture Overview

### System Architecture
- **3-Node Kubernetes Cluster**: 1 Control Plane + 2 Worker Nodes
- **Total Resources**: 96GB RAM, 48 CPU threads
- **Networking**: Cilium CNI with eBPF acceleration
- **Storage**: Longhorn distributed storage with NVMe optimization
- **Load Balancing**: MetalLB for bare-metal LoadBalancer services

### Application Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet Traffic                         │
└────────────────────┬────────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────┐
│ NGINX Ingress Controller                │ ◄── 192.168.68.200
│ (Load Balancer + SSL Termination)       │
└────────────────────┬────────────────────┘
                     │
┌────────────────────▼────────────────────┐
│ API Gateway (NGINX)                     │ ◄── 192.168.68.211
│ (Routing + Rate Limiting)               │
└────────┬───────┬───────┬───────┬────────┘
         │       │       │       │
         ▼       ▼       ▼       ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   Frontend  │ │ User Service│ │Product Svc  │ │ Order Svc   │
│   (React)   │ │  (Node.js)  │ │  (Python)   │ │   (Java)    │
│  3 replicas │ │  2 replicas │ │  2 replicas │ │  2 replicas │
│    :3000    │ │    :3000    │ │    :5000    │ │    :8080    │
└─────────────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
                       │               │               │
                       └───────────────┼───────────────┘
                                       │
                           ┌───────────▼───────────┐
                           │  Notification Service │ ◄── Async Processing
                           │      (Python)         │
                           │     1 replica         │
                           │       :5001           │
                           └───────────┬───────────┘
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────┐
│                            Shared Data Layer                                │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │
│  │   PostgreSQL    │  │   Redis Cache   │  │         RabbitMQ            │ │
│  │   (Primary DB)  │  │   (Sessions &   │  │    (Message Queue for       │ │
│  │   StatefulSet   │  │    Caching)     │  │     Async Notifications)    │ │
│  │     :5432       │  │     :6379       │  │         :5672               │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```


## ✨ Features

### Core Platform
- ✅ **Polyglot Microservices**: React Frontend, NGINX Gateway, Node.js/Python/Java services
- ✅ **Production Databases**: PostgreSQL StatefulSet, Redis cache, RabbitMQ messaging
- ✅ **Auto-scaling**: HPA for dynamic scaling based on CPU/memory
- ✅ **Service Mesh Ready**: Prepared for Istio/Linkerd integration
- ✅ **Distributed Storage**: Dynamic PV provisioning with Longhorn
- ✅ **GitOps Deployment**: ArgoCD for declarative continuous delivery

### Observability Stack
- ✅ **Metrics**: Prometheus with custom dashboards
- ✅ **Visualization**: Grafana with pre-configured dashboards
- ✅ **Logging**: Loki for log aggregation
- ✅ **Tracing**: Jaeger for distributed tracing (optional)
- ✅ **Alerting**: AlertManager with notification channels

### Security & Governance
- ✅ **RBAC**: Role-based access control
- ✅ **Network Policies**: Microsegmentation between services
- ✅ **Secrets Management**: Encrypted secrets at rest
- ✅ **Pod Security Standards**: Security policies enforcement
- ✅ **Backup & Recovery**: Velero for disaster recovery

## 💻 Hardware Specifications

| Component | Specification |
|-----------|--------------|
| **Nodes** | 3x Beelink SER5 Max Mini PC |
| **CPU** | AMD Ryzen 7 6800U (8C/16T per node) |
| **RAM** | 32GB LPDDR5 per node (96GB total) |
| **Storage** | NVMe SSD (fast-nvme StorageClass) |
| **Network** | 2.5GbE + WiFi 6E |
| **OS** | Ubuntu 24.04 LTS |

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

## 🚀 Quick Start

### Prerequisites
- 3 Ubuntu 24.04 machines (physical or VMs)
- Network connectivity between nodes
- Basic knowledge of Kubernetes and Linux

### Fast Track Installation

```bash
# 1. Clone the repository
git clone https://github.com/jconover/k8s-microservices-platform.git
cd k8s-microservices-platform

# 2. Update node configurations
# Edit scripts/00-update-hosts.sh with your IPs if different

# 3. Run on ALL nodes
sudo ./scripts/00-update-hosts.sh
sudo ./scripts/01-install-prerequisites-all-nodes.sh
sudo reboot

# 4. On control plane node (after reboot)
sudo kubeadm init \
  --apiserver-advertise-address=192.168.68.86 \
  --pod-network-cidr=10.244.0.0/16 \
  --upload-certs

# 5. Configure kubectl (on control plane)
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 6. Install Cilium CNI (on control plane)
./scripts/02-setup-master.sh

# 7. Join worker nodes (copy command from step 4 output)
# Run on each worker:
sudo kubeadm join 192.168.68.86:6443 --token <token> --discovery-token-ca-cert-hash <hash>

# 8. Deploy core services (on control plane)
./scripts/03-deploy-core-services.sh

# 9. Deploy applications
./scripts/04-deploy-applications.sh

# 10. Verify deployment
./scripts/99-verify-cluster.sh
```

## 🎯 What's Next?

After deployment, follow the [Post-Deployment Guide](docs/post-deployment-guide.md) to:

- ✅ **Verify all services** are running properly
- ✅ **Test applications** and API endpoints  
- ✅ **Access monitoring dashboards** (Grafana, Prometheus)
- ✅ **Configure GitOps** with ArgoCD
- ✅ **Set up alerts** and backup strategies
- ✅ **Implement security** best practices

**Quick verification:**
```bash
# Run comprehensive verification
./scripts/verify-microservices.sh

# Test your applications
curl http://192.168.68.210          # Frontend
curl http://192.168.68.211:8080/health  # API Gateway
```


## 🧪 Testing

### Cluster Health Check
```bash
# Check node status
kubectl get nodes

# Check all pods
kubectl get pods --all-namespaces

# Check services
kubectl get svc --all-namespaces
```

### Application Testing
```bash
# Test Frontend
curl http://192.168.68.210

# Test API Gateway
curl http://192.168.68.211:8080/health

# Test API endpoints
curl http://192.168.68.211:8080/api/users
curl http://192.168.68.211:8080/api/products
curl http://192.168.68.211:8080/api/orders

# Test database connectivity
kubectl exec -it postgresql-0 -n database -- psql -U admin -d microservices -c "SELECT version();"
kubectl exec -it deployment/redis -n database -- redis-cli ping
```

For comprehensive testing procedures including load testing and monitoring validation, see the [Quick Reference Guide](docs/quick-reference.md).

## 🌐 Accessing Services

### Web UIs
| Service | URL | Credentials |
|---------|-----|-------------|
| **Frontend** | http://192.168.68.210 | - |
| **API Gateway** | http://192.168.68.211:8080 | - |
| **Grafana** | http://192.168.68.202:3000 | admin / admin123 |
| **Prometheus** | http://192.168.68.201:9090 | - |
| **AlertManager** | http://192.168.68.203:9093 | - |
| **ArgoCD** | http://192.168.68.204 | admin / (see below) |
| **RabbitMQ** | http://192.168.68.205:15672 | admin / admin123 |
| **Longhorn** | http://192.168.68.206 | - |

### Getting ArgoCD Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Port Forwarding (Alternative Access)
```bash
# If LoadBalancer IPs not working
kubectl port-forward svc/grafana -n monitoring 3000:3000
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

For more service access methods, see the [Quick Reference Guide](docs/quick-reference.md).

## ⚓ Using Helm Charts

### Installing the Platform via Helm
```bash
# Add Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install using custom values
helm install microservices-platform ./helm-charts/microservices-platform \
  --namespace microservices \
  --create-namespace \
  --values ./helm-charts/microservices-platform/values.yaml

# Upgrade deployment
helm upgrade microservices-platform ./helm-charts/microservices-platform \
  --namespace microservices \
  --values ./helm-charts/microservices-platform/values-production.yaml

# Check status
helm list -A
helm status microservices-platform -n microservices
```

For detailed Helm operations and customization options, see the [Quick Reference Guide](docs/quick-reference.md).

## 🔄 GitOps with ArgoCD

### Setting up ArgoCD
```bash
# Login to ArgoCD
argocd login 192.168.68.204 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

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

# Sync application
argocd app sync microservices

# Check status
argocd app get microservices
```

### GitOps Workflow
1. Make changes to YAML files in `k8s-manifests/`
2. Commit and push to GitHub
3. ArgoCD automatically detects changes
4. Syncs changes to cluster
5. Monitors health and rolls back if needed

For detailed ArgoCD commands and operations, see the [Quick Reference Guide](docs/quick-reference.md).

## 📊 Monitoring & Observability

### Grafana Dashboards
1. Access Grafana: http://192.168.68.202:3000
2. Login: admin / admin123
3. Import dashboards:
   - **Kubernetes Cluster**: Dashboard ID `7249`
   - **Node Exporter**: Dashboard ID `1860`
   - **PostgreSQL**: Dashboard ID `9628`
   - **Redis**: Dashboard ID `11835`
   - **RabbitMQ**: Dashboard ID `10991`

For detailed monitoring queries, alerting setup, and log aggregation, see the [Quick Reference Guide](docs/quick-reference.md).

## 🔧 Troubleshooting

For comprehensive troubleshooting procedures, diagnostic commands, and solutions to common issues, see the [Troubleshooting Guide](docs/troubleshooting.md).

### Quick Health Check
```bash
# Check overall cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# Test service endpoints
curl http://192.168.68.210          # Frontend
curl http://192.168.68.211:8080/health  # API Gateway
```

## 🎓 KCNA Exam Coverage

This project covers all Kubernetes and Cloud Native Associate (KCNA) exam objectives:

| Domain | Coverage | Percentage |
|--------|----------|------------|
| **Kubernetes Fundamentals** | Deployments, Services, ConfigMaps, Secrets, StatefulSets | 25% |
| **Container Orchestration** | Scheduling, Networking, Storage, Security | 22% |
| **Cloud Native Architecture** | Microservices, 12-factor apps, CI/CD | 16% |
| **Cloud Native Observability** | Prometheus, Grafana, Logging, Tracing | 8% |
| **Cloud Native Application Delivery** | GitOps, Helm, ArgoCD | 8% |

### Study Resources
- Official KCNA Curriculum: https://training.linuxfoundation.org/certification/kubernetes-cloud-native-associate/
- Practice with this cluster to understand concepts hands-on
- Review the [docs/kcna-study-guide.md](docs/kcna-study-guide.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Kubernetes Community for excellent documentation
- CNCF for cloud-native tools and best practices
- Beelink for powerful mini PCs perfect for homelab

## 📞 Contact & Support

- **GitHub Issues**: For bug reports and feature requests
- **Documentation**: Check `/docs` folder for detailed guides
- **Author**: [Your Name](https://github.com/jconover)

---
**Built with ❤️ for the Kubernetes community**


