# Lab 1: Backup Strategies and Fundamentals

## 🎯 Objectives

By the end of this lab, you will:
- Understand Kubernetes backup fundamentals
- Perform etcd backup and restore operations
- Implement application-consistent backups
- Design backup automation strategies
- Create backup verification procedures

## ⏱️ Estimated Time: 90 minutes

---

## Part 1: Understanding Kubernetes Backup Scope

### What Needs to Be Backed Up

```
┌─────────────────────────────────────────────────────────────────┐
│                  Kubernetes Backup Layers                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Layer 1: Cluster State (etcd)                                    │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  • All API objects (Deployments, Services, etc.)            │ │
│  │  • Secrets and ConfigMaps                                    │ │
│  │  • RBAC (Roles, RoleBindings)                                │ │
│  │  • CRDs and Custom Resources                                 │ │
│  │  • Namespaces and quotas                                     │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Layer 2: Persistent Data                                         │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  • PersistentVolumes (actual data)                           │ │
│  │  • Database contents                                         │ │
│  │  • File storage                                              │ │
│  │  • Message queues                                            │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Layer 3: External Dependencies                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  • External databases                                        │ │
│  │  • Cloud services configuration                              │ │
│  │  • DNS records                                               │ │
│  │  • SSL/TLS certificates                                      │ │
│  │  • Identity provider configs                                 │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Layer 4: Infrastructure as Code                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  • Terraform state                                           │ │
│  │  • Helm values                                               │ │
│  │  • GitOps repositories                                       │ │
│  │  • CI/CD pipelines                                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Backup Strategy Decision Matrix

| Data Type | Method | Frequency | Retention |
|-----------|--------|-----------|-----------|
| etcd | Snapshot | Hourly | 7 days |
| PV (databases) | Volume snapshot | Hourly | 30 days |
| PV (files) | Incremental backup | Daily | 90 days |
| Secrets | Encrypted export | Daily | 30 days |
| Git repos | Native git backup | Continuous | Indefinite |
| IaC state | Versioned storage | Per change | 90 days |

---

## Part 2: etcd Backup and Restore

### Understanding etcd

etcd is the brain of Kubernetes - it stores all cluster state.

```
┌─────────────────────────────────────────────────────────────────┐
│                     etcd in Kubernetes                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│                    ┌──────────────┐                              │
│                    │  API Server  │                              │
│                    └──────┬───────┘                              │
│                           │                                       │
│              Read/Write Operations                                │
│                           │                                       │
│                           ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                        etcd                                 │  │
│  │  ┌─────────────┬─────────────┬─────────────────────────┐   │  │
│  │  │   /pods     │  /services  │  /deployments           │   │  │
│  │  │   /nodes    │  /secrets   │  /configmaps            │   │  │
│  │  │   /rbac     │  /crds      │  /namespaces            │   │  │
│  │  └─────────────┴─────────────┴─────────────────────────┘   │  │
│  │                                                             │  │
│  │  • Distributed key-value store                             │  │
│  │  • Raft consensus protocol                                  │  │
│  │  • Typically 3-5 node cluster                               │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### etcd Backup Methods

#### Method 1: etcdctl Snapshot

```bash
# For Kind or kubeadm clusters with etcd access
# Find etcd pod
kubectl get pods -n kube-system -l component=etcd

# Get etcd endpoint and certs
ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')

# Check etcd cluster health
kubectl exec -n kube-system $ETCD_POD -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

# Create snapshot
kubectl exec -n kube-system $ETCD_POD -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-snapshot.db

# Copy snapshot out of pod
kubectl cp kube-system/$ETCD_POD:/tmp/etcd-snapshot.db ./etcd-snapshot-$(date +%Y%m%d-%H%M%S).db
```

#### Method 2: Direct etcdctl (On Control Plane Node)

```bash
# SSH to control plane node
ssh control-plane-node

# Set environment variables
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS="https://127.0.0.1:2379"
export ETCDCTL_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
export ETCDCTL_CERT="/etc/kubernetes/pki/etcd/server.crt"
export ETCDCTL_KEY="/etc/kubernetes/pki/etcd/server.key"

# Verify cluster status
etcdctl endpoint status --write-out=table

# Create snapshot
BACKUP_DIR="/var/backup/etcd"
mkdir -p $BACKUP_DIR
etcdctl snapshot save $BACKUP_DIR/snapshot-$(date +%Y%m%d-%H%M%S).db

# Verify snapshot
etcdctl snapshot status $BACKUP_DIR/snapshot-*.db --write-out=table
```

