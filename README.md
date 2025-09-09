# Kubernetes Multi-Tier Microservices Platform

A production-ready Kubernetes platform showcasing microservices architecture, GitOps, observability, and cloud-native best practices.

## 🚀 Quick Start

### Prerequisites
- 3 Linux machines (1 control plane, 2 workers) with 4GB RAM each
- Ubuntu 20.04+ or similar
- Docker installed
- kubectl, helm, and git installed locally

### Installation

1. Clone the repository:
\`\`\`bash
git clone https://github.com/yourusername/k8s-microservices-platform.git
cd k8s-microservices-platform
\`\`\`

2. Run the cluster setup:
\`\`\`bash
chmod +x scripts/*.sh
./scripts/install-prerequisites.sh
./scripts/setup-cluster.sh
\`\`\`

3. Deploy the platform:
\`\`\`bash
./scripts/deploy-all.sh
\`\`\`

## 🏗️ Architecture

- **Frontend**: React SPA with nginx
- **API Gateway**: Traefik for ingress and routing
- **Microservices**: User, Product, Order, and Notification services
- **Databases**: PostgreSQL (StatefulSet) and Redis (cache)
- **Message Queue**: RabbitMQ for async communication
- **Observability**: Prometheus, Grafana, Loki, Jaeger
- **GitOps**: ArgoCD for declarative deployments
- **Storage**: Longhorn for dynamic PV provisioning

## 📊 Features

- ✅ Multi-tier microservices architecture
- ✅ Horizontal Pod Autoscaling (HPA)
- ✅ StatefulSets for databases
- ✅ Persistent storage with dynamic provisioning
- ✅ Service mesh ready
- ✅ Full observability stack
- ✅ GitOps with ArgoCD
- ✅ RBAC and Network Policies
- ✅ Backup and disaster recovery with Velero
- ✅ CI/CD with GitHub Actions

## 🔍 Monitoring

Access the dashboards:
- Grafana: http://grafana.k8s.local (admin/admin)
- Prometheus: http://prometheus.k8s.local
- Jaeger: http://jaeger.k8s.local
- ArgoCD: http://argocd.k8s.local

## 🎓 KCNA Exam Coverage

This project covers all KCNA exam domains:
- Kubernetes Fundamentals (25%)
- Container Orchestration (22%)
- Cloud Native Architecture (16%)
- Cloud Native Observability (8%)
- Cloud Native Application Delivery (8%)

## 📚 Documentation

- [Setup Guide](docs/setup-guide.md)
- [Architecture Details](docs/architecture.md)
- [Troubleshooting](docs/troubleshooting.md)

## 🤝 Contributing

Feel free to open issues or submit PRs!

## 📄 License

MIT License