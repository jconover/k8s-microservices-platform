#!/bin/bash
set -e

echo "==================================="
echo "Deploying Applications Stack"
echo "==================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to check if resource exists
resource_exists() {
    kubectl get $1 $2 -n $3 &> /dev/null
    return $?
}

# Function to wait for pod with timeout
wait_for_pod() {
    local label=$1
    local namespace=$2
    local timeout=${3:-120}
    
    echo -e "${YELLOW}Waiting for $label in namespace $namespace...${NC}"
    kubectl wait --for=condition=ready pod -l $label -n $namespace --timeout=${timeout}s 2>/dev/null || {
        echo -e "${YELLOW}Warning: $label may not be ready yet${NC}"
        return 1
    }
    return 0
}

# ===========================
# SECTION 1: DATABASES
# ===========================
echo -e "\n${BLUE}=== Section 1: Deploying Databases ===${NC}"

# Create database namespace if not exists
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -

# Deploy PostgreSQL
echo -e "${GREEN}Deploying PostgreSQL...${NC}"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: database
data:
  POSTGRES_DB: microservices
  POSTGRES_USER: admin
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: database
type: Opaque
stringData:
  POSTGRES_PASSWORD: "SuperSecurePassword123!"
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: database
  labels:
    app: postgresql
spec:
  ports:
  - port: 5432
    name: postgres
  clusterIP: None
  selector:
    app: postgresql
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: database
spec:
  serviceName: postgresql
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
          name: postgres
        envFrom:
        - configMapRef:
            name: postgres-config
        - secretRef:
            name: postgres-secret
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
          subPath: postgres
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - admin
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - admin
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "fast-nvme"
      resources:
        requests:
          storage: 20Gi
EOF

# Deploy Redis
echo -e "${GREEN}Deploying Redis...${NC}"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: database
  labels:
    app: redis
spec:
  ports:
  - port: 6379
    name: redis
  selector:
    app: redis
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        command:
        - redis-server
        - "--maxmemory"
        - "1gb"
        - "--maxmemory-policy"
        - "allkeys-lru"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          tcpSocket:
            port: 6379
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

# Deploy RabbitMQ (simplified version)
echo -e "${GREEN}Deploying RabbitMQ...${NC}"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: database
  labels:
    app: rabbitmq
spec:
  ports:
  - port: 5672
    targetPort: 5672
    name: amqp
  - port: 15672
    targetPort: 15672
    name: management
  selector:
    app: rabbitmq
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq-management
  namespace: database
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.68.205
  ports:
  - port: 15672
    targetPort: 15672
    name: management
  selector:
    app: rabbitmq
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:3-management-alpine
        ports:
        - containerPort: 5672
          name: amqp
        - containerPort: 15672
          name: management
        env:
        - name: RABBITMQ_DEFAULT_USER
          value: admin
        - name: RABBITMQ_DEFAULT_PASS
          value: admin123
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          tcpSocket:
            port: 5672
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
        readinessProbe:
          tcpSocket:
            port: 15672
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
EOF

# Wait for databases
echo -e "${YELLOW}Waiting for databases to be ready...${NC}"
wait_for_pod "app=postgresql" "database" 180
wait_for_pod "app=redis" "database" 120
wait_for_pod "app=rabbitmq" "database" 180 || echo -e "${YELLOW}RabbitMQ may take longer to start${NC}"

echo -e "${GREEN}✓ Databases deployed${NC}"

# ===========================
# SECTION 2: MICROSERVICES
# ===========================
echo -e "\n${BLUE}=== Section 2: Deploying Microservices ===${NC}"

# Create microservices namespace
kubectl create namespace microservices --dry-run=client -o yaml | kubectl apply -f -

# Create database secret in microservices namespace
kubectl create secret generic db-secret \
  --from-literal=password="SuperSecurePassword123!" \
  -n microservices --dry-run=client -o yaml | kubectl apply -f -

# Check if we should use sample apps or custom images
USE_SAMPLE_APPS=true
DOCKER_USERNAME="${DOCKER_USERNAME:-yourusername}"

echo -e "${YELLOW}Note: Using sample applications. To use custom images, set DOCKER_USERNAME environment variable${NC}"

if [ "$USE_SAMPLE_APPS" = true ]; then
    # Deploy sample applications using public images
    echo -e "${GREEN}Deploying sample applications...${NC}"
    
    # Frontend
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: microservices
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: microservices
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.68.210
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: frontend
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-hpa
  namespace: microservices
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF

    # User Service
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: microservices
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "user-service"
        - name: DB_HOST
          value: postgresql.database
        - name: REDIS_HOST
          value: redis.database
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: microservices
spec:
  type: ClusterIP
  ports:
  - port: 3000
    targetPort: 80
  selector:
    app: user-service
EOF

    # Product Service
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: microservices
spec:
  replicas: 2
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      containers:
      - name: product-service
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "product-service"
        - name: DB_HOST
          value: postgresql.database
        - name: REDIS_HOST
          value: redis.database
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: microservices
spec:
  type: ClusterIP
  ports:
  - port: 5000
    targetPort: 80
  selector:
    app: product-service
