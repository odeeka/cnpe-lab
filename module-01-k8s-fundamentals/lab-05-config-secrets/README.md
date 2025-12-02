# Lab 5: ConfigMaps & Secrets

## Objective

Master configuration management in Kubernetes. Learn to externalize configuration using ConfigMaps and manage sensitive data with Secrets.

## What You'll Learn

- Create and manage ConfigMaps
- Use ConfigMaps as environment variables
- Mount ConfigMaps as volumes
- Create and use Secrets
- Understand Secret types (Opaque, TLS, Docker registry)
- Implement immutable ConfigMaps/Secrets
- Best practices for configuration management
- Decode and encode base64 secrets

## Prerequisites

- Completed Labs 1-4
- kind cluster running
- Understanding of Deployments and environment variables

## Lab Steps

### Step 1: Setup Environment

```bash
kubectl create namespace lab-05
kubectl config set-context --current --namespace=lab-05
```

### Step 2: Create ConfigMaps (Imperative)

ConfigMaps store non-confidential configuration data as key-value pairs.

1. **Create from literal values**:
```bash
kubectl create configmap app-config \
  --from-literal=database_host=postgres.example.com \
  --from-literal=database_port=5432 \
  --from-literal=log_level=info
```

2. **View the ConfigMap**:
```bash
kubectl get configmap app-config
kubectl describe configmap app-config
kubectl get configmap app-config -o yaml
```

3. **Create from file**:

Create a config file:
```bash
cat > app.properties <<EOF
app.name=MyApp
app.version=1.0.0
app.environment=production
max_connections=100
timeout=30
EOF
```

Create ConfigMap from file:
```bash
kubectl create configmap app-properties --from-file=app.properties
```

View it:
```bash
kubectl get configmap app-properties -o yaml
```

4. **Create from directory**:
```bash
mkdir config
echo "redis://localhost:6379" > config/redis.conf
echo "rabbitmq://localhost:5672" > config/rabbitmq.conf

kubectl create configmap app-configs --from-file=config/
kubectl describe configmap app-configs
```

5. **Create from env file**:
```bash
cat > app.env <<EOF
DB_HOST=postgres
DB_PORT=5432
CACHE_ENABLED=true
EOF

kubectl create configmap app-env --from-env-file=app.env
kubectl get configmap app-env -o yaml
```

### Step 3: Create ConfigMaps (Declarative)

1. **Simple key-value ConfigMap**:

Save as `configmap-simple.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
data:
  # Simple key-value pairs
  database_host: "postgres.lab-05.svc.cluster.local"
  database_port: "5432"
  database_name: "webapp_db"
  log_level: "debug"
  feature_flag_new_ui: "true"
```

Apply:
```bash
kubectl apply -f configmap-simple.yaml
```

2. **ConfigMap with file content**:

Save as `configmap-files.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  # Inline file content
  nginx.conf: |
    user nginx;
    worker_processes auto;
    error_log /var/log/nginx/error.log;
    
    events {
        worker_connections 1024;
    }
    
    http {
        log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for"';
        
        access_log /var/log/nginx/access.log main;
        
        server {
            listen 80;
            server_name localhost;
            
            location / {
                root /usr/share/nginx/html;
                index index.html;
            }
            
            location /health {
                access_log off;
                return 200 "healthy\n";
                add_header Content-Type text/plain;
            }
        }
    }
  
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>ConfigMap Demo</title></head>
    <body>
        <h1>Configuration from ConfigMap</h1>
        <p>This HTML was loaded from a ConfigMap!</p>
    </body>
    </html>
```

Apply:
```bash
kubectl apply -f configmap-files.yaml
```

### Step 4: Use ConfigMaps as Environment Variables

1. **Inject all keys as env vars**:

Save as `pod-configmap-env.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-env-demo
spec:
  containers:

  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "env | sort && sleep 3600"]
    envFrom:

    - configMapRef:
        name: webapp-config
  restartPolicy: Never
```

Apply and check:
```bash
kubectl apply -f pod-configmap-env.yaml
kubectl logs app-env-demo | grep -E "database|log_level"
```

2. **Inject specific keys as env vars**:

Save as `pod-configmap-specific-env.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-specific-env
spec:
  containers:

  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo DB_HOST=$DB_HOST DB_PORT=$DB_PORT && sleep 3600"]
    env:

    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: database_host
    - name: DB_PORT
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: database_port
    - name: STATIC_VALUE
      value: "hardcoded"
  restartPolicy: Never
```

