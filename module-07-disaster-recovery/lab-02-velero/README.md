# Lab 2: Velero Deep Dive

## 🎯 Objectives

By the end of this lab, you will:
- Install and configure Velero
- Perform backup and restore operations
- Implement scheduled backups with retention
- Execute cross-cluster migration
- Use Velero with CSI snapshots and Restic

## ⏱️ Estimated Time: 90 minutes

---

## Part 1: Velero Architecture

### Understanding Velero Components

```
┌─────────────────────────────────────────────────────────────────┐
│                     Velero Architecture                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Velero Server                             │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │ │
│  │  │  Backup     │  │  Restore    │  │  Schedule           │  │ │
│  │  │  Controller │  │  Controller │  │  Controller         │  │ │
│  │  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │ │
│  │         │                │                     │             │ │
│  └─────────┼────────────────┼─────────────────────┼─────────────┘ │
│            │                │                     │               │
│            ▼                ▼                     ▼               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                     Kubernetes API                           │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐ │ │
│  │  │ Backups │  │Restores │  │Schedules│  │BackupStorageLoc │ │ │
│  │  │  (CRD)  │  │  (CRD)  │  │  (CRD)  │  │     (CRD)       │ │ │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                              │                                    │
│                              ▼                                    │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                   Storage Providers                          │ │
│  │                                                               │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐ │ │
│  │  │   AWS   │  │   GCP   │  │  Azure  │  │     MinIO       │ │ │
│  │  │   S3    │  │   GCS   │  │  Blob   │  │    (S3 API)     │ │ │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────────────┘ │ │
│  │                                                               │ │
│  │  Volume Snapshot Providers:                                   │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐ │ │
│  │  │AWS EBS  │  │GCP PD   │  │Azure    │  │ CSI Snapshots   │ │ │
│  │  │Snapshots│  │Snapshots│  │Snapshots│  │                 │ │ │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                     Node Agent (Restic)                      │ │
│  │  • File-level backups                                        │ │
│  │  • Deduplication                                             │ │
│  │  • Encryption                                                │ │
│  │  • Runs as DaemonSet                                         │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Backup Types

| Type | Description | Use Case |
|------|-------------|----------|
| **Full** | All resources and volumes | Initial backup |
| **Namespace** | Specific namespace(s) | Application backup |
| **Resource** | Specific resource types | Selective backup |
| **Label-based** | Resources matching labels | Microservice backup |

---

## Part 2: Installing Velero

### Prerequisites Setup

```bash
# Create backup storage (MinIO for local development)
kubectl create namespace velero

# Deploy MinIO
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: velero
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: "minioadmin"
        - name: MINIO_ROOT_PASSWORD
          value: "minioadmin"
        ports:
        - containerPort: 9000
        - containerPort: 9001
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        emptyDir:
          sizeLimit: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: velero
spec:
  ports:
  - port: 9000
    name: api
  - port: 9001
    name: console
  selector:
    app: minio
EOF

# Wait for MinIO to be ready
kubectl wait --for=condition=ready pod -l app=minio -n velero --timeout=120s

# Create bucket
kubectl exec -n velero deploy/minio -- mc alias set local http://localhost:9000 minioadmin minioadmin
kubectl exec -n velero deploy/minio -- mc mb local/velero-backups
```

### Install Velero CLI

```bash
# Download Velero CLI
VELERO_VERSION="v1.13.0"
wget https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-amd64.tar.gz
tar -xzf velero-${VELERO_VERSION}-linux-amd64.tar.gz
sudo mv velero-${VELERO_VERSION}-linux-amd64/velero /usr/local/bin/

# Verify installation
velero version --client-only
```

### Install Velero Server

```bash
# Create credentials file for MinIO
cat > credentials-velero <<EOF
[default]
aws_access_key_id = minioadmin
aws_secret_access_key = minioadmin
EOF