### etcd Restore Process

```bash
# ⚠️ WARNING: This is a destructive operation
# Only perform on a cluster you can afford to lose

# Stop kube-apiserver (on all control plane nodes)
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

# Stop etcd
sudo mv /etc/kubernetes/manifests/etcd.yaml /tmp/

# Wait for pods to stop
sleep 30

# Backup existing etcd data
sudo mv /var/lib/etcd /var/lib/etcd.backup.$(date +%Y%m%d-%H%M%S)

# Restore from snapshot
sudo etcdctl snapshot restore /path/to/snapshot.db \
  --data-dir=/var/lib/etcd \
  --name=control-plane \
  --initial-cluster=control-plane=https://127.0.0.1:2380 \
  --initial-advertise-peer-urls=https://127.0.0.1:2380

# Set correct ownership
sudo chown -R etcd:etcd /var/lib/etcd

# Restore etcd and API server manifests
sudo mv /tmp/etcd.yaml /etc/kubernetes/manifests/
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

# Wait for cluster to recover
sleep 60
kubectl get nodes
```

### Automated etcd Backup Script

```bash
#!/bin/bash
# etcd-backup.sh - Automated etcd backup script

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backup/etcd}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
S3_BUCKET="${S3_BUCKET:-}"
ETCD_ENDPOINTS="${ETCD_ENDPOINTS:-https://127.0.0.1:2379}"
ETCD_CACERT="${ETCD_CACERT:-/etc/kubernetes/pki/etcd/ca.crt}"
ETCD_CERT="${ETCD_CERT:-/etc/kubernetes/pki/etcd/server.crt}"
ETCD_KEY="${ETCD_KEY:-/etc/kubernetes/pki/etcd/server.key}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Generate backup filename
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/etcd-snapshot-$TIMESTAMP.db"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check etcd health
log "Checking etcd cluster health..."
ETCDCTL_API=3 etcdctl \
    --endpoints="$ETCD_ENDPOINTS" \
    --cacert="$ETCD_CACERT" \
    --cert="$ETCD_CERT" \
    --key="$ETCD_KEY" \
    endpoint health

# Create snapshot
log "Creating etcd snapshot..."
ETCDCTL_API=3 etcdctl \
    --endpoints="$ETCD_ENDPOINTS" \
    --cacert="$ETCD_CACERT" \
    --cert="$ETCD_CERT" \
    --key="$ETCD_KEY" \
    snapshot save "$BACKUP_FILE"

# Verify snapshot
log "Verifying snapshot..."
ETCDCTL_API=3 etcdctl snapshot status "$BACKUP_FILE" --write-out=table

# Compress backup
log "Compressing backup..."
gzip "$BACKUP_FILE"
BACKUP_FILE="${BACKUP_FILE}.gz"

# Calculate checksum
CHECKSUM=$(sha256sum "$BACKUP_FILE" | awk '{print $1}')
echo "$CHECKSUM" > "${BACKUP_FILE}.sha256"

# Upload to S3 if configured
if [ -n "$S3_BUCKET" ]; then
    log "Uploading to S3..."
    aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/etcd/"
    aws s3 cp "${BACKUP_FILE}.sha256" "s3://$S3_BUCKET/etcd/"
fi

# Cleanup old backups
log "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "etcd-snapshot-*.db.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "etcd-snapshot-*.sha256" -mtime +$RETENTION_DAYS -delete

# Cleanup old S3 backups
if [ -n "$S3_BUCKET" ]; then
    # Use S3 lifecycle policies instead for production
    aws s3 ls "s3://$S3_BUCKET/etcd/" | while read -r line; do
        FILE_DATE=$(echo "$line" | awk '{print $1}')
        FILE_NAME=$(echo "$line" | awk '{print $4}')
        if [ -n "$FILE_DATE" ]; then
            FILE_AGE=$(( ($(date +%s) - $(date -d "$FILE_DATE" +%s)) / 86400 ))
            if [ "$FILE_AGE" -gt "$RETENTION_DAYS" ]; then
                aws s3 rm "s3://$S3_BUCKET/etcd/$FILE_NAME"
            fi
        fi
    done
fi

log "Backup completed successfully: $BACKUP_FILE"
log "Checksum: $CHECKSUM"
```