Apply and verify:
```bash
kubectl apply -f pod-configmap-specific-env.yaml
kubectl logs app-specific-env
```

### Step 5: Mount ConfigMaps as Volumes

1. **Mount entire ConfigMap**:

Save as `pod-configmap-volume.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-with-config
spec:
  containers:

  - name: nginx
    image: nginx:1.25
    volumeMounts:

    - name: config-volume
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf    # Mount specific file, not directory
    - name: html-volume
      mountPath: /usr/share/nginx/html
  volumes:

  - name: config-volume
    configMap:
      name: nginx-config
  - name: html-volume
    configMap:
      name: nginx-config
      items:

      - key: index.html
        path: index.html
```

Apply and test:
```bash
kubectl apply -f pod-configmap-volume.yaml

# Wait for pod to be ready

kubectl wait --for=condition=ready pod/nginx-with-config --timeout=60s

# Test the configuration

kubectl port-forward pod/nginx-with-config 8080:80 &
sleep 2
curl http://localhost:8080
curl http://localhost:8080/health
kill %1  # Stop port-forward
```

2. **Mount with custom file permissions**:

Save as `pod-configmap-permissions.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-config-perms
spec:
  containers:

  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "ls -la /config && cat /config/app.properties && sleep 3600"]
    volumeMounts:

    - name: config
      mountPath: /config
  volumes:

  - name: config
    configMap:
      name: app-properties
      defaultMode: 0600  # rw-------
```

Apply:
```bash
kubectl apply -f pod-configmap-permissions.yaml
kubectl logs app-config-perms
```

### Step 6: Create Secrets

Secrets store sensitive data like passwords, tokens, keys.

1. **Create from literal values**:
```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=SuperSecret123!
```

2. **View the Secret**:
```bash
kubectl get secret db-credentials
kubectl describe secret db-credentials
# Note: values are hidden in describe

kubectl get secret db-credentials -o yaml
# Values are base64 encoded
```

3. **Decode secret values**:
```bash
# Get encoded password

kubectl get secret db-credentials -o jsonpath='{.data.password}'

# Decode it

kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 -d
echo
```

4. **Create from file**:
```bash
# Create SSH key (example)

ssh-keygen -t rsa -b 2048 -f id_rsa -N ""

kubectl create secret generic ssh-key \
  --from-file=id_rsa=./id_rsa \
  --from-file=id_rsa.pub=./id_rsa.pub
```

5. **Create from YAML** (not recommended for prod):

Save as `secret-basic.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  # Values must be base64 encoded
  api_key: U3VwZXJTZWNyZXRBUElLZXkxMjM=  # "SuperSecretAPIKey123"
  token: bXktc2VjcmV0LXRva2Vu          # "my-secret-token"
```

To encode values:
```bash
echo -n "SuperSecretAPIKey123" | base64
echo -n "my-secret-token" | base64
```

Apply:
```bash
kubectl apply -f secret-basic.yaml
```

6. **String data (auto-encoded)**:

Save as `secret-stringdata.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-credentials
type: Opaque
stringData:
  # Values in plain text, Kubernetes encodes them
  username: admin
  password: VerySecurePassword123!
  api_url: https://api.example.com
```

Apply:
```bash
kubectl apply -f secret-stringdata.yaml
kubectl get secret app-credentials -o yaml
# Values are now base64 encoded
```

### Step 7: Use Secrets in Pods

1. **Inject secrets as environment variables**:

Save as `pod-secret-env.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secrets
spec:
  containers:

  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo Username: $DB_USER && echo Password: $DB_PASS && sleep 3600"]
    env:

    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
  restartPolicy: Never
```

Apply and check:
```bash
kubectl apply -f pod-secret-env.yaml
kubectl logs app-with-secrets
```

2. **Mount secrets as volumes** (more secure):

Save as `pod-secret-volume.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-secret-volume
spec:
  containers:

  - name: app
    image: busybox:1.36
    command: 

    - sh
    - -c
    - |
      echo "=== Checking mounted secrets ==="
      ls -la /secrets
      echo "Username: $(cat /secrets/username)"
      echo "Password: $(cat /secrets/password)"
      sleep 3600
    volumeMounts:

    - name: secrets
      mountPath: /secrets
      readOnly: true
  volumes:

  - name: secrets
    secret:
      secretName: db-credentials
      defaultMode: 0400  # r--------
```

Apply:
```bash
kubectl apply -f pod-secret-volume.yaml
kubectl logs app-secret-volume
```

**Best Practice**: Volume mount is more secure than env vars:

- Env vars can leak in logs/crashes
- Volumes support automatic rotation
- Volumes have better permission control