# Install Velero with AWS plugin (for S3-compatible storage)
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket velero-backups \
  --secret-file ./credentials-velero \
  --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://minio.velero.svc:9000 \
  --use-node-agent \
  --default-volumes-to-fs-backup

# Verify installation
kubectl get pods -n velero
velero version
```

### Velero Installation with Helm

```bash
# Add Helm repository
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

# Create values file
cat > velero-values.yaml <<EOF
initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.9.0
    volumeMounts:
      - mountPath: /target
        name: plugins

configuration:
  backupStorageLocation:
    - name: default
      provider: aws
      bucket: velero-backups
      config:
        region: minio
        s3ForcePathStyle: true
        s3Url: http://minio.velero.svc:9000

  volumeSnapshotLocation:
    - name: default
      provider: aws
      config:
        region: minio

credentials:
  useSecret: true
  secretContents:
    cloud: |
      [default]
      aws_access_key_id = minioadmin
      aws_secret_access_key = minioadmin

deployNodeAgent: true
nodeAgent:
  podVolumePath: /var/lib/kubelet/pods

schedules:
  daily-backup:
    disabled: false
    schedule: "0 2 * * *"
    template:
      ttl: 168h  # 7 days
      includedNamespaces:
        - production
        - staging
EOF

# Install with Helm
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --values velero-values.yaml
```

---

## Part 3: Basic Backup and Restore

### Create Sample Application

```yaml
# sample-app.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo-app
  labels:
    app: demo
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: demo-app
data:
  config.json: |
    {
      "database": "postgres",
      "cache": "redis",
      "version": "1.0"
    }
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: demo-app
type: Opaque
stringData:
  db-password: "super-secret-password"
  api-key: "abc123xyz"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: demo-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: demo-app
  labels:
    app: demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
      annotations:
        backup.velero.io/backup-volumes: data
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: data
          mountPath: /data
        - name: config
          mountPath: /etc/config
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: app-data
      - name: config
        configMap:
          name: app-config
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: demo-app
spec:
  ports:
  - port: 80
  selector:
    app: demo
```

```bash
# Deploy sample application
kubectl apply -f sample-app.yaml

# Add some data to the PV
kubectl exec -n demo-app deploy/demo-app -- sh -c "echo 'Important data $(date)' > /data/important.txt"
kubectl exec -n demo-app deploy/demo-app -- cat /data/important.txt
```

### Create Backup

```bash
# Create a backup of the demo-app namespace
velero backup create demo-backup \
  --include-namespaces demo-app \
  --wait

# Check backup status
velero backup describe demo-backup
velero backup logs demo-backup

# List all backups
velero backup get
```

### Simulate Disaster

```bash
# Delete the namespace (simulating disaster)
kubectl delete namespace demo-app

# Verify deletion
kubectl get namespace demo-app
# Should return: Error from server (NotFound)
```

### Restore from Backup

```bash
# Restore the backup
velero restore create demo-restore \
  --from-backup demo-backup \
  --wait

# Check restore status
velero restore describe demo-restore
velero restore logs demo-restore

# Verify restoration
kubectl get all -n demo-app
kubectl exec -n demo-app deploy/demo-app -- cat /data/important.txt
```

---

## Part 4: Advanced Backup Options

### Selective Backups

```bash
# Backup by labels
velero backup create label-backup \
  --selector app=demo \
  --wait

# Backup specific resources
velero backup create resources-backup \
  --include-resources deployments,services,configmaps \
  --include-namespaces demo-app \
  --wait

# Backup excluding specific resources
velero backup create exclude-backup \
  --include-namespaces demo-app \
  --exclude-resources pods,replicasets,events \
  --wait

# Backup multiple namespaces
velero backup create multi-ns-backup \
  --include-namespaces demo-app,production,staging \
  --wait

# Backup with custom TTL
velero backup create ttl-backup \
  --include-namespaces demo-app \
  --ttl 720h \  # 30 days
  --wait
