#!/bin/bash
set -e

# Run this on master after all nodes have joined

echo "==================================="
echo "Deploying Core Services"
echo "==================================="

# Check all nodes are ready
echo "Checking cluster nodes..."
kubectl get nodes

# Create namespaces
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
  labels:
    name: microservices
---
apiVersion: v1
kind: Namespace
metadata:
  name: database
  labels:
    name: database
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
---
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
---
apiVersion: v1
kind: Namespace
metadata:
  name: ingress
  labels:
    name: ingress
EOF

# Install Longhorn for storage
echo "Installing Longhorn storage..."
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml

# Wait for Longhorn
kubectl wait --namespace longhorn-system --for=condition=ready pod -l app=longhorn-manager --timeout=300s

# Create storage class
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-nvme
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "30"
  dataLocality: "best-effort"
  fsType: "ext4"
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF

# Install NGINX Ingress Controller
echo "Installing NGINX Ingress..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.loadBalancerIP=192.168.68.200 \
  --set controller.resources.requests.memory=512Mi \
  --set controller.resources.requests.cpu=250m \
  --set controller.resources.limits.memory=1Gi \
  --set controller.resources.limits.cpu=500m

# Install Prometheus Stack
echo "Installing Prometheus monitoring stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

cat <<EOF > /tmp/prometheus-values.yaml
prometheus:
  service:
    type: LoadBalancer
    loadBalancerIP: 192.168.68.201
  prometheusSpec:
    retention: 30d
    resources:
      requests:
        memory: 2Gi
        cpu: 1
      limits:
        memory: 4Gi
        cpu: 2
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: fast-nvme
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

grafana:
  service:
    type: LoadBalancer
    loadBalancerIP: 192.168.68.202
  adminPassword: admin123
  persistence:
    enabled: true
    storageClassName: fast-nvme
    size: 10Gi
  resources:
    requests:
      memory: 256Mi
      cpu: 250m
    limits:
      memory: 512Mi
      cpu: 500m

alertmanager:
  service:
    type: LoadBalancer
    loadBalancerIP: 192.168.68.203
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: fast-nvme
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
EOF

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f /tmp/prometheus-values.yaml

# Install ArgoCD
echo "Installing ArgoCD..."
kubectl create namespace argocd 2>/dev/null || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Patch ArgoCD for LoadBalancer with specific IP
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer", "loadBalancerIP": "192.168.68.204"}}'

echo "==================================="
echo "Core Services Deployed!"
echo "==================================="
echo ""
echo "Waiting for all services to get IPs..."
sleep 30

echo ""
echo "Service Access Points:"
echo "----------------------"
echo "NGINX Ingress:   http://192.168.68.200"
echo "Prometheus:      http://192.168.68.201:9090"
echo "Grafana:         http://192.168.68.202:3000 (admin/admin123)"
echo "AlertManager:    http://192.168.68.203:9093"
echo "ArgoCD:          http://192.168.68.204:80"
echo ""
echo "ArgoCD Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "Longhorn UI:"
kubectl get svc -n longhorn-system longhorn-frontend