### Step 8: Docker Registry Secrets

1. **Create docker-registry secret**:
```bash
kubectl create secret docker-registry my-registry-secret \
  --docker-server=docker.io \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=my@email.com
```

2. **Use in pod**:

Save as `pod-private-image.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-image-pod
spec:
  imagePullSecrets:

  - name: my-registry-secret
  containers:

  - name: app
    image: myuser/private-app:latest
```

### Step 9: TLS Secrets

1. **Create self-signed certificate**:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=example.com/O=example"
```

2. **Create TLS secret**:
```bash
kubectl create secret tls tls-secret \
  --cert=tls.crt \
  --key=tls.key
```

3. **View TLS secret**:
```bash
kubectl get secret tls-secret -o yaml
```

Note: Contains `tls.crt` and `tls.key` keys.

4. **Use in nginx with TLS**:

Save as `pod-nginx-tls.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-tls-config
data:
  nginx.conf: |
    events { worker_connections 1024; }
    http {
      server {
        listen 443 ssl;
        server_name example.com;
        
        ssl_certificate /etc/nginx/ssl/tls.crt;
        ssl_certificate_key /etc/nginx/ssl/tls.key;
        
        location / {
          return 200 "Secure connection!\n";
          add_header Content-Type text/plain;
        }
      }
    }
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-tls
spec:
  containers:

  - name: nginx
    image: nginx:1.25
    ports:

    - containerPort: 443
    volumeMounts:

    - name: tls
      mountPath: /etc/nginx/ssl
      readOnly: true
    - name: config
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
  volumes:

  - name: tls
    secret:
      secretName: tls-secret
  - name: config
    configMap:
      name: nginx-tls-config
```

Apply and test:
```bash
kubectl apply -f pod-nginx-tls.yaml
kubectl wait --for=condition=ready pod/nginx-tls --timeout=60s

# Test HTTPS

kubectl port-forward pod/nginx-tls 8443:443 &
sleep 2
curl -k https://localhost:8443
kill %1
```

### Step 10: Immutable ConfigMaps and Secrets

Immutable ConfigMaps/Secrets cannot be modified (better performance, security).

1. **Create immutable ConfigMap**:

Save as `configmap-immutable.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
immutable: true
data:
  key1: value1
  key2: value2
```

Apply:
```bash
kubectl apply -f configmap-immutable.yaml
```

2. **Try to modify it**:
```bash
kubectl patch configmap immutable-config --type merge -p '{"data":{"key1":"new-value"}}'
# Error: field is immutable
```

To update: delete and recreate (with rolling update of pods):
```bash
kubectl delete configmap immutable-config
kubectl apply -f configmap-immutable.yaml
# Pods referencing it will need to be recreated
```

### Step 11: Deployment with ConfigMap and Secret

Real-world example combining everything.

Save as `deployment-full.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config-v1
data:
  app.conf: |
    [server]
    port=8080
    log_level=info
    
    [database]
    host=postgres.lab-05.svc.cluster.local
    port=5432
    name=webapp_db
---
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets-v1
type: Opaque
stringData:
  db_username: app_user
  db_password: SecurePass123!
  api_key: sk-1234567890abcdef
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:

      - name: app
        image: nginx:1.25
        env:
        # Mix of ConfigMap and Secret env vars
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: webapp-config-v1
              key: app.conf  # Would parse this in real app
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: webapp-secrets-v1
              key: db_username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: webapp-secrets-v1
              key: db_password
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: webapp-secrets-v1
              key: api_key
        volumeMounts:

        - name: config
          mountPath: /etc/config
          readOnly: true
        - name: secrets
          mountPath: /etc/secrets
          readOnly: true
      volumes:

      - name: config
        configMap:
          name: webapp-config-v1
      - name: secrets
        secret:
          secretName: webapp-secrets-v1
          defaultMode: 0400
```

Apply:
```bash
kubectl apply -f deployment-full.yaml
kubectl get pods -l app=webapp

# Verify config is mounted

