# 🚀 Kubernetes Microservices Platform

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.34-blue?logo=kubernetes)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-v3-blue?logo=helm)](https://helm.sh/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-orange?logo=argo)](https://argoproj.github.io/cd/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

A production-ready Kubernetes platform demonstrating microservices architecture, GitOps deployment, comprehensive observability, and cloud-native best practices. Built on a 3-node bare-metal cluster using Beelink SER5 Max mini PCs.

## 📋 Table of Contents
- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Hardware Specifications](#hardware-specifications)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Testing](#testing)
- [Accessing Services](#accessing-services)
- [Using Helm Charts](#using-helm-charts)
- [GitOps with ArgoCD](#gitops-with-argocd)
- [Monitoring & Observability](#monitoring--observability)
- [Troubleshooting](#troubleshooting)
- [KCNA Exam Coverage](#kcna-exam-coverage)
- [Contributing](#contributing)

## 🏗️ Architecture Overview

### System Architecture
- **3-Node Kubernetes Cluster**: 1 Control Plane + 2 Worker Nodes
- **Total Resources**: 96GB RAM, 48 CPU threads
- **Networking**: Cilium CNI with eBPF acceleration
- **Storage**: Longhorn distributed storage with NVMe optimization
- **Load Balancing**: MetalLB for bare-metal LoadBalancer services

### Application Architecture

┌─────────────────────────────────────────────────────────────────┐
│                         Internet Traffic                         │
└────────────────────┬────────────────────────────────────────────┘
│
┌──────▼──────┐
│ NGINX       │ ◄── 192.168.68.200
│ Ingress     │
└──────┬──────┘
│
┌──────▼──────┐
│ API Gateway │ ◄── 192.168.68.211
│  (Traefik)  │
└──────┬──────┘
│
┌───────────────┼───────────────┐
│               │               │
┌────▼────┐    ┌────▼────┐    ┌────▼────┐
│Frontend │    │  User   │    │Product  │
│(React)  │    │Service  │    │Service  │
│3 replicas│   │Node.js  │    │Python   │
└─────────┘    └────┬────┘    └────┬────┘
│               │
┌─────▼───────────────▼─────┐
│      PostgreSQL           │
│      Redis Cache          │
│      RabbitMQ Queue       │
└───────────────────────────┘


## ✨ Features

### Core Platform
- ✅ **Multi-tier Microservices**: Frontend, API Gateway, 4 backend services
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
git clone https://github.com/yourusername/k8s-microservices-platform.git
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