### etcd Backup CronJob for Kubernetes

```yaml
# etcd-backup-cronjob.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: etcd-backup
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: etcd-backup
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec"]
  verbs: ["get", "list", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: etcd-backup
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: etcd-backup
subjects:
- kind: ServiceAccount
  name: etcd-backup
  namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: etcd-backup-script
  namespace: kube-system
data:
  backup.sh: |
    #!/bin/bash
    set -e
    
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE="/backup/etcd-snapshot-$TIMESTAMP.db"
    
    # Create backup
    etcdctl snapshot save "$BACKUP_FILE" \
      --endpoints=https://127.0.0.1:2379 \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/server.crt \
      --key=/etc/kubernetes/pki/etcd/server.key
    
    # Verify
    etcdctl snapshot status "$BACKUP_FILE"
    
    # Compress and upload to S3
    gzip "$BACKUP_FILE"
    aws s3 cp "${BACKUP_FILE}.gz" "s3://${S3_BUCKET}/etcd/"
    
    echo "Backup completed: ${BACKUP_FILE}.gz"
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
spec:
  schedule: "0 */4 * * *"  # Every 4 hours
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: etcd-backup
          hostNetwork: true
          nodeSelector:
            node-role.kubernetes.io/control-plane: ""
          tolerations:
          - key: node-role.kubernetes.io/control-plane
            operator: Exists
            effect: NoSchedule
          containers:
          - name: etcd-backup
            image: bitnami/etcd:3.5
            command: ["/bin/bash", "/scripts/backup.sh"]
            env:
            - name: ETCDCTL_API
              value: "3"
            - name: S3_BUCKET
              valueFrom:
                secretKeyRef:
                  name: etcd-backup-config
                  key: s3-bucket
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: etcd-backup-config
                  key: aws-access-key-id
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: etcd-backup-config
                  key: aws-secret-access-key
            volumeMounts:
            - name: etcd-certs
              mountPath: /etc/kubernetes/pki/etcd
              readOnly: true
            - name: backup-script
              mountPath: /scripts
            - name: backup-storage
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: etcd-certs
            hostPath:
              path: /etc/kubernetes/pki/etcd
          - name: backup-script
            configMap:
              name: etcd-backup-script
              defaultMode: 0755
          - name: backup-storage
            emptyDir: {}
```

---

## Part 3: Application-Consistent Backups

### The Challenge of Consistency

```
┌─────────────────────────────────────────────────────────────────┐
│                  Backup Consistency Levels                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Crash-Consistent                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  • Point-in-time snapshot of storage                        │ │
│  │  • Like pulling the power plug                               │ │
│  │  • May require recovery/replay on restore                    │ │
│  │  • Suitable for: Databases with WAL/journaling              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Application-Consistent                                           │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  • Application paused or quiesced                            │ │
│  │  • Buffers flushed to disk                                   │ │
│  │  • No in-flight transactions                                 │ │
│  │  • Suitable for: Clean restore without recovery              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Transactionally-Consistent                                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  • All related data captured together                        │ │
│  │  • Across multiple volumes/databases                         │ │
│  │  • Preserves referential integrity                           │ │
│  │  • Suitable for: Distributed systems                         │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Pre/Post Backup Hooks

```yaml
# backup-hooks-example.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-with-hooks
  annotations:
    # Velero backup hooks
    backup.velero.io/backup-volumes: data
    pre.hook.backup.velero.io/command: '["/bin/bash", "-c", "pg_dump -U postgres mydb > /backup/pre-backup.sql && sync"]'
    pre.hook.backup.velero.io/container: postgres
    pre.hook.backup.velero.io/timeout: 120s
    post.hook.backup.velero.io/command: '["/bin/bash", "-c", "rm -f /backup/pre-backup.sql"]'
    post.hook.backup.velero.io/container: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
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

### Database-Specific Backup Strategies

#### PostgreSQL

