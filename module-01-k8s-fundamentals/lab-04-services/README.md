# Lab 4: Services & Networking

## Objective

Master Kubernetes Services to expose and connect applications. Learn different service types, DNS resolution, and service discovery patterns.

## What You'll Learn

- Understand Kubernetes networking model
- Create and use ClusterIP services (internal)
- Expose applications with NodePort services
- Configure LoadBalancer services
- Use headless services for StatefulSets
- Implement service discovery via DNS
- Use endpoints and endpoint slices
- Configure session affinity

## Prerequisites

- Completed Labs 1-3
- kind cluster running with multiple nodes
- Understanding of Deployments

## Lab Steps

### Step 1: Setup Environment

1. **Create namespace and deployment**:
```bash
kubectl create namespace lab-04
kubectl config set-context --current --namespace=lab-04
```

2. **Create a sample application**:

Save as `deployment-backend.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      containers:

      - name: nginx
        image: nginx:1.25
        ports:

        - containerPort: 80
        env:

        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        volumeMounts:

        - name: html
          mountPath: /usr/share/nginx/html
      initContainers:

      - name: install-html
        image: busybox:1.36
        command:

        - sh
        - -c
        - |
          echo "<h1>Backend Service</h1>" > /html/index.html
          echo "<p>Pod: $POD_NAME</p>" >> /html/index.html
          echo "<p>IP: $POD_IP</p>" >> /html/index.html
        env:

        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        volumeMounts:

        - name: html
          mountPath: /html
      volumes:

      - name: html
        emptyDir: {}
```

Apply it:
```bash
kubectl apply -f deployment-backend.yaml
kubectl get pods -l app=backend
```

### Step 2: ClusterIP Service (Default, Internal Only)

ClusterIP is the default service type - accessible only within the cluster.

1. **Create ClusterIP service imperatively**:
```bash
kubectl expose deployment backend --port=80 --target-port=80 --name=backend-clusterip
```

2. **Inspect the service**:
```bash
kubectl get service backend-clusterip
kubectl describe service backend-clusterip
```

Note the:

- **ClusterIP**: Virtual IP assigned (e.g., 10.96.x.x)
- **Endpoints**: Pod IPs that back the service
- **Port/TargetPort**: Service port vs container port

3. **View endpoints**:
```bash
kubectl get endpoints backend-clusterip
```

Shows all pod IPs that match the service selector.

4. **Test the service from within cluster**:
```bash
# Create a test pod

kubectl run test-pod --image=busybox:1.36 --rm -it --restart=Never -- sh

# Inside the pod:

wget -qO- http://backend-clusterip
wget -qO- http://backend-clusterip
wget -qO- http://backend-clusterip
exit
```

Each request may hit a different pod (load balancing).

5. **Create declarative ClusterIP service**:

Save as `service-clusterip.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  labels:
    app: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:

  - port: 8080        # Service port
    targetPort: 80    # Container port
    protocol: TCP
    name: http
  sessionAffinity: None
```

Apply and test:
```bash
kubectl apply -f service-clusterip.yaml
kubectl run test-pod --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://backend-svc:8080
```bash
### Step 3: DNS-Based Service Discovery

Kubernetes provides automatic DNS for services.

1. **Understand DNS naming**:

- **Same namespace**: `<service-name>`
- **Different namespace**: `<service-name>.<namespace>`
- **Fully qualified**: `<service-name>.<namespace>.svc.cluster.local`

2. **Test DNS resolution**:
```bash
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- sh

# Inside the pod:
# Short name (same namespace)

nslookup backend-svc

# FQDN

nslookup backend-svc.lab-04.svc.cluster.local

# Check DNS config

cat /etc/resolv.conf
exit
```

3. **Test cross-namespace service discovery**:
```bash
# Create service in different namespace

kubectl create namespace other-ns
kubectl create deployment nginx --image=nginx:1.25 -n other-ns
kubectl expose deployment nginx --port=80 -n other-ns

# Test from lab-04 namespace

kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://nginx.other-ns
```

### Step 4: NodePort Service (External Access)

NodePort exposes the service on each node's IP at a static port.

1. **Create NodePort service**:

Save as `service-nodeport.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-nodeport
spec:
  type: NodePort
  selector:
    app: backend
  ports:

  - port: 80          # Service port
    targetPort: 80    # Container port
    nodePort: 30080   # External port (30000-32767)
    protocol: TCP
```

Apply:
```bash
kubectl apply -f service-nodeport.yaml
kubectl get service backend-nodeport
```

2. **Access via NodePort**:
```bash
# Get node IP

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Access from your host

curl http://$NODE_IP:30080
```bash
For kind clusters, you need port forwarding:
```bash
# Map the NodePort to localhost

kubectl port-forward service/backend-nodeport 8080:80

# In another terminal:

curl http://localhost:8080
```

3. **Let Kubernetes assign NodePort automatically**:

