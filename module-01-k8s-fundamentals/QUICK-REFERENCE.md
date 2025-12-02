# Module 1: Quick Reference Guide

## Essential kubectl Commands

### Cluster & Context
```bash
kubectl cluster-info                          # Show cluster info
kubectl config current-context                # Show current context
kubectl config get-contexts                   # List all contexts
kubectl config use-context <context>          # Switch context
kubectl config set-context --current --namespace=<ns>  # Set default namespace
```

### Viewing Resources
```bash
kubectl get <resource>                        # List resources
kubectl get <resource> -o wide                # More details
kubectl get <resource> -o yaml                # YAML output
kubectl get <resource> -o json                # JSON output
kubectl get all                               # All resources in namespace
kubectl get all -A                            # All resources in all namespaces
kubectl describe <resource> <name>            # Detailed info
kubectl explain <resource>                    # Resource documentation
```

### Creating Resources
```bash
kubectl create <resource> <name>              # Create imperatively
kubectl apply -f <file.yaml>                  # Create/update declaratively
kubectl apply -f <directory>/                 # Apply all files in directory
kubectl create -f <file.yaml>                 # Create only (fails if exists)
```

### Editing & Deleting
```bash
kubectl edit <resource> <name>                # Edit in editor
kubectl delete <resource> <name>              # Delete resource
kubectl delete -f <file.yaml>                 # Delete from file
kubectl delete <resource> --all               # Delete all in namespace
```

### Pods
```bash
kubectl run <name> --image=<image>            # Create pod
kubectl logs <pod>                            # View logs
kubectl logs <pod> -f                         # Follow logs
kubectl logs <pod> -c <container>             # Specific container
kubectl logs <pod> --previous                 # Previous container instance
kubectl exec <pod> -- <command>               # Execute command
kubectl exec -it <pod> -- /bin/bash           # Interactive shell
kubectl cp <pod>:<path> <local-path>          # Copy from pod
kubectl port-forward <pod> <local>:<remote>   # Port forward
kubectl attach <pod> -c <container>           # Attach to container
```

### Deployments
```bash
kubectl create deployment <name> --image=<image> --replicas=<n>
kubectl scale deployment <name> --replicas=<n>
kubectl set image deployment/<name> <container>=<image>
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>
kubectl rollout restart deployment/<name>
kubectl autoscale deployment <name> --min=<n> --max=<n> --cpu-percent=<n>
```

### Services
```bash
kubectl expose <resource> <name> --port=<port> --target-port=<port>
kubectl expose deployment <name> --type=NodePort --port=<port>
kubectl get endpoints <service>
```

### ConfigMaps & Secrets
```bash
kubectl create configmap <name> --from-literal=<key>=<value>
kubectl create configmap <name> --from-file=<file>
kubectl create secret generic <name> --from-literal=<key>=<value>
kubectl create secret docker-registry <name> --docker-server=<server> --docker-username=<user> --docker-password=<pass>
kubectl create secret tls <name> --cert=<cert-file> --key=<key-file>
```

### Debugging
```bash
kubectl describe <resource> <name>            # Detailed info + events
kubectl get events --sort-by='.lastTimestamp' # Recent events
kubectl top nodes                             # Node resource usage
kubectl top pods                              # Pod resource usage
kubectl debug <pod> -it --image=<debug-image> # Ephemeral debug container
kubectl debug node/<node> -it --image=<image> # Debug node
```bash
## Resource Specifications

### Pod Template
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  labels:
    app: myapp
  annotations:
    description: "My pod"
spec:
  containers:

  - name: app
    image: nginx:1.25
    ports:

    - containerPort: 80
    env:

    - name: ENV_VAR
      value: "value"
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
    volumeMounts:

    - name: data
      mountPath: /data
  volumes:

  - name: data
    emptyDir: {}
```

### Deployment Template
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:

      - name: app
        image: nginx:1.25
        ports:

        - containerPort: 80
```

### Service Templates
```yaml
# ClusterIP

apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:

  - port: 80
    targetPort: 80
---
# NodePort

apiVersion: v1
kind: Service
metadata:
  name: my-nodeport
spec:
  type: NodePort
  selector:
    app: myapp
  ports:

  - port: 80
    targetPort: 80
    nodePort: 30080
---
# LoadBalancer

apiVersion: v1
kind: Service
metadata:
  name: my-lb
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:

  - port: 80
    targetPort: 80
```