```yaml
# postgres-backup-job.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15
            command:
            - /bin/bash
            - -c
            - |
              set -e
              TIMESTAMP=$(date +%Y%m%d-%H%M%S)
              BACKUP_FILE="/backup/postgres-${TIMESTAMP}.sql.gz"
              
              # Create backup
              pg_dumpall -h postgres-service -U postgres | gzip > "$BACKUP_FILE"
              
              # Verify backup size
              SIZE=$(stat -c%s "$BACKUP_FILE")
              if [ "$SIZE" -lt 1000 ]; then
                echo "Backup file too small, possible failure"
                exit 1
              fi
              
              # Upload to S3
              aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/postgres/"
              
              echo "Backup completed: $BACKUP_FILE"
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            - name: S3_BUCKET
              value: "company-backups"
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup-storage
            emptyDir:
              sizeLimit: 10Gi
```

#### MySQL/MariaDB

```yaml
# mysql-backup-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-backup-script
data:
  backup.sh: |
    #!/bin/bash
    set -euo pipefail
    
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_DIR="/backup"
    
    # Lock tables and flush
    mysql -h mysql-service -u root -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH TABLES WITH READ LOCK;"
    
    # Get binary log position for point-in-time recovery
    mysql -h mysql-service -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW MASTER STATUS\G" > "${BACKUP_DIR}/binlog-position-${TIMESTAMP}.txt"
    
    # Create backup
    mysqldump -h mysql-service -u root -p"${MYSQL_ROOT_PASSWORD}" \
      --all-databases \
      --single-transaction \
      --routines \
      --triggers \
      --events \
      --flush-logs \
      | gzip > "${BACKUP_DIR}/mysql-${TIMESTAMP}.sql.gz"
    
    # Unlock tables
    mysql -h mysql-service -u root -p"${MYSQL_ROOT_PASSWORD}" -e "UNLOCK TABLES;"
    
    # Upload to storage
    aws s3 cp "${BACKUP_DIR}/mysql-${TIMESTAMP}.sql.gz" "s3://${S3_BUCKET}/mysql/"
    aws s3 cp "${BACKUP_DIR}/binlog-position-${TIMESTAMP}.txt" "s3://${S3_BUCKET}/mysql/"
    
    echo "Backup completed successfully"
```

#### MongoDB

```yaml
# mongodb-backup-job.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mongodb-backup
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: mongo:6
            command:
            - /bin/bash
            - -c
            - |
              set -e
              TIMESTAMP=$(date +%Y%m%d-%H%M%S)
              BACKUP_DIR="/backup/mongodb-${TIMESTAMP}"
              
              # Create backup with oplog for point-in-time recovery
              mongodump \
                --uri="mongodb://root:${MONGO_ROOT_PASSWORD}@mongodb-service:27017" \
                --oplog \
                --out="$BACKUP_DIR"
              
              # Compress
              cd /backup
              tar -czf "mongodb-${TIMESTAMP}.tar.gz" "mongodb-${TIMESTAMP}"
              rm -rf "mongodb-${TIMESTAMP}"
              
              # Upload
              aws s3 cp "mongodb-${TIMESTAMP}.tar.gz" "s3://${S3_BUCKET}/mongodb/"
              
              echo "Backup completed: mongodb-${TIMESTAMP}.tar.gz"
            env:
            - name: MONGO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: password
            - name: S3_BUCKET
              value: "company-backups"
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup-storage
            emptyDir:
              sizeLimit: 20Gi
```

---

## Part 4: Volume Snapshots

### CSI Volume Snapshots

```yaml
# volumesnapshotclass.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
  annotations:
    snapshot.storage.kubernetes.io/is-default-class: "true"
driver: ebs.csi.aws.com  # or appropriate CSI driver
deletionPolicy: Retain
parameters:
  # Driver-specific parameters
---
# volumesnapshot.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgres-data-snapshot
  namespace: production
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: postgres-data
```

### Automated Snapshot Controller

```yaml
# snapshot-controller.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: snapshot-controller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: snapshot-controller
rules:
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots", "volumesnapshotcontents", "volumesnapshotclasses"]
  verbs: ["get", "list", "watch", "create", "delete"]
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: snapshot-scheduler-config
  namespace: kube-system
data:
  config.yaml: |
    schedules:
      - name: hourly
        schedule: "0 * * * *"
        retention:
          count: 24
        selector:
          matchLabels:
            backup-policy: hourly
      
      - name: daily
        schedule: "0 2 * * *"
        retention:
          count: 7
        selector:
          matchLabels:
            backup-policy: daily
      
      - name: weekly
        schedule: "0 3 * * 0"
        retention:
          count: 4
        selector:
          matchLabels:
            backup-policy: weekly
```