```

### Backup Hooks

```yaml
# app-with-hooks.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: demo-app
  annotations:
    # Pre-backup hook: create consistent snapshot
    pre.hook.backup.velero.io/container: postgres
    pre.hook.backup.velero.io/command: '["/bin/bash", "-c", "pg_dump -U postgres -d mydb > /backup/dump.sql"]'
    pre.hook.backup.velero.io/timeout: 120s
    pre.hook.backup.velero.io/on-error: Fail
    
    # Post-backup hook: cleanup
    post.hook.backup.velero.io/container: postgres
    post.hook.backup.velero.io/command: '["/bin/bash", "-c", "rm -f /backup/dump.sql"]'
    post.hook.backup.velero.io/timeout: 30s
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
      annotations:
        backup.velero.io/backup-volumes: data,backup
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_PASSWORD
          value: "password"
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        - name: backup
          mountPath: /backup
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-data
      - name: backup
        emptyDir: {}
```

### Restore Hooks

```yaml
# restore-hooks-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: restore-hooks
  namespace: velero
  labels:
    velero.io/restore-hook: "true"
data:
  restore-hooks.yaml: |
    version: v1
    kind: RestoreHook
    metadata:
      name: postgres-restore-hook
    spec:
      resources:
        - name: postgres
          includedNamespaces:
            - demo-app
          labelSelector:
            matchLabels:
              app: postgres
          postHooks:
            - init:
                initContainers:
                  - name: restore-data
                    image: postgres:15
                    command:
                      - /bin/bash
                      - -c
                      - |
                        # Wait for postgres to be ready
                        until pg_isready -h localhost -U postgres; do
                          sleep 2
                        done
                        # Restore from dump if exists
                        if [ -f /backup/dump.sql ]; then
                          psql -U postgres -d mydb < /backup/dump.sql
                        fi
                    volumeMounts:
                      - name: backup
                        mountPath: /backup
```

---

## Part 5: Scheduled Backups

### Create Backup Schedules

```bash
# Create hourly backup schedule
velero schedule create hourly-backup \
  --schedule="0 * * * *" \
  --include-namespaces demo-app \
  --ttl 24h

# Create daily backup schedule with retention
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces production,staging \
  --ttl 168h \  # 7 days
  --default-volumes-to-fs-backup

# Create weekly backup schedule
velero schedule create weekly-backup \
  --schedule="0 3 * * 0" \
  --include-namespaces production \
  --ttl 720h \  # 30 days
  --snapshot-volumes

# List schedules
velero schedule get

# Describe schedule
velero schedule describe daily-backup

# Trigger schedule manually
velero backup create --from-schedule daily-backup
```

### Schedule Configuration via CRD

```yaml
# velero-schedules.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: production-hourly
  namespace: velero
spec:
  schedule: "0 * * * *"
  template:
    includedNamespaces:
      - production
    excludedResources:
      - events
      - events.events.k8s.io
    storageLocation: default
    volumeSnapshotLocations:
      - default
    ttl: 24h0m0s
    snapshotVolumes: true
    defaultVolumesToFsBackup: false
    hooks:
      resources:
        - name: database-hooks
          includedNamespaces:
            - production
          labelSelector:
            matchLabels:
              tier: database
          pre:
            - exec:
                container: database
                command:
                  - /bin/bash
                  - -c
                  - "pg_dump -U postgres > /backup/pre-backup.sql"
                onError: Fail
                timeout: 120s
---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: production-daily
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
      - production
    storageLocation: default
    ttl: 168h0m0s  # 7 days
    snapshotVolumes: true
---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: all-namespaces-weekly
  namespace: velero
spec:
  schedule: "0 3 * * 0"
  template:
    excludedNamespaces:
      - kube-system
      - velero
    storageLocation: default
    ttl: 720h0m0s  # 30 days
