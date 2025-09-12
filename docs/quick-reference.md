# 📚 Quick Reference Guide

Essential commands and information for daily operations of the Kubernetes Microservices Platform.

## 🚀 Service URLs

### Web Interfaces
| Service | URL | Credentials |
|---------|-----|-------------|
| **Frontend** | http://192.168.68.210 | - |
| **API Gateway** | http://192.168.68.211:8080 | - |
| **Grafana** | http://192.168.68.202:3000 | admin / admin123 |
| **Prometheus** | http://192.168.68.201:9090 | - |
| **AlertManager** | http://192.168.68.203:9093 | - |
| **ArgoCD** | http://192.168.68.204 | admin / (get password below) |
| **RabbitMQ** | http://192.168.68.205:15672 | admin / admin123 |
| **Longhorn** | http://192.168.68.206 | - |

### Getting ArgoCD Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 🔧 Essential Commands

### Cluster Management
```bash
# Node operations
kubectl get nodes -o wide
kubectl describe node <node-name>
kubectl cordon <node-name>         # Mark unschedulable
kubectl drain <node-name>          # Evacuate pods
kubectl uncordon <node-name>       # Mark schedulable

# Cluster info
kubectl cluster-info
kubectl get componentstatuses
kubectl get --raw /healthz
```

### Application Management
```bash
# Deploy applications
kubectl apply -f k8s-manifests/04-microservices/
kubectl rollout status deployment/frontend -n microservices
kubectl rollout history deployment/frontend -n microservices
kubectl rollout undo deployment/frontend -n microservices

# Scale applications
kubectl scale deployment/frontend --replicas=5 -n microservices
kubectl autoscale deployment/frontend --min=3 --max=10 --cpu-percent=70 -n microservices

# Update images
kubectl set image deployment/frontend frontend=jconover/frontend:v2 -n microservices
```

### Debugging & Troubleshooting
```bash
# Logs
kubectl logs -f deployment/frontend -n microservices
kubectl logs --tail=100 -l app=frontend -n microservices
kubectl logs -p <pod-name> -n microservices  # Previous instance

# Exec into pods
kubectl exec -it <pod-name> -n microservices -- /bin/sh
kubectl exec -it deployment/redis -n database -- redis-cli

# Port forwarding
kubectl port-forward svc/frontend 8080:80 -n microservices
kubectl port-forward pod/<pod-name> 8080:80 -n microservices

# Debugging pods
kubectl run debug --image=busybox -it --rm -- /bin/sh
kubectl debug <pod-name> -it --image=busybox
```

### Resource Management
```bash
# View resources
kubectl top nodes
kubectl top pods -A
kubectl describe quota -A
kubectl describe limitrange -A

# Resource usage
kubectl get pods -A -o custom-columns=NAME:.metadata.name,CPU:.spec.containers[*].resources.requests.cpu,MEMORY:.spec.containers[*].resources.requests.memory

# Clean up
kubectl delete pod --field-selector=status.phase==Succeeded -A
kubectl delete pod --field-selector=status.phase==Failed -A
```

### Secrets & ConfigMaps
```bash
# Create secrets
kubectl create secret generic db-secret --from-literal=password=secret123 -n microservices
kubectl create secret docker-registry regcred --docker-server=docker.io --docker-username=user --docker-password=pass

# View secrets (base64 encoded)
kubectl get secret db-secret -n microservices -o yaml
kubectl get secret db-secret -n microservices -o jsonpath="{.data.password}" | base64 -d

# ConfigMaps
kubectl create configmap app-config --from-file=config.yaml -n microservices
kubectl describe configmap app-config -n microservices
```

### Networking
```bash
# Services
kubectl get svc -A
kubectl get endpoints -A
kubectl describe svc frontend -n microservices

# Ingress
kubectl get ingress -A
kubectl describe ingress -n microservices

# Network policies
kubectl get networkpolicy -A
kubectl describe networkpolicy -n microservices

# DNS testing
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

### Storage
```bash
# Persistent Volumes
kubectl get pv
kubectl get pvc -A
kubectl describe pvc postgres-storage-postgresql-0 -n database

# StorageClasses
kubectl get storageclass
kubectl describe storageclass fast-nvme

# Longhorn specific
kubectl get volumes.longhorn.io -n longhorn-system
kubectl get replicas.longhorn.io -n longhorn-system
```

## 🧪 Testing Commands

### Application Health Checks
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

### Load Testing
```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Test frontend performance
ab -n 1000 -c 10 http://192.168.68.210/

# Test API Gateway
ab -n 1000 -c 10 http://192.168.68.211:8080/health

# Watch HPA scaling
kubectl get hpa -n microservices --watch
```

### Monitoring Tests
```bash
# Check Prometheus targets
curl http://192.168.68.201:9090/api/v1/targets

# Query metrics
curl http://192.168.68.201:9090/api/v1/query?query=up

# Test Grafana
curl -u admin:admin123 http://192.168.68.202:3000/api/health
```

## ⚓ Helm Commands

### Repository Management
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo bitnami
```