### PVC with Backup Labels

```yaml
# pvc-with-backup-policy.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: critical-database-data
  namespace: production
  labels:
    backup-policy: hourly
    app: critical-database
    tier: data
  annotations:
    backup.kubernetes.io/pre-hook: "/scripts/freeze.sh"
    backup.kubernetes.io/post-hook: "/scripts/thaw.sh"
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: fast-ssd
```

---

## Part 5: Backup Verification

### Restore Testing Pipeline

```yaml
# backup-verification-job.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-verification
  namespace: backup-system
spec:
  schedule: "0 6 * * 1"  # Weekly on Monday at 6 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: verification
            image: backup-verification:latest
            command:
            - /bin/bash
            - -c
            - |
              set -e
              
              echo "=== Backup Verification Started ==="
              
              # 1. List available backups
              echo "Checking available backups..."
              LATEST_BACKUP=$(aws s3 ls s3://${S3_BUCKET}/etcd/ | sort | tail -1 | awk '{print $4}')
              echo "Latest backup: $LATEST_BACKUP"
              
              # 2. Download and verify checksum
              echo "Downloading backup..."
              aws s3 cp "s3://${S3_BUCKET}/etcd/$LATEST_BACKUP" /tmp/
              aws s3 cp "s3://${S3_BUCKET}/etcd/${LATEST_BACKUP%.gz}.sha256" /tmp/ || true
              
              if [ -f "/tmp/${LATEST_BACKUP%.gz}.sha256" ]; then
                echo "Verifying checksum..."
                cd /tmp && sha256sum -c "${LATEST_BACKUP%.gz}.sha256"
              fi
              
              # 3. Decompress and validate
              echo "Decompressing..."
              gunzip -k "/tmp/$LATEST_BACKUP"
              BACKUP_FILE="${LATEST_BACKUP%.gz}"
              
              # 4. Validate etcd snapshot
              echo "Validating snapshot..."
              etcdctl snapshot status "/tmp/$BACKUP_FILE" --write-out=table
              
              # 5. Test restore (to temporary location)
              echo "Testing restore..."
              TEMP_DIR=$(mktemp -d)
              etcdctl snapshot restore "/tmp/$BACKUP_FILE" \
                --data-dir="$TEMP_DIR/etcd-data" \
                --name=test-restore \
                --initial-cluster=test-restore=http://localhost:2380 \
                --initial-advertise-peer-urls=http://localhost:2380
              
              # 6. Verify restored data
              echo "Verifying restored data..."
              # Start temporary etcd and verify
              etcd --data-dir="$TEMP_DIR/etcd-data" \
                --listen-client-urls=http://localhost:12379 \
                --advertise-client-urls=http://localhost:12379 &
              ETCD_PID=$!
              sleep 5
              
              # Count keys
              KEY_COUNT=$(etcdctl --endpoints=http://localhost:12379 get "" --prefix --keys-only | wc -l)
              echo "Restored key count: $KEY_COUNT"
              
              # Cleanup
              kill $ETCD_PID 2>/dev/null || true
              rm -rf "$TEMP_DIR"
              
              # 7. Report results
              echo "=== Verification Complete ==="
              echo "Backup: $LATEST_BACKUP"
              echo "Status: SUCCESS"
              echo "Keys: $KEY_COUNT"
              
              # Send notification
              curl -X POST "$SLACK_WEBHOOK" \
                -H "Content-Type: application/json" \
                -d "{\"text\":\"✅ Backup verification successful\nBackup: $LATEST_BACKUP\nKeys: $KEY_COUNT\"}"
            env:
            - name: S3_BUCKET
              value: "company-backups"
            - name: SLACK_WEBHOOK
              valueFrom:
                secretKeyRef:
                  name: backup-config
                  key: slack-webhook
          restartPolicy: OnFailure
```

### Restore Drill Documentation

