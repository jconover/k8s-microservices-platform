# 🎯 Post-Deployment Guide

Congratulations! Your Kubernetes microservices platform is deployed. This guide will help you verify everything is working and complete your setup.

## 🔍 Immediate Verification

### Run the Verification Script
```bash
# Make the script executable and run it
chmod +x scripts/verify-microservices.sh
./scripts/verify-microservices.sh
```

This comprehensive script checks:
- ✅ Cluster and node status
- ✅ Pod health across all namespaces
- ✅ Service endpoints and LoadBalancer IPs
- ✅ Database connectivity
- ✅ Microservice health endpoints
- ✅ Storage and secrets status
- ✅ Resource usage

### Quick Manual Checks
```bash
# Check all pods are running
kubectl get pods -A

# Check LoadBalancer services
kubectl get svc -A | grep LoadBalancer

# Test basic connectivity
curl http://192.168.68.210  # Frontend
curl http://192.168.68.211:8080/health  # API Gateway
```

## 🧪 Testing Your Applications

### Frontend Testing
```bash
# Test the React frontend
curl http://192.168.68.210
# Should return HTML content

# Test in browser
# Visit: http://192.168.68.210
```

### API Endpoint Testing
```bash
# Test API Gateway health
curl http://192.168.68.211:8080/health

# Test microservice endpoints
curl http://192.168.68.211:8080/api/users
curl http://192.168.68.211:8080/api/products  
curl http://192.168.68.211:8080/api/orders

# Test individual service health
curl http://user-service.microservices:3000/health
curl http://product-service.microservices:5000/health
curl http://order-service.microservices:8080/actuator/health
curl http://notification-service.microservices:5001/health
```

### Database Testing
```bash
# Test PostgreSQL connectivity
kubectl exec -it postgresql-0 -n database -- psql -U admin -d microservices -c "SELECT version();"

# Test Redis connectivity
kubectl exec -it deployment/redis -n database -- redis-cli ping

# Test RabbitMQ
kubectl exec -it rabbitmq-0 -n database -- rabbitmqctl cluster_status
```

### Load Testing (Optional)
```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Test frontend performance
ab -n 1000 -c 10 http://192.168.68.210/

# Test API performance
ab -n 1000 -c 10 http://192.168.68.211:8080/health

# Watch auto-scaling in action
kubectl get hpa -n microservices --watch
```

## 🌐 Accessing Web Interfaces

### Service URLs
| Service | URL | Credentials | Purpose |
|---------|-----|-------------|---------|
| **Frontend** | http://192.168.68.210 | - | Main application interface |
| **API Gateway** | http://192.168.68.211:8080 | - | API endpoints and routing |
| **Grafana** | http://192.168.68.202:3000 | admin / admin123 | Monitoring dashboards |
| **Prometheus** | http://192.168.68.201:9090 | - | Metrics and alerts |
| **AlertManager** | http://192.168.68.203:9093 | - | Alert management |
| **ArgoCD** | http://192.168.68.204 | admin / (see below) | GitOps deployment |
| **RabbitMQ** | http://192.168.68.205:15672 | admin / admin123 | Message queue management |
| **Longhorn** | http://192.168.68.206 | - | Storage management |

### Getting ArgoCD Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 📊 Setting Up Monitoring Dashboards

### Import Grafana Dashboards
1. **Access Grafana**: http://192.168.68.202:3000
2. **Login**: admin / admin123
3. **Import recommended dashboards**:
   - **Kubernetes Cluster Overview**: Dashboard ID `7249`
   - **Node Exporter Full**: Dashboard ID `1860`
   - **PostgreSQL Database**: Dashboard ID `9628`
   - **Redis Dashboard**: Dashboard ID `11835`
   - **RabbitMQ Overview**: Dashboard ID `10991`

### Custom Dashboard Creation
```bash
# Example: Create custom application dashboard
# 1. Go to Grafana > Create > Dashboard
# 2. Add panels for:
#    - Request rate: rate(http_requests_total[5m])
#    - Response time: http_request_duration_seconds
#    - Error rate: rate(http_requests_total{status=~"5.."}[5m])
#    - Active users: user_sessions_active
```

### Setting Up Alerts
```bash
# Create custom alerting rules
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: microservices-alerts
  namespace: monitoring
spec:
  groups:
  - name: microservices.rules
    rules:
    - alert: HighCPUUsage
      expr: sum(rate(container_cpu_usage_seconds_total[5m])) by (pod) > 0.8
      for: 5m
      annotations:
        summary: "High CPU usage detected for pod {{ \$labels.pod }}"
    - alert: HighMemoryUsage
      expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
      for: 5m
      annotations:
        summary: "High memory usage detected for pod {{ \$labels.pod }}"
    - alert: PodRestartingFrequently
      expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
      for: 5m
      annotations:
        summary: "Pod {{ \$labels.pod }} is restarting frequently"
EOF
```

## 🔄 Configuring GitOps with ArgoCD

### Initial ArgoCD Setup
```bash
# Get admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Login via CLI
argocd login 192.168.68.204 --username admin --password $ARGOCD_PASSWORD

# Add your repository
argocd repo add https://github.com/jconover/k8s-microservices-platform

# Verify repository connection
argocd repo list
```

