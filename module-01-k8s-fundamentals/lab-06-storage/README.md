# Lab 6: Storage & Persistence

## Objective

Master Kubernetes storage concepts. Learn to work with Volumes, PersistentVolumes (PV), PersistentVolumeClaims (PVC), and StorageClasses for stateful applications.

## What You'll Learn

- Understand Kubernetes storage architecture
- Use emptyDir and hostPath volumes
- Create and manage PersistentVolumes (PV)
- Request storage with PersistentVolumeClaims (PVC)
- Implement dynamic provisioning with StorageClasses
- Configure access modes and reclaim policies
- Work with StatefulSets for stateful apps
- Backup and restore data

## Prerequisites

- Completed Labs 1-5
- kind cluster running
- Understanding of Pods and Deployments

## Lab Steps

### Step 1: Setup Environment

```bash
kubectl create namespace lab-06
kubectl config set-context --current --namespace=lab-06
```

### Step 2: emptyDir Volumes (Temporary Storage)

emptyDir is created when a Pod is assigned to a node and exists while the Pod runs on that node.

1. **Basic emptyDir usage**:

Save as `pod-emptydir.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-demo
spec:
  containers:

  - name: writer
    image: busybox:1.36
    command:

    - sh
    - -c
    - |
      while true; do
        echo "$(date): Writing data" >> /data/log.txt
        sleep 5
      done
    volumeMounts:

    - name: shared-data
      mountPath: /data
  
  - name: reader
    image: busybox:1.36
    command:

    - sh
    - -c
    - |
      while true; do
        echo "=== Latest logs ==="
        tail -n 5 /data/log.txt 2>/dev/null || echo "Waiting for data..."
        sleep 10
      done
    volumeMounts:

    - name: shared-data
      mountPath: /data
  
  volumes:

  - name: shared-data
    emptyDir: {}
```

Apply and observe:
```bash
kubectl apply -f pod-emptydir.yaml
kubectl logs emptydir-demo -c writer
kubectl logs emptydir-demo -c reader
```

2. **emptyDir with size limit**:

Save as `pod-emptydir-limit.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-limited
spec:
  containers:

  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'data' > /data/file.txt && sleep 3600"]
    volumeMounts:

    - name: cache
      mountPath: /data
  volumes:

  - name: cache
    emptyDir:
      sizeLimit: 100Mi
```

Apply:
```bash
kubectl apply -f pod-emptydir-limit.yaml
```

3. **emptyDir in memory (tmpfs)**:

Save as `pod-emptydir-memory.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-memory
spec:
  containers:

  - name: app
    image: nginx:1.25
    volumeMounts:

    - name: cache
      mountPath: /cache
  volumes:

  - name: cache
    emptyDir:
      medium: Memory  # Uses tmpfs (RAM)
      sizeLimit: 128Mi
```

Apply:
```bash
kubectl apply -f pod-emptydir-memory.yaml
kubectl exec emptydir-memory -- df -h /cache
```

**Note**: Data in emptyDir is lost when Pod is deleted!

### Step 3: hostPath Volumes (Node Storage)

hostPath mounts a file or directory from the host node into the Pod.

1. **Basic hostPath usage**:

Save as `pod-hostpath.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-demo
spec:
  containers:

  - name: app
    image: busybox:1.36
    command:

    - sh
    - -c
    - |
      echo "Writing to host: $(date)" >> /host-data/app.log
      cat /host-data/app.log
      sleep 3600
    volumeMounts:

    - name: host-volume
      mountPath: /host-data
  volumes:

  - name: host-volume
    hostPath:
      path: /tmp/kind-data
      type: DirectoryOrCreate
```

Apply:
```bash
kubectl apply -f pod-hostpath.yaml
kubectl logs hostpath-demo
```

2. **hostPath types**:

Save as `pod-hostpath-types.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-types
spec:
  containers:

  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:

    - name: host-dir
      mountPath: /host-dir
    - name: host-file
      mountPath: /host-file
  volumes:

  - name: host-dir
    hostPath:
      path: /tmp
      type: Directory  # Must exist
  - name: host-file
    hostPath:
      path: /etc/hostname
      type: File  # Must exist and be a file
```

**hostPath types**:

- `DirectoryOrCreate`: Creates if doesn't exist
- `Directory`: Must exist as directory
- `FileOrCreate`: Creates file if doesn't exist
- `File`: Must exist as file
- `Socket`: Unix socket
- `CharDevice`: Character device
- `BlockDevice`: Block device

**Warning**: hostPath is NOT recommended for production (node-specific, security risk).