```yaml
# restore-drill-template.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: restore-drill-runbook
  namespace: backup-system
data:
  runbook.md: |
    # Restore Drill Runbook
    
    ## Pre-Drill Checklist
    - [ ] Schedule drill with stakeholders
    - [ ] Notify on-call team
    - [ ] Prepare isolated test environment
    - [ ] Identify backup to test
    - [ ] Prepare rollback plan
    
    ## Drill Procedure
    
    ### 1. Environment Preparation (15 min)
    ```bash
    # Create test namespace
    kubectl create namespace restore-drill
    
    # Apply resource quotas
    kubectl apply -f restore-drill-quotas.yaml
    ```
    
    ### 2. Backup Identification (5 min)
    ```bash
    # List available backups
    velero backup get
    
    # Select backup for testing
    BACKUP_NAME="daily-backup-20240201-020000"
    
    # Describe backup contents
    velero backup describe $BACKUP_NAME --details
    ```
    
    ### 3. Restore Execution (30 min)
    ```bash
    # Perform restore to test namespace
    velero restore create drill-restore-$(date +%s) \
      --from-backup $BACKUP_NAME \
      --namespace-mappings "production:restore-drill"
    
    # Monitor restore progress
    velero restore get
    velero restore describe drill-restore-* --details
    ```
    
    ### 4. Validation (30 min)
    - [ ] All pods running
    - [ ] Services accessible
    - [ ] Data integrity verified
    - [ ] Application functionality tested
    
    ```bash
    # Check pod status
    kubectl get pods -n restore-drill
    
    # Run validation tests
    kubectl apply -f validation-job.yaml -n restore-drill
    ```
    
    ### 5. Cleanup (10 min)
    ```bash
    kubectl delete namespace restore-drill
    velero restore delete drill-restore-*
    ```
    
    ## Post-Drill Report
    
    | Metric | Target | Actual |
    |--------|--------|--------|
    | RTO | 1 hour | ___ |
    | Data Loss | 0 | ___ |
    | Success Rate | 100% | ___ |
    
    ## Issues Found
    
    1. 
    2.
    
    ## Action Items
    
    1. 
    2.
```

---

## Part 6: Backup Monitoring and Alerting

### Prometheus Metrics for Backup

```yaml
# backup-metrics-exporter.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backup-metrics-exporter
  namespace: backup-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backup-metrics
  template:
    metadata:
      labels:
        app: backup-metrics
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      containers:
      - name: exporter
        image: python:3.11-slim
        command: ["python", "/app/exporter.py"]
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: exporter-code
          mountPath: /app
      volumes:
      - name: exporter-code
        configMap:
          name: backup-exporter-code
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-exporter-code
  namespace: backup-system
data:
  exporter.py: |
    from prometheus_client import start_http_server, Gauge, Counter
    import subprocess
    import json
    import time
    from datetime import datetime, timedelta
    
    # Metrics
    backup_last_success = Gauge(
        'backup_last_success_timestamp',
        'Timestamp of last successful backup',
        ['backup_type', 'target']
    )
    
    backup_size_bytes = Gauge(
        'backup_size_bytes',
        'Size of last backup in bytes',
        ['backup_type', 'target']
    )
    
    backup_duration_seconds = Gauge(
        'backup_duration_seconds',
        'Duration of last backup',
        ['backup_type', 'target']
    )
    
    backup_count = Counter(
        'backup_total',
        'Total number of backups',
        ['backup_type', 'target', 'status']
    )
    
    backup_age_hours = Gauge(
        'backup_age_hours',
        'Age of newest backup in hours',
        ['backup_type', 'target']
    )
    
    def collect_velero_metrics():
        try:
            result = subprocess.run(
                ['velero', 'backup', 'get', '-o', 'json'],
                capture_output=True, text=True
            )
            backups = json.loads(result.stdout)
            
            for backup in backups.get('items', []):
                name = backup['metadata']['name']
                status = backup['status']['phase']
                
                if status == 'Completed':
                    completion_time = backup['status'].get('completionTimestamp')
                    if completion_time:
                        ts = datetime.fromisoformat(completion_time.replace('Z', '+00:00'))
                        backup_last_success.labels(
                            backup_type='velero',
                            target=name.split('-')[0]
                        ).set(ts.timestamp())
                        
                        age = (datetime.now(ts.tzinfo) - ts).total_seconds() / 3600
                        backup_age_hours.labels(
                            backup_type='velero',
                            target=name.split('-')[0]
                        ).set(age)
        except Exception as e:
            print(f"Error collecting Velero metrics: {e}")
    
    def main():
        start_http_server(9090)
        while True:
            collect_velero_metrics()
            time.sleep(60)
    
    if __name__ == '__main__':
        main()
```