### Install/Upgrade Applications
```bash
# Install using custom values
helm install microservices-platform ./helm-charts/microservices-platform \
  --namespace microservices \
  --create-namespace \
  --values ./helm-charts/microservices-platform/values.yaml

# Upgrade deployment
helm upgrade microservices-platform ./helm-charts/microservices-platform \
  --namespace microservices

# Dry run
helm install microservices-platform ./helm-charts/microservices-platform --dry-run --debug

# Rollback
helm rollback microservices-platform 1 -n microservices

# Uninstall
helm uninstall microservices-platform -n microservices
```

### Helm Operations
```bash
# List and status
helm list -A
helm status microservices-platform -n microservices
helm get values microservices-platform -n microservices
helm history microservices-platform -n microservices
```

## 🔄 ArgoCD Commands

### Login & Repository Management
```bash
# Login
argocd login 192.168.68.204 --username admin --password <password>

# Add repository
argocd repo add https://github.com/jconover/k8s-microservices-platform
argocd repo list
```

### Application Management
```bash
# Create application
argocd app create microservices \
  --repo https://github.com/jconover/k8s-microservices-platform \
  --path k8s-manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace microservices \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# App operations
argocd app list
argocd app get microservices
argocd app sync microservices
argocd app history microservices
argocd app rollback microservices 1
```

## 📊 Monitoring Queries

### Prometheus Queries
```bash
# CPU usage per node
sum(rate(container_cpu_usage_seconds_total[5m])) by (node)

# Memory usage per namespace
sum(container_memory_usage_bytes) by (namespace)

# Pod restarts
sum(rate(kube_pod_container_status_restarts_total[15m])) by (pod)

# Service latency (requires service mesh)
histogram_quantile(0.99, rate(request_duration_seconds_bucket[5m]))
```

### Database Queries
```bash
# PostgreSQL from within cluster
kubectl run -it --rm psql --image=postgres:16-alpine -- psql -h postgresql.database -U admin -d microservices

# Redis from within cluster
kubectl run -it --rm redis-cli --image=redis:7-alpine -- redis-cli -h redis.database

# RabbitMQ queue status
kubectl exec -it rabbitmq-0 -n database -- rabbitmqctl list_queues
```

## 💾 Backup & Restore

### Manual Backups
```bash
# Backup entire namespace
kubectl get all -n microservices -o yaml > microservices-backup.yaml

# Backup specific resources
kubectl get deployment,service,configmap,secret -n microservices -o yaml > app-backup.yaml

# Restore
kubectl apply -f microservices-backup.yaml
```

### Database Backups
```bash
# PostgreSQL backup
kubectl exec -it postgresql-0 -n database -- pg_dump -U admin microservices > postgres-backup.sql

# PostgreSQL restore
kubectl exec -i postgresql-0 -n database -- psql -U admin microservices < postgres-backup.sql

# Redis backup (if persistence enabled)
kubectl exec -it deployment/redis -n database -- redis-cli BGSAVE
```

### Velero Backup (if installed)
```bash
velero backup create full-backup
velero backup get
velero restore create --from-backup full-backup
```

## 🔍 Quick Diagnostic Scripts

### Health Check Script
```bash
#!/bin/bash
# Save as health-check.sh

echo "=== Node Status ==="
kubectl get nodes -o wide

echo -e "\n=== Pod Status ==="
kubectl get pods -A | grep -v Running | grep -v Completed

echo -e "\n=== Service Status ==="
for service in "192.168.68.210:80" "192.168.68.211:8080/health" "192.168.68.201:9090/-/healthy"; do
    echo -n "Checking http://$service: "
    if curl -s -f "http://$service" > /dev/null; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
done

echo -e "\n=== Recent Events ==="
kubectl get events -A --sort-by='.lastTimestamp' | tail -5
```

### Resource Usage Script
```bash
#!/bin/bash
# Save as resource-check.sh

echo "=== Node Resources ==="
kubectl top nodes

echo -e "\n=== Top Pods by CPU ==="
kubectl top pods -A --sort-by=cpu | head -10

echo -e "\n=== Top Pods by Memory ==="
kubectl top pods -A --sort-by=memory | head -10

echo -e "\n=== Storage Usage ==="
kubectl get pvc -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SIZE:.spec.resources.requests.storage,USED:.status.capacity.storage
```

## 📋 Common Troubleshooting

### Pod Issues
```bash
# Pod stuck in Pending
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod-name>

# Pod in CrashLoopBackOff
kubectl logs <pod-name> -n <namespace> --previous
kubectl describe pod <pod-name> -n <namespace>

# ImagePullBackOff
kubectl describe pod <pod-name> -n <namespace>
docker pull <image-name>  # Test manually
```

### Service Issues
```bash
# Service not accessible
kubectl get endpoints <service-name> -n <namespace>
kubectl run test --image=busybox -it --rm -- wget -O- http://<service>.<namespace>:<port>

# LoadBalancer pending
kubectl get svc -A | grep Pending
kubectl describe svc <service-name> -n <namespace>
```

For detailed troubleshooting, see the [Troubleshooting Guide](troubleshooting.md).