```

---

## Part 6: Cross-Cluster Migration

### Migration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  Cross-Cluster Migration                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Source Cluster                      Target Cluster              │
│  ┌─────────────────┐                 ┌─────────────────┐         │
│  │                 │                 │                 │         │
│  │  ┌───────────┐  │                 │  ┌───────────┐  │         │
│  │  │   App     │  │                 │  │   App     │  │         │
│  │  │  + Data   │  │                 │  │  + Data   │  │         │
│  │  └─────┬─────┘  │                 │  └─────▲─────┘  │         │
│  │        │        │                 │        │        │         │
│  │  ┌─────▼─────┐  │                 │  ┌─────┴─────┐  │         │
│  │  │  Velero   │  │                 │  │  Velero   │  │         │
│  │  │  Backup   │  │                 │  │  Restore  │  │         │
│  │  └─────┬─────┘  │                 │  └─────▲─────┘  │         │
│  │        │        │                 │        │        │         │
│  └────────┼────────┘                 └────────┼────────┘         │
│           │                                   │                   │
│           ▼                                   │                   │
│  ┌────────────────────────────────────────────┴────────────────┐ │
│  │                    Shared Object Storage                     │ │
│  │                    (S3 / GCS / MinIO)                        │ │
│  │                                                               │ │
│  │   ┌─────────────────────────────────────────────────────┐    │ │
│  │   │  backup-name/                                        │    │ │
│  │   │  ├── velero-backup.json                              │    │ │
│  │   │  ├── backup-resources/                               │    │ │
│  │   │  │   ├── namespaces.json                             │    │ │
│  │   │  │   ├── deployments.json                            │    │ │
│  │   │  │   └── ...                                         │    │ │
│  │   │  └── restic/                                         │    │ │
│  │   │      └── <volume-data>                               │    │ │
│  │   └─────────────────────────────────────────────────────┘    │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Configure Shared Storage

```bash
# On both clusters, configure the same backup location
# Source cluster (already configured)
velero backup-location get

# Target cluster - install Velero with same storage
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket velero-backups \
  --secret-file ./credentials-velero \
  --backup-location-config region=us-east-1,s3ForcePathStyle=true,s3Url=https://s3.amazonaws.com \
  --use-node-agent
```

### Migration Steps

```bash
# Step 1: On source cluster - create backup
velero backup create migration-backup \
  --include-namespaces production \
  --snapshot-volumes \
  --default-volumes-to-fs-backup \
  --wait

# Verify backup
velero backup describe migration-backup
velero backup logs migration-backup

# Step 2: On target cluster - verify backup is visible
velero backup get
# Should show migration-backup

# Step 3: On target cluster - restore with namespace mapping (optional)
velero restore create migration-restore \
  --from-backup migration-backup \
  --namespace-mappings "production:production-migrated" \
  --wait

# Or restore to same namespace
velero restore create migration-restore \
  --from-backup migration-backup \
  --wait

# Step 4: Verify restoration
kubectl get all -n production-migrated
```

### Handling StorageClass Differences

```yaml
# storageclass-mapping.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: change-storage-class-config
  namespace: velero
  labels:
    velero.io/plugin-config: ""
    velero.io/change-storage-class: RestoreItemAction
data:
  # Map source storage class to target storage class
  gp2: gp3
  standard: premium-rwo
  fast-ssd: fast-nvme
```

```bash
# Restore with storage class mapping
velero restore create migration-restore \
  --from-backup migration-backup \
  --restore-volumes \
  --wait
```

---

## Part 7: CSI Snapshots Integration

### Configure CSI Plugin

```bash
# Install CSI plugin
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0,velero/velero-plugin-for-csi:v0.7.0 \
  --features=EnableCSI \
  --bucket velero-backups \
  --secret-file ./credentials-velero \
  --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://minio.velero.svc:9000