### Step 4: PersistentVolumes (PV) - Manual Provisioning

PersistentVolumes are cluster resources that abstract storage details.

1. **Create a PersistentVolume**:

Save as `pv-manual.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-manual
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:

    - ReadWriteOnce  # RWO: single node read-write
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/data
    type: DirectoryOrCreate
```

Apply and verify:
```bash
kubectl apply -f pv-manual.yaml
kubectl get pv
kubectl describe pv pv-manual
```

Status will be `Available`.

**Access Modes**:

- `ReadWriteOnce` (RWO): Single node read-write
- `ReadOnlyMany` (ROX): Multiple nodes read-only
- `ReadWriteMany` (RWX): Multiple nodes read-write
- `ReadWriteOncePod` (RWOP): Single pod read-write

**Reclaim Policies**:

- `Retain`: Manual reclamation (data preserved)
- `Delete`: Delete volume when PVC deleted
- `Recycle`: Scrub data (deprecated)

### Step 5: PersistentVolumeClaims (PVC)

PVCs request storage resources from PVs.

1. **Create a PVC**:

Save as `pvc-manual.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-manual
spec:
  storageClassName: manual
  accessModes:

    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi  # Requesting 500Mi from 1Gi PV
```

Apply and verify:
```bash
kubectl apply -f pvc-manual.yaml
kubectl get pvc
kubectl describe pvc pvc-manual
```

Status changes from `Pending` → `Bound`.

Check PV status:
```bash
kubectl get pv pv-manual
```

Status changed from `Available` → `Bound`.

2. **Use PVC in a Pod**:

Save as `pod-with-pvc.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-storage
spec:
  containers:

  - name: app
    image: nginx:1.25
    volumeMounts:

    - name: persistent-storage
      mountPath: /usr/share/nginx/html
  volumes:

  - name: persistent-storage
    persistentVolumeClaim:
      claimName: pvc-manual
```

Apply:
```bash
kubectl apply -f pod-with-pvc.yaml
```

3. **Write data to persistent storage**:
```bash
kubectl exec pod-with-storage -- sh -c "echo '<h1>Persistent Data!</h1>' > /usr/share/nginx/html/index.html"

# Test

kubectl exec pod-with-storage -- cat /usr/share/nginx/html/index.html
```

4. **Verify persistence**:
```bash
# Delete the pod

kubectl delete pod pod-with-storage

# Recreate it

kubectl apply -f pod-with-pvc.yaml

# Data still there!

kubectl exec pod-with-storage -- cat /usr/share/nginx/html/index.html
```

### Step 6: StorageClass (Dynamic Provisioning)

StorageClasses enable dynamic PV provisioning.

1. **Check existing StorageClasses**:
```bash
kubectl get storageclass
# or

kubectl get sc
```

In kind, you should see `standard` (provided by Rancher local-path-provisioner).

2. **Describe the StorageClass**:
```bash
kubectl describe sc standard
```

Note:

- **Provisioner**: rancher.io/local-path
- **VolumeBindingMode**: WaitForFirstConsumer (delays binding until pod scheduled)
- **ReclaimPolicy**: Delete

3. **Create PVC with dynamic provisioning**:

Save as `pvc-dynamic.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-dynamic
spec:
  storageClassName: standard  # Uses dynamic provisioner
  accessModes:

    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

Apply:
```bash
kubectl apply -f pvc-dynamic.yaml
kubectl get pvc pvc-dynamic
```

Status is `Pending` because VolumeBindingMode is `WaitForFirstConsumer`.

4. **Use the dynamic PVC**:

Save as `pod-dynamic-storage.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-dynamic
spec:
  containers:

  - name: app
    image: busybox:1.36
    command:

    - sh
    - -c
    - |
      echo "Dynamic storage test" > /data/test.txt
      echo "Data written at: $(date)" >> /data/test.txt
      cat /data/test.txt
      sleep 3600
    volumeMounts:

    - name: data
      mountPath: /data
  volumes:

  - name: data
    persistentVolumeClaim:
      claimName: pvc-dynamic
```

Apply:
```bash
kubectl apply -f pod-dynamic-storage.yaml

# Watch PVC bind

kubectl get pvc pvc-dynamic --watch
```

Now PVC status changes to `Bound` and PV is automatically created!

```bash
kubectl get pv
# You'll see a new auto-generated PV
```

### Step 7: Create Custom StorageClass

1. **Create a custom StorageClass**:

Save as `storageclass-custom.yaml`:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: rancher.io/local-path
volumeBindingMode: Immediate  # Bind immediately
reclaimPolicy: Delete
parameters:
  # Provisioner-specific parameters
  pathPattern: "/mnt/fast-storage"
```