### Alerting Rules

```yaml
# backup-alerting-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: backup-alerts
  namespace: monitoring
spec:
  groups:
  - name: backup-health
    rules:
    - alert: BackupMissing
      expr: |
        time() - backup_last_success_timestamp{backup_type="velero"} > 86400
      for: 1h
      labels:
        severity: critical
      annotations:
        summary: "Backup missing for {{ $labels.target }}"
        description: "No successful backup in the last 24 hours for {{ $labels.target }}"
    
    - alert: BackupAgeTooOld
      expr: backup_age_hours > 25
      for: 30m
      labels:
        severity: warning
      annotations:
        summary: "Backup too old for {{ $labels.target }}"
        description: "Newest backup is {{ $value }} hours old"
    
    - alert: BackupFailed
      expr: increase(backup_total{status="Failed"}[1h]) > 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "Backup failed for {{ $labels.target }}"
        description: "Backup job failed in the last hour"
    
    - alert: BackupStorageLow
      expr: |
        (s3_bucket_size_bytes{bucket="company-backups"} / s3_bucket_quota_bytes{bucket="company-backups"}) > 0.85
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "Backup storage running low"
        description: "Backup storage is {{ $value | humanizePercentage }} full"
  
  - name: etcd-backup
    rules:
    - alert: EtcdBackupMissing
      expr: |
        time() - backup_last_success_timestamp{backup_type="etcd"} > 14400
      for: 30m
      labels:
        severity: critical
      annotations:
        summary: "etcd backup missing"
        description: "No successful etcd backup in the last 4 hours"
    
    - alert: EtcdBackupSizeDrop
      expr: |
        backup_size_bytes{backup_type="etcd"} < (backup_size_bytes{backup_type="etcd"} offset 1d) * 0.5
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "etcd backup size dropped significantly"
        description: "Current backup is less than 50% of yesterday's size"
```

---

## 🎯 Practical Exercises

### Exercise 1: etcd Backup and Restore

1. Create a Kind cluster with accessible etcd
2. Deploy sample applications
3. Create etcd snapshot
4. Make changes to the cluster
5. Restore from snapshot
6. Verify restoration

### Exercise 2: Database Backup Implementation

1. Deploy PostgreSQL with persistent storage
2. Create sample database with data
3. Implement backup CronJob
4. Simulate data loss
5. Restore from backup
6. Verify data integrity

### Exercise 3: Backup Monitoring Setup

1. Deploy backup metrics exporter
2. Configure Prometheus scraping
3. Create Grafana dashboard for backup status
4. Set up alerting for backup failures
5. Test alert routing

---

## 📚 Key Takeaways

### Backup Strategy Checklist

| Item | Implemented | Tested |
|------|-------------|--------|
| etcd backup | [ ] | [ ] |
| PV snapshots | [ ] | [ ] |
| Database dumps | [ ] | [ ] |
| Application configs | [ ] | [ ] |
| Secrets (encrypted) | [ ] | [ ] |
| Monitoring | [ ] | [ ] |
| Alerting | [ ] | [ ] |
| Runbooks | [ ] | [ ] |

### Best Practices Summary

1. **3-2-1 Rule**: 3 copies, 2 different media, 1 offsite
2. **Test restores regularly** - untested backups aren't backups
3. **Encrypt sensitive data** in backups
4. **Monitor backup health** with alerting
5. **Document procedures** with runbooks
6. **Automate everything** possible

---

## ✅ Lab Checklist

Before completing this lab, verify:

- [ ] Understand Kubernetes backup scope
- [ ] Can perform etcd backup
- [ ] Can restore from etcd snapshot
- [ ] Implemented database backup strategy
- [ ] Created volume snapshots
- [ ] Set up backup verification
- [ ] Configured monitoring and alerting
- [ ] Documented restore procedures

---

## Next Steps

Continue to [Lab 2: Velero Deep Dive →](../lab-02-velero/README.md)