Save as `service-nodeport-auto.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-nodeport-auto
spec:
  type: NodePort
  selector:
    app: backend
  ports:

  - port: 80
    targetPort: 80
    # nodePort is omitted - will be auto-assigned
```

Apply and check:
```bash
kubectl apply -f service-nodeport-auto.yaml
kubectl get service backend-nodeport-auto
# Note the assigned NodePort (30000-32767 range)
```

### Step 5: LoadBalancer Service (Cloud Provider)

LoadBalancer requests an external load balancer from cloud provider.

1. **Create LoadBalancer service**:

Save as `service-loadbalancer.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-lb
spec:
  type: LoadBalancer
  selector:
    app: backend
  ports:

  - port: 80
    targetPort: 80
    protocol: TCP
```

Apply:
```bash
kubectl apply -f service-loadbalancer.yaml
kubectl get service backend-lb --watch
```

**Note**: In kind/minikube, EXTERNAL-IP stays `<pending>` (no cloud provider). In real cloud (AKS, EKS, GKE), you'd get a public IP.

2. **Simulate LoadBalancer with MetalLB** (optional for kind):

For local testing, you can install MetalLB:
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Wait for pods to be ready

kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s
```bash
Configure IP pool (adjust for your kind network):
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:

  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
```

### Step 6: Headless Services (No Load Balancing)

Headless services return pod IPs directly instead of a virtual IP.

1. **Create headless service**:

Save as `service-headless.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-headless
spec:
  clusterIP: None  # This makes it headless
  selector:
    app: backend
  ports:

  - port: 80
    targetPort: 80
```

Apply:
```bash
kubectl apply -f service-headless.yaml
kubectl get service backend-headless
# ClusterIP shows "None"
```

2. **Test DNS returns all pod IPs**:
```bash
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- nslookup backend-headless

# You'll see multiple A records (one per pod)
```

This is useful for:

- StatefulSets (need to address specific pods)
- Client-side load balancing
- Service discovery where you need all pod IPs

### Step 7: ExternalName Service (CNAME Redirect)

Maps a service to an external DNS name.

1. **Create ExternalName service**:

Save as `service-externalname.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: api.github.com
```

Apply:
```bash
kubectl apply -f service-externalname.yaml
```

2. **Test DNS resolution**:
```bash
kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- nslookup external-api

# Returns CNAME pointing to api.github.com
```

Use case: Abstract external dependencies, easier to change later.

### Step 8: Session Affinity (Sticky Sessions)

Ensure requests from same client go to same pod.

1. **Create service with session affinity**:

Save as `service-affinity.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-sticky
spec:
  type: ClusterIP
  selector:
    app: backend
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600  # 1 hour
  ports:

  - port: 80
    targetPort: 80
```

Apply and test:
```bash
kubectl apply -f service-affinity.yaml

# Test multiple requests

for i in {1..10}; do
  kubectl run test-$i --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://backend-sticky
done
```bash
From the same source IP, requests should hit the same pod.

### Step 9: Multi-Port Services

Services can expose multiple ports.

1. **Create deployment with multiple ports**:

Save as `deployment-multiport.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-multiport
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp-multi
  template:
    metadata:
      labels:
        app: webapp-multi
    spec:
      containers:

      - name: app
        image: nginx:1.25
        ports:

        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
```

2. **Create multi-port service**:

Save as `service-multiport.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-multiport-svc
spec:
  selector:
    app: webapp-multi
  ports:

  - name: http      # Must name ports when multiple
    port: 80
    targetPort: http
    protocol: TCP
  - name: https
    port: 443
    targetPort: https
    protocol: TCP
```

Apply:
```bash
kubectl apply -f deployment-multiport.yaml
kubectl apply -f service-multiport.yaml
kubectl describe service webapp-multiport-svc
```

### Step 10: Endpoints and EndpointSlices

1. **View endpoints**:
```bash
kubectl get endpoints backend-svc -o yaml
```

Shows pod IPs and ports backing the service.

2. **View endpoint slices** (newer, more scalable):
```bash
kubectl get endpointslices
kubectl describe endpointslice backend-svc-<suffix>
```

3. **Create service without selector** (manual endpoints):

Save as `service-manual-endpoints.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  ports:

  - port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-db  # Must match service name
subsets:

- addresses:

  - ip: 192.168.1.100  # External database IP
  ports:

  - port: 5432
```

Use case: Connect to external databases or services outside Kubernetes.

### Step 11: Service Testing and Debugging

1. **Check service connectivity**:
```bash
# From within a pod

kubectl run test --image=nicolaka/netshoot --rm -it --restart=Never -- bash

# Inside the container:

curl http://backend-svc
dig backend-svc.lab-04.svc.cluster.local
nslookup backend-svc
ping backend-svc  # Won't work (no ICMP), but DNS resolves

# Test specific endpoint

curl http://<pod-ip>

# Trace route

traceroute backend-svc
exit
```