Apply:
```bash
kubectl apply -f storageclass-custom.yaml
kubectl get sc
```

2. **Use custom StorageClass**:

Save as `pvc-fast.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-fast
spec:
  storageClassName: fast-storage
  accessModes:

    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Apply:
```bash
kubectl apply -f pvc-fast.yaml
kubectl get pvc pvc-fast
```

With `Immediate` binding, PV is provisioned immediately.

### Step 8: StatefulSet with Persistent Storage

StatefulSets manage stateful applications with stable network identities and persistent storage.

1. **Create a StatefulSet with PVC template**:

Save as `statefulset-storage.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
spec:
  clusterIP: None  # Headless service
  selector:
    app: nginx-stateful
  ports:

  - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: nginx-headless
  replicas: 3
  selector:
    matchLabels:
      app: nginx-stateful
  template:
    metadata:
      labels:
        app: nginx-stateful
    spec:
      containers:

      - name: nginx
        image: nginx:1.25
        ports:

        - containerPort: 80
        volumeMounts:

        - name: www
          mountPath: /usr/share/nginx/html
        command:

        - sh
        - -c
        - |
          echo "<h1>Pod: $HOSTNAME</h1>" > /usr/share/nginx/html/index.html
          nginx -g 'daemon off;'
  volumeClaimTemplates:

  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: standard
      resources:
        requests:
          storage: 1Gi
```

Apply:
```bash
kubectl apply -f statefulset-storage.yaml

# Watch pods being created

kubectl get pods -l app=nginx-stateful --watch
```

2. **Observe ordered pod creation**:

StatefulSet pods are created sequentially:

- `web-0` created first
- After `web-0` is Running, `web-1` is created
- After `web-1` is Running, `web-2` is created

3. **Check PVCs**:
```bash
kubectl get pvc
```

You'll see: `www-web-0`, `www-web-1`, `www-web-2`

Each pod has its own persistent volume!

4. **Test pod identity and persistence**:
```bash
# Write unique data to each pod

kubectl exec web-0 -- sh -c "echo 'Data from web-0' >> /usr/share/nginx/html/data.txt"
kubectl exec web-1 -- sh -c "echo 'Data from web-1' >> /usr/share/nginx/html/data.txt"
kubectl exec web-2 -- sh -c "echo 'Data from web-2' >> /usr/share/nginx/html/data.txt"

# Read data

kubectl exec web-0 -- cat /usr/share/nginx/html/data.txt
kubectl exec web-1 -- cat /usr/share/nginx/html/data.txt
```

5. **Delete a pod and verify persistence**:
```bash
kubectl delete pod web-1

# Wait for recreation

kubectl get pods -l app=nginx-stateful --watch

# Check data is still there

kubectl exec web-1 -- cat /usr/share/nginx/html/data.txt
```

The new `web-1` pod reattaches to the same PVC!

6. **Scale StatefulSet**:
```bash
kubectl scale statefulset web --replicas=4

# New pod web-3 created with new PVC

kubectl get pods -l app=nginx-stateful
kubectl get pvc
```

### Step 9: Snapshot and Backup (Conceptual)

While CSI snapshots require specific provisioners, here's the concept:

1. **VolumeSnapshot** (requires VolumeSnapshotClass):

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-snapshot
spec:
  volumeSnapshotClassName: csi-snapshot-class
  source:
    persistentVolumeClaimName: pvc-dynamic
```

2. **Restore from snapshot**:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-from-snapshot
spec:
  dataSource:
    name: my-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:

    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

**Manual backup approach**:
```bash
# Backup PVC data

kubectl exec pod-with-storage -- tar czf - /data | gzip > backup.tar.gz

# Restore to new PVC

kubectl exec new-pod -- tar xzf - < backup.tar.gz
```bash
### Step 10: Storage Best Practices

1. **Use labels for PV selection**:

Save as `pvc-with-selector.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-labeled
spec:
  storageClassName: manual
  accessModes:

    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  selector:
    matchLabels:
      type: local  # Matches PV labels
```bash
2. **Resource limits and requests**:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
  namespace: lab-06
spec:
  hard:
    persistentvolumeclaims: "10"
    requests.storage: "100Gi"
```

Apply:
```bash
kubectl apply -f storage-quota.yaml
kubectl describe resourcequota storage-quota
```

3. **Monitor storage usage**:
```bash
# Check PVC usage in pods

kubectl exec pod-with-storage -- df -h /usr/share/nginx/html

# List all PVCs with their status