EOF

    # Order Service
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: microservices
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: order-service
        image: nginxdemos/hello
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "order-service"
        - name: DB_HOST
          value: postgresql.database
        - name: RABBITMQ_HOST
          value: rabbitmq.database
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: microservices
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 80
  selector:
    app: order-service
EOF

    # Notification Service
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notification-service
  template:
    metadata:
      labels:
        app: notification-service
    spec:
      containers:
      - name: notification-service
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "notification-service"
        - name: RABBITMQ_HOST
          value: rabbitmq.database
        - name: REDIS_HOST
          value: redis.database
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: notification-service
  namespace: microservices
spec:
  type: ClusterIP
  ports:
  - port: 5001
    targetPort: 80
  selector:
    app: notification-service
EOF

    # API Gateway
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: microservices
data:
  default.conf: |
    upstream user-service {
        server user-service:3000;
    }
    upstream product-service {
        server product-service:5000;
    }
    upstream order-service {
        server order-service:8080;
    }
    upstream notification-service {
        server notification-service:5001;
    }
    
    server {
        listen 80;
        
        location /api/users {
            proxy_pass http://user-service;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
        
        location /api/products {
            proxy_pass http://product-service;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
        
        location /api/orders {
            proxy_pass http://order-service;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
        
        location /api/notifications {
            proxy_pass http://notification-service;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
        
        location / {
            return 200 'API Gateway is running\n';
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: microservices
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: api-gateway
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: config
        configMap:
          name: nginx-config
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: microservices
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.68.211
  ports:
  - port: 8080
    targetPort: 80
  selector:
    app: api-gateway
EOF

fi

# Wait for microservices
echo -e "${YELLOW}Waiting for microservices to be ready...${NC}"
wait_for_pod "app=frontend" "microservices" 120
wait_for_pod "app=user-service" "microservices" 120
wait_for_pod "app=product-service" "microservices" 120
wait_for_pod "app=order-service" "microservices" 120
wait_for_pod "app=api-gateway" "microservices" 120

echo -e "${GREEN}✓ Microservices deployed${NC}"

# ===========================
# SECTION 3: VERIFICATION
# ===========================
echo -e "\n${BLUE}=== Section 3: Deployment Verification ===${NC}"

# Check database pods
echo -e "\n${YELLOW}Database Status:${NC}"
kubectl get pods -n database -o wide

# Check microservice pods
echo -e "\n${YELLOW}Microservices Status:${NC}"
kubectl get pods -n microservices -o wide

# Check services
echo -e "\n${YELLOW}Service Endpoints:${NC}"
echo -e "${GREEN}Databases:${NC}"
kubectl get svc -n database

echo -e "\n${GREEN}Microservices:${NC}"
kubectl get svc -n microservices

# Check HPA
echo -e "\n${YELLOW}Autoscaling Status:${NC}"
kubectl get hpa -n microservices 2>/dev/null || echo "No HPA configured"

# ===========================
# SECTION 4: ACCESS INFO
# ===========================
echo -e "\n${BLUE}=== Section 4: Access Information ===${NC}"

# Get LoadBalancer IPs
FRONTEND_IP=$(kubectl get svc frontend -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
API_GW_IP=$(kubectl get svc api-gateway -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
RABBIT_IP=$(kubectl get svc rabbitmq-management -n database -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")

echo -e "${GREEN}Application Access Points:${NC}"
echo "----------------------------------------"
echo -e "Frontend:          http://${FRONTEND_IP:-192.168.68.210}"
echo -e "API Gateway:       http://${API_GW_IP:-192.168.68.211}:8080"
echo -e "RabbitMQ Mgmt:     http://${RABBIT_IP:-192.168.68.205}:15672"
echo "  Username: admin"
echo "  Password: admin123"

echo -e "\n${GREEN}Internal Services (ClusterIP):${NC}"
echo "----------------------------------------"
echo "PostgreSQL:        postgresql.database:5432"
echo "Redis:             redis.database:6379"
echo "RabbitMQ:          rabbitmq.database:5672"

echo -e "\n${GREEN}Test Commands:${NC}"
echo "----------------------------------------"
echo "# Test Frontend:"
echo "curl http://${FRONTEND_IP:-192.168.68.210}"
echo ""
echo "# Test API Gateway:"
echo "curl http://${API_GW_IP:-192.168.68.211}:8080"
echo "curl http://${API_GW_IP:-192.168.68.211}:8080/api/users"
echo ""
echo "# Check PostgreSQL:"
echo "kubectl exec -it postgresql-0 -n database -- psql -U admin -d microservices -c 'SELECT version();'"
echo ""
echo "# Check Redis:"
echo "kubectl exec -it deployment/redis -n database -- redis-cli ping"

echo -e "\n${GREEN}==================================="
echo -e "Deployment Complete!"
echo -e "===================================${NC}"

# Check for any pods not running
NOT_RUNNING=$(kubectl get pods -A | grep -v Running | grep -v Completed | grep -v NAME | wc -l)
if [ $NOT_RUNNING -gt 0 ]; then
    echo -e "\n${YELLOW}Warning: Some pods are not running:${NC}"
    kubectl get pods -A | grep -v Running | grep -v Completed
fi