POD=$(kubectl get pod -l app=webapp -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- cat /etc/config/app.conf
kubectl exec $POD -- ls -la /etc/secrets
```

### Step 12: ConfigMap and Secret Updates

1. **Update ConfigMap**:
```bash
kubectl edit configmap webapp-config-v1
# Change log_level=info to log_level=debug
```

**Important**: Pods don't automatically reload! Two approaches:

**Approach 1**: Rolling restart
```bash
kubectl rollout restart deployment webapp
```

**Approach 2**: Version your ConfigMaps
```yaml
# Create webapp-config-v2 with changes
# Update deployment to reference v2
# Kubernetes will perform rolling update
```

2. **Test automatic volume update** (without pod restart):

Create a simple test:
```bash
kubectl create configmap test-config --from-literal=message="Hello v1"

kubectl run test --image=busybox:1.36 -- sh -c "while true; do cat /config/message 2>/dev/null && echo; sleep 5; done"

kubectl exec test -- cat /config/message
```

Wait for pod to be running, then update ConfigMap:
```bash
kubectl patch configmap test-config -p '{"data":{"message":"Hello v2"}}'

# Watch logs - update may take ~60s

kubectl logs test -f
```

You'll see the message change without pod restart!

## Validation

Verify your understanding:

```bash
# 1. List all ConfigMaps

kubectl get configmaps
# Should see multiple ConfigMaps

# 2. List all Secrets

kubectl get secrets
# Should see multiple Secrets

# 3. Verify webapp deployment is running

kubectl get deployment webapp -o jsonpath='{.status.readyReplicas}'
# Should match desired replicas

# 4. Check secret is properly base64 encoded

kubectl get secret app-secrets -o jsonpath='{.data.api_key}' | base64 -d
# Should output: SuperSecretAPIKey123

# 5. Verify ConfigMap is mounted in pod

POD=$(kubectl get pod -l app=webapp -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- ls /etc/config
# Should show app.conf
```

## Practice Challenges

Test your skills:

1. **Challenge 1**: Create a ConfigMap from a properties file and mount it at `/config/app.properties`
   <details>
   <summary>Solution</summary>
   ```bash
   echo "app.name=MyApp" > app.properties
   kubectl create configmap myconfig --from-file=app.properties
   # Then mount in pod volumeMounts
   ```bash
   </details>

2. **Challenge 2**: Create a Secret for database connection (host, user, password) and use in a pod
   <details>
   <summary>Hint</summary>
   Use `kubectl create secret generic` with `--from-literal` for each field
   </details>

3. **Challenge 3**: Create an immutable ConfigMap and try to update it
   <details>
   <summary>Expected</summary>
   Update will fail - must delete and recreate
   </details>

4. **Challenge 4**: Create a TLS secret and use it in nginx to serve HTTPS
   <details>
   <summary>Steps</summary>
   1. Generate cert with openssl
   2. Create TLS secret
   3. Mount in nginx at /etc/nginx/ssl
   4. Configure nginx.conf for SSL
   </details>

5. **Challenge 5**: Update a ConfigMap and perform a rolling restart of the deployment
   <details>
   <summary>Solution</summary>
   ```bash
   kubectl edit configmap <name>
   kubectl rollout restart deployment <name>
   ```
   </details>

## Cleanup

Remove all resources:

```bash
kubectl delete namespace lab-05
rm -f app.properties app.env tls.* id_rsa* config/
```bash
## Troubleshooting Guide

| Issue | Cause | Solution |
|-------|-------|----------|
| Pod can't find ConfigMap | Doesn't exist or wrong name | `kubectl get cm` to verify |
| Secret not decoded in pod | Mounted as volume | Secrets in volumes are auto-decoded |
| ConfigMap changes not reflected | Pods cache data | Rolling restart deployment |
| Permission denied on mounted files | Wrong defaultMode | Set appropriate mode (0400, 0600, etc.) |
| Can't create ConfigMap from file | File doesn't exist | Verify file path |

## Key Takeaways

- ✅ **ConfigMaps**: Non-confidential configuration (env vars, files, command args)
- ✅ **Secrets**: Sensitive data (passwords, tokens, certificates)
- ✅ **Environment variables**: Simple but can leak, no auto-update
- ✅ **Volume mounts**: More secure, supports auto-update, better permissions
- ✅ **Immutable**: Better performance, prevent accidental changes
- ✅ **Secret types**: Opaque (generic), TLS (certs), docker-registry (image pull)
- ✅ **Base64**: Encoding, not encryption - secrets are not encrypted by default
- ✅ **Version your config**: Use v1, v2 suffixes for controlled rollouts
- ✅ **Best practice**: Mount secrets as volumes, not env vars
- ✅ **Updates**: ConfigMaps/Secrets mounted as volumes update automatically (~60s)

## Additional Resources

- [ConfigMaps Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Configure Pods with ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [Distribute Credentials Securely](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/)

## Next Lab

[Lab 6: Storage & Persistence](../lab-06-storage/) - Learn persistent storage with PVs and PVCs

---

**Estimated Time**: 90-120 minutes