kubectl get pvc -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName
```

## Validation

Verify your understanding:

```bash
# 1. List all PVs

kubectl get pv
# Should see manually created and dynamically provisioned PVs

# 2. List all PVCs

kubectl get pvc
# Should show Bound status for active PVCs

# 3. Check StatefulSet has 4 replicas

kubectl get statefulset web -o jsonpath='{.status.readyReplicas}'
# Should show: 4

# 4. Verify each StatefulSet pod has its own PVC

kubectl get pvc -l app=nginx-stateful | wc -l
# Should match number of replicas

# 5. Check storage classes

kubectl get sc
# Should show standard and fast-storage

# 6. Verify data persistence

kubectl exec web-0 -- cat /usr/share/nginx/html/data.txt
# Should show previously written data
```

## Practice Challenges

Test your skills:

1. **Challenge 1**: Create a 5Gi PV with ReadWriteMany access mode and bind it to a PVC
   <details>
   <summary>Hint</summary>
   Note: hostPath doesn't truly support RWX. In real clusters, use NFS or cloud storage.
   </details>

2. **Challenge 2**: Create a Deployment with 3 replicas, all sharing the same PVC
   <details>
   <summary>Consideration</summary>
   Only works with ReadWriteMany (RWX) volumes. Most storage types are RWO.
   </details>

3. **Challenge 3**: Create a StatefulSet with 2 replicas, each with 2Gi storage, and scale to 5 replicas
   <details>
   <summary>Steps</summary>
   ```bash
   # Create StatefulSet with volumeClaimTemplates
   kubectl apply -f statefulset.yaml
   kubectl scale statefulset <name> --replicas=5
   # Watch new PVCs get created
   ```
   </details>

4. **Challenge 4**: Delete a StatefulSet but preserve the PVCs
   <details>
   <summary>Solution</summary>
   ```bash
   kubectl delete statefulset web --cascade=orphan
   # PVCs remain
   kubectl get pvc
   ```
   </details>

5. **Challenge 5**: Create a Pod that writes 1GB of data to an emptyDir with 500Mi limit. What happens?
   <details>
   <summary>Expected</summary>
   Pod will be evicted when limit is exceeded
   </details>

## Cleanup

Remove all resources:

```bash
# Delete namespace (PVCs deleted)

kubectl delete namespace lab-06

# Check PVs

kubectl get pv

# Manually delete PVs with Retain policy

kubectl delete pv pv-manual

# PVs with Delete policy are auto-deleted

# Delete custom StorageClass

kubectl delete sc fast-storage
```bash
## Troubleshooting Guide

| Issue | Diagnostic | Solution |
|-------|-----------|----------|
| PVC stuck in Pending | `kubectl describe pvc <name>` | Check no matching PV exists or StorageClass exists |
| Pod can't mount volume | `kubectl describe pod <name>` | Check PVC is Bound, access mode compatible |
| StatefulSet pods stuck | `kubectl get events` | Check PVC provisioning, storage quota |
| PV not binding to PVC | Check storageClassName, capacity, access modes | Must match between PV and PVC |
| Out of disk space | `df -h` in pod | Increase PVC size or clean up data |
| VolumeBindingMode delay | Check StorageClass bindingMode | WaitForFirstConsumer waits for pod |

**Essential debugging commands**:
```bash
kubectl get pv,pvc
kubectl describe pv <name>
kubectl describe pvc <name>
kubectl get events --sort-by='.lastTimestamp'
kubectl describe pod <name>
```

## Key Takeaways

- ✅ **emptyDir**: Temporary storage, deleted with Pod
- ✅ **hostPath**: Node-specific, not portable, avoid in production
- ✅ **PV**: Cluster-wide storage resource
- ✅ **PVC**: Request for storage by pods
- ✅ **StorageClass**: Dynamic provisioning, abstracts storage backend
- ✅ **Access Modes**: RWO (most common), ROX, RWX, RWOP
- ✅ **Reclaim Policy**: Retain (manual), Delete (auto-cleanup)
- ✅ **VolumeBindingMode**: Immediate vs WaitForFirstConsumer
- ✅ **StatefulSets**: Stable identity + persistent storage per pod
- ✅ **volumeClaimTemplates**: Automatic PVC creation per replica
- ✅ **Dynamic Provisioning**: Automatic PV creation via StorageClass

## Additional Resources

- [Volumes Documentation](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [CSI Drivers](https://kubernetes-csi.github.io/docs/)

## Next Lab

[Lab 7: Resource Management](../lab-07-resources/) - Learn resource requests, limits, QoS, and autoscaling

---

**Estimated Time**: 120-150 minutes
