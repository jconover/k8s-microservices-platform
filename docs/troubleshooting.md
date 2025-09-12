# 🔧 Troubleshooting Guide

This guide covers common issues and their solutions for the Kubernetes Microservices Platform.

## 🚨 Emergency Procedures

### Cluster Not Responding
```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes
kubectl get componentstatuses

# Check system services
sudo systemctl status kubelet
sudo systemctl status docker
sudo journalctl -u kubelet -f
```

### All Pods Down
```bash
# Check node resources
kubectl top nodes
df -h  # Check disk space

# Restart kubelet if needed
sudo systemctl restart kubelet
```

## 🔍 Diagnostic Commands

### Pod Issues

#### Pods Not Starting
```bash
# Check pod status and events
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous  # Previous instance

# Common issues to check:
# 1. Image pull errors
# 2. Resource constraints
# 3. Config/secret missing
# 4. Node selector/affinity issues
```

#### ImagePullBackOff
```bash
# Check image name and tag
kubectl describe pod <pod-name> -n <namespace>

# Test image pull manually
docker pull <image-name>

# Check registry credentials
kubectl get secrets -n <namespace>
kubectl describe secret <registry-secret> -n <namespace>
```

#### CrashLoopBackOff
```bash
# Check application logs
kubectl logs <pod-name> -n <namespace> --previous
kubectl logs -f <pod-name> -n <namespace>

# Check resource limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 Limits

# Debug with interactive shell
kubectl run debug --image=busybox -it --rm -- /bin/sh
kubectl debug <pod-name> -it --image=busybox
```

### Secret Issues

#### Missing Database Secret
```bash
# Check if secrets exist
kubectl get secrets -n microservices
kubectl get secrets -n database

# Common error: "secret db-secret not found"
# Fix by applying the secret
kubectl apply -f k8s-manifests/03-databases/db-secret.yaml

# Or use the manual script
./scripts/create-secrets.sh

# Restart affected pods
kubectl rollout restart deployment/order-service -n microservices
kubectl rollout restart deployment/product-service -n microservices
kubectl rollout restart deployment/user-service -n microservices

# Verify pods start successfully
kubectl get pods -n microservices
```

#### Secret Content Issues
```bash
# View secret content (base64 encoded)
kubectl get secret db-secret -n microservices -o yaml

# Decode secret value
kubectl get secret db-secret -n microservices -o jsonpath="{.data.password}" | base64 -d

# Update secret if password is wrong
kubectl delete secret db-secret -n microservices
kubectl create secret generic db-secret --from-literal=password="SuperSecurePassword123!" -n microservices
```

### Storage Issues

#### PVC Stuck in Pending
```bash
# Check PVC status
kubectl describe pvc <pvc-name> -n <namespace>

# Check available storage
kubectl get pv
kubectl get storageclass

# Check Longhorn status
kubectl get pods -n longhorn-system
kubectl logs -n longhorn-system -l app=longhorn-manager

# Check node storage
df -h
```

#### Longhorn Issues
```bash
# Check Longhorn system
kubectl get pods -n longhorn-system
kubectl get volumes.longhorn.io -n longhorn-system
kubectl get replicas.longhorn.io -n longhorn-system

# Access Longhorn UI
kubectl port-forward svc/longhorn-frontend -n longhorn-system 8080:80
# Then visit http://localhost:8080

# Common fixes:
# 1. Ensure nodes have required packages: open-iscsi, nfs-common
# 2. Check disk space on nodes
# 3. Verify network connectivity between nodes
```

### Network Issues

#### Service Not Accessible
```bash
# Check service and endpoints
kubectl get svc -n <namespace>
kubectl get endpoints -n <namespace>
kubectl describe svc <service-name> -n <namespace>

# Test service connectivity from within cluster
kubectl run test-pod --image=busybox -it --rm -- /bin/sh
# Inside pod:
nslookup <service-name>.<namespace>
wget -O- http://<service-name>.<namespace>:<port>

# Check network policies
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy -n <namespace>
```

#### Ingress Not Working
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Check ingress resources
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>

# Test LoadBalancer IP
curl -v http://<loadbalancer-ip>
```

#### CNI Issues (Cilium)
```bash
# Check Cilium status
cilium status
cilium connectivity test

# Check Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl logs -n kube-system -l k8s-app=cilium

# Restart Cilium if needed
kubectl delete pods -n kube-system -l k8s-app=cilium
```

### Database Issues

#### PostgreSQL Problems
```bash
# Check PostgreSQL pod
kubectl get pods -n database -l app=postgresql
kubectl logs -n database postgresql-0

# Connect to database
kubectl exec -it postgresql-0 -n database -- psql -U admin -d microservices

# Check database connectivity from apps
kubectl exec -it deployment/user-service -n microservices -- /bin/sh
# Test connection from inside app pod

# Common issues:
# 1. Password/credentials incorrect
# 2. Database not initialized
# 3. Connection limits reached
# 4. Storage full
```

#### Redis Issues
```bash
# Check Redis pod
kubectl get pods -n database -l app=redis
kubectl logs -n database deployment/redis

# Test Redis connection
kubectl exec -it deployment/redis -n database -- redis-cli ping
kubectl exec -it deployment/redis -n database -- redis-cli info

# Check memory usage
kubectl exec -it deployment/redis -n database -- redis-cli info memory
```

#### RabbitMQ Issues
```bash
# Check RabbitMQ pod
kubectl get pods -n database -l app=rabbitmq
kubectl logs -n database statefulset/rabbitmq

# Access management UI
kubectl port-forward svc/rabbitmq -n database 15672:15672
# Visit http://localhost:15672 (admin/admin123)