2. **Check service is routing correctly**:
```bash
# Get service endpoints

kubectl get endpoints backend-svc

# Get pod IPs

kubectl get pods -l app=backend -o wide

# They should match
```

3. **Common issues debugging**:
```bash
# No endpoints?

kubectl describe service backend-svc
# Check selector matches pod labels

# Can't resolve DNS?

kubectl get pods -n kube-system -l k8s-app=kube-dns
# CoreDNS should be running

# Service exists but can't connect?

kubectl describe service backend-svc
# Check ports match (port vs targetPort)
```

## Validation

Verify your setup:

```bash
# 1. ClusterIP service has endpoints

kubectl get endpoints backend-svc | grep -v "ENDPOINTS"
# Should show pod IPs

# 2. DNS resolution works

kubectl run test --image=busybox:1.36 --rm --restart=Never -- nslookup backend-svc
# Should resolve to service IP

# 3. NodePort is accessible

kubectl get service backend-nodeport -o jsonpath='{.spec.ports[0].nodePort}'
# Should show port number (30080)

# 4. All services are running

kubectl get services
# Should list multiple services

# 5. Test connectivity

kubectl run test --image=busybox:1.36 --rm --restart=Never -- wget -qO- http://backend-svc
# Should return HTML
```

## Practice Challenges

Test your skills:

1. **Challenge 1**: Create a deployment with 4 replicas and expose it with ClusterIP on port 8080 (container uses port 80)
   <details>
   <summary>Solution</summary>
   ```bash
   kubectl create deployment app --image=nginx:1.25 --replicas=4
   kubectl expose deployment app --port=8080 --target-port=80
   ```
   </details>

2. **Challenge 2**: Create a headless service and verify DNS returns all pod IPs
   <details>
   <summary>Hint</summary>
   Set `clusterIP: None` and use nslookup to see all A records
   </details>

3. **Challenge 3**: Expose an application on NodePort 30100 and test access
   <details>
   <summary>Solution</summary>
   ```yaml
   spec:
     type: NodePort
     ports:

     - port: 80
       nodePort: 30100
   ```bash
   </details>

4. **Challenge 4**: Create a service that routes to pods with labels `app=web` OR `app=api`
   <details>
   <summary>Hint</summary>
   Services only support AND logic in selectors, not OR. You'd need to add a common label to both deployments.
   </details>

5. **Challenge 5**: Debug why a service has no endpoints
   <details>
   <summary>Checklist</summary>
   - Verify selector matches pod labels exactly
   - Check pods are running and ready
   - Verify targetPort matches container port
   - Check if pods are in same namespace
   </details>

## Cleanup

Remove all resources:

```bash
kubectl delete namespace lab-04
kubectl delete namespace other-ns
```bash
## Troubleshooting Guide

| Issue | Diagnostic | Solution |
|-------|-----------|----------|
| Service has no endpoints | `kubectl describe svc <name>` | Check selector matches pod labels |
| Can't access ClusterIP | Test from within cluster | ClusterIP is internal only |
| DNS not resolving | Check CoreDNS pods | `kubectl get pods -n kube-system -l k8s-app=kube-dns` |
| NodePort not accessible | Check nodePort range | Must be 30000-32767 |
| LoadBalancer pending | Check cloud provider | Need cloud or MetalLB for local |
| Wrong pod receiving traffic | Check pod labels | Verify selector matches |

**Essential debugging commands**:
```bash
kubectl get service <name> -o wide
kubectl describe service <name>
kubectl get endpoints <name>
kubectl logs -n kube-system -l k8s-app=kube-dns
kubectl run test --image=nicolaka/netshoot --rm -it -- bash
```

## Key Takeaways

- ✅ **ClusterIP**: Default, internal only, gets a virtual IP
- ✅ **NodePort**: Exposes on all node IPs at static port (30000-32767)
- ✅ **LoadBalancer**: Requests external LB (cloud provider needed)
- ✅ **Headless**: No virtual IP, returns pod IPs directly (clusterIP: None)
- ✅ **ExternalName**: CNAME redirect to external DNS
- ✅ Services provide **stable endpoints** for dynamic pods
- ✅ DNS format: `service.namespace.svc.cluster.local`
- ✅ Selectors must **exactly match** pod labels
- ✅ Port vs TargetPort: service port vs container port
- ✅ Session affinity enables sticky sessions

## Additional Resources

- [Service Documentation](https://kubernetes.io/docs/concepts/services-networking/service/)
- [DNS for Services](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Connecting Applications](https://kubernetes.io/docs/tutorials/services/connect-applications-service/)
- [EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/)

## Next Lab

[Lab 5: ConfigMaps & Secrets](../lab-05-config-secrets/) - Learn configuration and secrets management

---

**Estimated Time**: 90-120 minutes