# Verify CSI feature is enabled
velero client config get features
```

### VolumeSnapshotClass Configuration

```yaml
# volumesnapshotclass.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
  labels:
    velero.io/csi-volumesnapshot-class: "true"
driver: ebs.csi.aws.com
deletionPolicy: Retain
parameters:
  # Provider-specific parameters
```

### CSI Snapshot Backup

```bash
# Create backup with CSI snapshots
velero backup create csi-backup \
  --include-namespaces demo-app \
  --snapshot-volumes \
  --csi-snapshot-timeout 20m \
  --wait

# Check snapshot status
kubectl get volumesnapshots -n demo-app
kubectl get volumesnapshotcontents
```

---

## Part 8: Troubleshooting Velero

### Common Issues and Solutions

```bash
# Check Velero logs
kubectl logs -n velero deploy/velero -f

# Check node-agent logs
kubectl logs -n velero -l name=node-agent --all-containers

# Check backup/restore logs
velero backup logs <backup-name>
velero restore logs <restore-name>

# Debug backup issues
velero backup describe <backup-name> --details

# Check backup storage location
velero backup-location get
kubectl get backupstoragelocation -n velero -o yaml

# Verify storage connectivity
kubectl exec -n velero deploy/velero -- \
  /velero debug --backup-location default
```

### Backup Validation

```bash
# Validate backup contents
velero backup describe <backup-name> --details | grep -A 50 "Resource List"

# Check for partial failures
velero backup describe <backup-name> | grep -i "phase\|error\|warning"

# List items in backup
velero backup logs <backup-name> 2>&1 | grep "backed up"
```

### Performance Tuning

```yaml
# velero-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: velero-config
  namespace: velero
data:
  # Parallel upload/download settings
  uploader-type: "restic"
  
  # Resource limits
  default-volumes-to-fs-backup: "true"
  default-snapshot-move-data: "false"
  
  # Timeout settings
  resourceTimeout: "10m"
  itemOperationTimeout: "4h"
```

---

## 🎯 Practical Exercises

### Exercise 1: Full Backup and Restore Cycle

1. Deploy a multi-tier application (web + database)
2. Add data to the database
3. Create a full backup with hooks
4. Delete the application
5. Restore from backup
6. Verify data integrity

### Exercise 2: Scheduled Backup Implementation

1. Create hourly, daily, and weekly schedules
2. Configure different retention policies
3. Monitor backup completion
4. Set up alerting for failures
5. Verify retention enforcement

### Exercise 3: Cross-Cluster Migration

1. Set up two clusters with shared storage
2. Deploy application on source cluster
3. Create backup with all data
4. Restore on target cluster
5. Verify complete migration
6. Handle storage class differences

---

## 📚 Key Takeaways

### Velero Best Practices

| Practice | Recommendation |
|----------|----------------|
| **Storage** | Use S3-compatible storage with versioning |
| **Encryption** | Enable server-side encryption |
| **Retention** | Implement tiered retention policies |
| **Hooks** | Use pre/post hooks for consistency |
| **Testing** | Regular restore testing |
| **Monitoring** | Set up backup failure alerts |

### Backup Strategy Matrix

| Workload Type | Backup Method | Frequency | Retention |
|---------------|---------------|-----------|-----------|
| Stateless | Resource only | Daily | 7 days |
| Stateful (DB) | Snapshots + Hooks | Hourly | 30 days |
| Critical | Full + Snapshots | Every 15 min | 90 days |

---

## ✅ Lab Checklist

Before completing this lab, verify:

- [ ] Velero installed and configured
- [ ] Backup storage location working
- [ ] Can create and restore backups
- [ ] Scheduled backups configured
- [ ] Backup hooks implemented
- [ ] Cross-cluster restore tested
- [ ] CSI snapshots working (if applicable)
- [ ] Troubleshooting commands understood

---

## Next Steps

Continue to [Lab 3: Disaster Recovery Planning →](../lab-03-disaster-recovery/README.md)