### ConfigMap & Secret
```yaml
# ConfigMap

apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  key1: value1
  config.yaml: |
    setting: value
---
# Secret

apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
stringData:
  username: admin
  password: secret123
```

### PVC & StatefulSet
```yaml
# PVC

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:

    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 1Gi
---
# StatefulSet

apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: my-statefulset
spec:
  serviceName: my-service
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:

      - name: app
        image: nginx:1.25
        volumeMounts:

        - name: data
          mountPath: /data
  volumeClaimTemplates:

  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: standard
      resources:
        requests:
          storage: 1Gi
```

## Troubleshooting Flowchart

```bash
Pod not starting?
├─ Check status: kubectl get pod <name>
├─ Describe pod: kubectl describe pod <name>
├─ Check events: kubectl get events --field-selector involvedObject.name=<name>
│
├─ ImagePullBackOff?
│  └─ Fix: Check image name/tag exists
│
├─ CrashLoopBackOff?
│  ├─ Check logs: kubectl logs <pod> --previous
│  └─ Fix: Fix application error
│
├─ CreateContainerConfigError?
│  └─ Fix: Create missing ConfigMap/Secret
│
├─ Pending?
│  ├─ Check: kubectl describe pod <name>
│  ├─ Insufficient resources?
│  │  └─ Scale down or add nodes
│  └─ PVC not bound?
│     └─ Check: kubectl describe pvc <name>
│
└─ Init:Error?
   └─ Check: kubectl logs <pod> -c <init-container>

Service not accessible?
├─ Check service: kubectl get svc <name>
├─ Check endpoints: kubectl get endpoints <name>
│
├─ No endpoints?
│  ├─ Check selector: kubectl describe svc <name>
│  ├─ Check pod labels: kubectl get pods --show-labels
│  └─ Fix: Match selector to pod labels
│
├─ DNS not working?
│  ├─ Check CoreDNS: kubectl get pods -n kube-system -l k8s-app=kube-dns
│  └─ Test: kubectl run test --image=busybox --rm -it -- nslookup <service>
│
└─ Connection refused?
   └─ Check port/targetPort match container port
```

## Key Concepts

### QoS Classes

- **Guaranteed**: requests = limits (highest priority)
- **Burstable**: requests < limits (medium priority)
- **BestEffort**: no resources specified (lowest priority)

### Access Modes

- **RWO** (ReadWriteOnce): Single node read-write
- **ROX** (ReadOnlyMany): Multiple nodes read-only
- **RWX** (ReadWriteMany): Multiple nodes read-write
- **RWOP** (ReadWriteOncePod): Single pod read-write

### Service Types

- **ClusterIP**: Internal only (default)
- **NodePort**: Exposes on node IP:port (30000-32767)
- **LoadBalancer**: External load balancer (cloud only)
- **ExternalName**: CNAME redirect

### Reclaim Policies

- **Retain**: Manual cleanup (data preserved)
- **Delete**: Auto-delete when PVC deleted
- **Recycle**: Scrub data (deprecated)

## Common Patterns

### Init Container Pattern
```yaml
spec:
  initContainers:

  - name: init
    image: busybox
    command: ["sh", "-c", "until nslookup mydb; do sleep 2; done"]
  containers:

  - name: app
    image: myapp
```

### Sidecar Pattern
```yaml
spec:
  containers:

  - name: app
    image: myapp
  - name: sidecar
    image: logging-agent
```

### Multi-Container Communication
```yaml
spec:
  containers:

  - name: app
    image: app
    volumeMounts:

    - name: shared
      mountPath: /shared
  - name: sidecar
    image: sidecar
    volumeMounts:

    - name: shared
      mountPath: /shared
  volumes:

  - name: shared
    emptyDir: {}
```

## Useful Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kdp='kubectl describe pod'
alias kds='kubectl describe service'
alias kdd='kubectl describe deployment'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kgall='kubectl get all'
alias kctx='kubectl config current-context'
alias kns='kubectl config set-context --current --namespace'
```bash
## Documentation Links

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [kubectl Reference](https://kubernetes.io/docs/reference/kubectl/)
- [API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

**Print this guide** for quick reference during hands-on practice!