# Check queue status
kubectl exec -it rabbitmq-0 -n database -- rabbitmqctl list_queues
kubectl exec -it rabbitmq-0 -n database -- rabbitmqctl cluster_status
```

## 📊 Monitoring & Observability Issues

### Prometheus Not Collecting Metrics
```bash
# Check Prometheus pod
kubectl get pods -n monitoring -l app=prometheus
kubectl logs -n monitoring prometheus-0

# Check targets
curl http://192.168.68.201:9090/api/v1/targets

# Check service monitors
kubectl get servicemonitor -A
kubectl describe servicemonitor -n monitoring
```

### Grafana Dashboard Issues
```bash
# Check Grafana pod
kubectl get pods -n monitoring -l app=grafana
kubectl logs -n monitoring deployment/grafana

# Reset admin password
kubectl exec -it deployment/grafana -n monitoring -- grafana-cli admin reset-admin-password newpassword

# Check datasources
curl -u admin:admin123 http://192.168.68.202:3000/api/datasources
```

## 🔄 GitOps Issues (ArgoCD)

### ArgoCD Application Out of Sync
```bash
# Check application status
argocd app get <app-name>
argocd app sync <app-name>

# Force sync if needed
argocd app sync <app-name> --force

# Check repository connectivity
argocd repo list
argocd repo get <repo-url>
```

### ArgoCD Login Issues
```bash
# Reset admin password
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU0uh7CaChLa","admin.passwordMtime": "'$(date +%FT%T%Z)'"}}'

# Get current password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 🔧 Resource Issues

### High CPU/Memory Usage
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A

# Check resource limits
kubectl describe quota -A
kubectl describe limitrange -A

# Scale down if needed
kubectl scale deployment <deployment-name> --replicas=1 -n <namespace>

# Check for resource leaks
kubectl get pods -A -o custom-columns=NAME:.metadata.name,CPU:.spec.containers[*].resources.requests.cpu,MEMORY:.spec.containers[*].resources.requests.memory
```

### Disk Space Issues
```bash
# Check node disk usage
df -h

# Clean up Docker images
docker system prune -a

# Clean up completed pods
kubectl delete pod --field-selector=status.phase==Succeeded -A
kubectl delete pod --field-selector=status.phase==Failed -A

# Clean up old logs
sudo journalctl --vacuum-time=7d
```

## 🛠️ Recovery Procedures

### Cluster Recovery
```bash
# If control plane is down
sudo systemctl status kubelet
sudo systemctl restart kubelet

# If etcd is corrupted
sudo kubeadm init phase etcd restore --etcd-backup-dir=/tmp/etcd-backup

# Complete cluster reset (last resort)
sudo kubeadm reset
sudo rm -rf /etc/cni/net.d
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
```

### Application Recovery
```bash
# Restart deployment
kubectl rollout restart deployment/<deployment-name> -n <namespace>

# Rollback to previous version
kubectl rollout undo deployment/<deployment-name> -n <namespace>

# Scale to zero and back
kubectl scale deployment <deployment-name> --replicas=0 -n <namespace>
kubectl scale deployment <deployment-name> --replicas=3 -n <namespace>
```

### Database Recovery
```bash
# PostgreSQL recovery
kubectl exec -it postgresql-0 -n database -- pg_dumpall -U admin > backup.sql
kubectl exec -i postgresql-0 -n database -- psql -U admin < backup.sql

# Redis recovery (if persistence enabled)
kubectl exec -it deployment/redis -n database -- redis-cli BGSAVE
kubectl exec -it deployment/redis -n database -- redis-cli LASTSAVE
```

## 📋 Health Check Scripts

### Quick Health Check
```bash
#!/bin/bash
# quick-health-check.sh

echo "=== Cluster Health Check ==="
kubectl get nodes
echo ""

echo "=== Pod Status ==="
kubectl get pods -A | grep -v Running | grep -v Completed
echo ""

echo "=== Service Status ==="
kubectl get svc -A -o wide
echo ""

echo "=== Storage Status ==="
kubectl get pv,pvc -A
echo ""

echo "=== Recent Events ==="
kubectl get events -A --sort-by='.lastTimestamp' | tail -10
```

### Application Health Check
```bash
#!/bin/bash
# app-health-check.sh

SERVICES=(
    "http://192.168.68.210:80"           # Frontend
    "http://192.168.68.211:8080/health"  # API Gateway  
    "http://192.168.68.201:9090/-/healthy" # Prometheus
    "http://192.168.68.202:3000/api/health" # Grafana
)

for service in "${SERVICES[@]}"; do
    echo -n "Checking $service: "
    if curl -s -f "$service" > /dev/null; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
done
```

## 🆘 Getting Help

### Log Collection for Support
```bash
# Collect all relevant logs
mkdir -p /tmp/k8s-logs
kubectl logs -n kube-system -l k8s-app=cilium --tail=1000 > /tmp/k8s-logs/cilium.log
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=1000 > /tmp/k8s-logs/longhorn.log
kubectl get events -A --sort-by='.lastTimestamp' > /tmp/k8s-logs/events.log
kubectl get pods -A -o wide > /tmp/k8s-logs/pods.log
kubectl get nodes -o wide > /tmp/k8s-logs/nodes.log

# Create archive
tar -czf k8s-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp k8s-logs/
```

### Useful Debug Commands
```bash
# Get cluster info
kubectl cluster-info dump > cluster-dump.yaml

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Check system pods
kubectl get pods -n kube-system
kubectl get pods -n longhorn-system
kubectl get pods -n monitoring

# Network troubleshooting
kubectl run netshoot --image=nicolaka/netshoot -it --rm -- /bin/bash
```

Remember: When in doubt, check the logs first with `kubectl logs` and `kubectl describe` commands!