### Create ArgoCD Applications
```bash
# Create application for microservices
argocd app create microservices-platform \
  --repo https://github.com/jconover/k8s-microservices-platform \
  --path k8s-manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace microservices \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Sync the application
argocd app sync microservices-platform

# Check application status
argocd app get microservices-platform
```

### GitOps Workflow
1. **Make changes** to YAML files in `k8s-manifests/`
2. **Commit and push** to GitHub
3. **ArgoCD automatically detects** changes
4. **Syncs changes** to cluster
5. **Monitors health** and rolls back if needed

## 🏗️ Production Readiness Tasks

### 1. Backup Strategy
```bash
# Install Velero for cluster backups
kubectl apply -f https://github.com/vmware-tanzu/velero/releases/latest/download/velero-v1.12.0-linux-amd64.tar.gz

# Create backup schedule
velero schedule create daily-backup --schedule="0 1 * * *"

# Manual backup
velero backup create full-backup-$(date +%Y%m%d)
```

### 2. Security Hardening
```bash
# Apply network policies
kubectl apply -f k8s-manifests/07-security/network-policies.yaml

# Set up RBAC
kubectl apply -f k8s-manifests/07-security/rbac.yaml

# Enable Pod Security Standards
kubectl label namespace microservices pod-security.kubernetes.io/enforce=restricted
```

### 3. Log Aggregation
```bash
# Install Loki for log aggregation
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack -n monitoring

# Configure Grafana to use Loki as datasource
# URL: http://loki:3100
```

### 4. SSL/TLS Setup
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

## 📈 Performance Optimization

### Resource Right-Sizing
```bash
# Check current resource usage
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Adjust resource requests/limits based on usage
# Edit deployment files in k8s-manifests/04-microservices/
```

### Auto-Scaling Configuration
```bash
# Configure Vertical Pod Autoscaler (VPA)
kubectl apply -f https://github.com/kubernetes/autoscaler/releases/latest/download/vpa-release.yaml

# Create VPA for a service
kubectl apply -f - <<EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: frontend-vpa
  namespace: microservices
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  updatePolicy:
    updateMode: "Auto"
EOF
```

## 🔧 Maintenance Tasks

### Regular Health Checks
```bash
# Run verification script weekly
./scripts/verify-microservices.sh

# Check cluster resource usage
kubectl top nodes
kubectl top pods -A

# Review recent events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### Updates and Patches
```bash
# Update application images
kubectl set image deployment/frontend frontend=jconover/frontend:v2.0 -n microservices

# Rolling restart for configuration changes
kubectl rollout restart deployment/frontend -n microservices

# Check rollout status
kubectl rollout status deployment/frontend -n microservices
```

### Database Maintenance
```bash
# PostgreSQL backup
kubectl exec -it postgresql-0 -n database -- pg_dump -U admin microservices > backup-$(date +%Y%m%d).sql

# Redis backup
kubectl exec -it deployment/redis -n database -- redis-cli BGSAVE

# Check database performance
kubectl exec -it postgresql-0 -n database -- psql -U admin -d microservices -c "SELECT * FROM pg_stat_activity;"
```

## 🚨 Troubleshooting Quick Reference

### Common Issues
```bash
# Pods not starting
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Service not accessible
kubectl get endpoints <service-name> -n <namespace>
kubectl port-forward svc/<service-name> 8080:80 -n <namespace>

# Storage issues
kubectl get pvc -A
kubectl describe pvc <pvc-name> -n <namespace>

# Network connectivity
kubectl run debug --image=busybox -it --rm -- /bin/sh
# Inside pod: nslookup <service-name>.<namespace>
```

For detailed troubleshooting, see the [Troubleshooting Guide](troubleshooting.md).

## 📚 Learning and Development

### KCNA Exam Preparation
This platform covers all KCNA exam objectives:
- ✅ **Kubernetes Fundamentals** (25%)
- ✅ **Container Orchestration** (22%)
- ✅ **Cloud Native Architecture** (16%)
- ✅ **Cloud Native Observability** (8%)
- ✅ **Cloud Native Application Delivery** (8%)

### Hands-on Exercises
1. **Scale applications** under load
2. **Simulate failures** and observe recovery
3. **Practice GitOps** workflows
4. **Experiment with** service mesh (Istio/Linkerd)
5. **Implement** chaos engineering practices

### Next Steps
- 🎓 **Study cloud-native patterns** and best practices
- 🔧 **Experiment with** advanced Kubernetes features
- 🌐 **Explore** service mesh technologies
- 📊 **Implement** advanced monitoring and observability
- 🔐 **Enhance** security with policy engines like OPA/Gatekeeper

## 🎉 Congratulations!

You now have a **production-ready Kubernetes microservices platform** that demonstrates:

- **Modern architecture patterns**
- **Cloud-native best practices** 
- **Complete observability stack**
- **GitOps deployment workflows**
- **Auto-scaling and resilience**
- **Production-grade security**

This platform serves as an excellent foundation for learning Kubernetes, preparing for cloud-native certifications, and building real-world applications.

---

**Need help?** Check out the [Quick Reference Guide](quick-reference.md) for daily operations or the [Troubleshooting Guide](troubleshooting.md) for common issues.
