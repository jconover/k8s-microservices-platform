## Phase 1: Initial Setup (ALL NODES)
01.     ./scripts/00-update-hosts.sh             # Setup hostname resolution
02.     sudo ./scripts/01-install-prerequisites-all-nodes.sh  # Install K8s components
03.     sudo reboot                               # Reboot all nodes

### Phase 2: Cluster Creation (MASTER ONLY)
04.     ./scripts/02-setup-master.sh              # Initialize cluster
    ### Save the join command!

### Phase 3: Join Workers (WORKER NODES)
05.     sudo kubeadm join ...                     # Run on each worker

### Phase 4: Core Services (MASTER)
06.     ./scripts/03-deploy-core-services.sh      # Deploy monitoring, storage, etc.

### Phase 5: Applications (MASTER)
07.     ./scripts/04-deploy-applications.sh       # Deploy microservices
08.     ./scripts/05-setup-ingress-routes.sh      # Configure ingress

### Phase 6: Verification (MASTER)
09.     ./scripts/99-verify-cluster.sh            # Verify everything is working
10.     ./scripts/get-passwords.sh                # Get all service credentials


***

# Quick Test after Setup:

### Test the cluster is working:
    kubectl run test-pod --image=nginx --port=80
    kubectl expose pod test-pod --type=LoadBalancer --port=80 --target-port=80
    kubectl get svc test-pod

### Should get an IP from your MetalLB pool (192.168.68.200-250)
### Test with: curl http://[assigned-ip]

### Cleanup test
    kubectl delete pod test-pod
    kubectl delete svc test-pod