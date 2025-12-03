# Module 7: Quick Reference

## 📋 Backup Commands

### etcd Backup

```bash
# Check etcd cluster health
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

# Create etcd snapshot
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify snapshot
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db --write-out=table

# Restore from snapshot
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restored \
  --name=controlplane \
  --initial-cluster=controlplane=https://127.0.0.1:2380 \
  --initial-advertise-peer-urls=https://127.0.0.1:2380
```

### Volume Snapshots

```bash
# Create VolumeSnapshot
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: pvc-snapshot
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: my-pvc
EOF

# List snapshots
kubectl get volumesnapshots

# Restore from snapshot
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
spec:
  dataSource:
    name: pvc-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF
```

---

## 📋 Velero Commands

### Installation

```bash
# Install Velero CLI
curl -L https://github.com/vmware-tanzu/velero/releases/download/v1.13.0/velero-v1.13.0-linux-amd64.tar.gz | tar xz
sudo mv velero-v1.13.0-linux-amd64/velero /usr/local/bin/

# Install Velero with AWS plugin
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket velero-backups \
  --secret-file ./credentials \
  --backup-location-config region=us-east-1 \
  --use-node-agent

# Check installation
velero version
kubectl get pods -n velero
```

### Backup Operations

```bash
# Create namespace backup
velero backup create my-backup --include-namespaces production

# Create backup with label selector
velero backup create app-backup --selector app=nginx

# Create backup excluding resources
velero backup create partial-backup \
  --include-namespaces production \
  --exclude-resources pods,events

# Create backup with TTL
velero backup create ttl-backup \
  --include-namespaces production \
  --ttl 720h

# Create backup from schedule
velero backup create --from-schedule daily-backup

# List backups
velero backup get

# Describe backup
velero backup describe my-backup --details

# View backup logs
velero backup logs my-backup
```

### Restore Operations

```bash
# Restore entire backup
velero restore create --from-backup my-backup

# Restore with namespace mapping
velero restore create --from-backup my-backup \
  --namespace-mappings "production:production-restore"

# Restore specific resources
velero restore create --from-backup my-backup \
  --include-resources deployments,services

# Exclude namespaces from restore
velero restore create --from-backup my-backup \
  --exclude-namespaces kube-system

# List restores
velero restore get

# Describe restore
velero restore describe my-restore --details

# View restore logs
velero restore logs my-restore
```

### Schedule Management

```bash
# Create schedule
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces production \
  --ttl 168h

# List schedules
velero schedule get

# Describe schedule
velero schedule describe daily-backup

# Delete schedule
velero schedule delete daily-backup

# Pause schedule
velero schedule pause daily-backup

# Unpause schedule
velero schedule unpause daily-backup
```

### Backup Location

```bash
# Get backup locations
velero backup-location get

# Create backup location
velero backup-location create secondary \
  --provider aws \
  --bucket secondary-bucket \
  --config region=us-west-2

# Set default location
velero backup-location set default --default
```

---

## 📋 Disaster Recovery

### RTO/RPO Quick Reference

| Tier | Strategy | RTO | RPO | Cost |
|------|----------|-----|-----|------|
| 1 | Active-Active | ~0 | 0 | $$$$$ |
| 2 | Hot Standby | Minutes | Seconds | $$$$ |
| 3 | Warm Standby | Hours | Hours | $$$ |
| 4 | Pilot Light | Hours-Day | Hours | $$ |
| 5 | Backup/Restore | Days | Days | $ |

### DNS Failover (Route53)

```bash
# Update DNS record
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.example.com",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [{"Value": "dr-endpoint.example.com"}]
      }
    }]
  }'

# Check DNS propagation
dig api.example.com +short
```

### Database Failover

```bash
# PostgreSQL - Check replication status
kubectl exec postgres-0 -- psql -c "SELECT * FROM pg_stat_replication;"

# PostgreSQL - Promote replica
kubectl exec postgres-replica-0 -- pg_ctl promote

# CloudNativePG - Promote replica
kubectl cnpg promote postgres-replica -n production

# Check new primary
kubectl get cluster postgres-replica -n production
```

### Failover Checklist

```
□ Disaster declared and authorized
□ Team assembled in war room
□ DR site health verified
□ Database replica promoted
□ Applications scaled up
□ DNS/traffic updated
□ Services verified
□ Stakeholders notified
□ Monitoring confirmed
```

---

## 📋 Chaos Engineering

### Litmus Chaos

```bash
# Install Litmus
helm install litmus litmuschaos/litmus --namespace litmus

# Install experiments
kubectl apply -f https://hub.litmuschaos.io/api/chaos/3.0.0?file=charts/generic/experiments.yaml

# List experiments
kubectl get chaosexperiments -n litmus

# Check chaos engine status
kubectl get chaosengine -n default

# Get chaos results
kubectl get chaosresult -n default -o yaml

# Delete chaos engine
kubectl delete chaosengine my-chaos -n default
```

### Chaos Mesh

```bash
# Install Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace chaos-mesh \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock

# List chaos experiments
kubectl get podchaos,networkchaos,stresschaos -A

# Delete chaos experiment
kubectl delete podchaos pod-failure -n chaos-mesh

# View chaos dashboard
kubectl port-forward svc/chaos-dashboard -n chaos-mesh 2333:2333
```

### Pod Chaos

```yaml
# Pod Kill
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces: [default]
    labelSelectors:
      app: nginx
```

### Network Chaos

```yaml
# Network Delay
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-delay
spec:
  action: delay
  mode: all
  selector:
    namespaces: [default]
    labelSelectors:
      app: web
  delay:
    latency: "100ms"
    jitter: "50ms"
  duration: "60s"
```

### Stress Chaos

```yaml
# CPU Stress
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: cpu-stress
spec:
  mode: all
  selector:
    namespaces: [default]
    labelSelectors:
      app: compute
  stressors:
    cpu:
      workers: 2
      load: 80
  duration: "60s"
```

---

## 📋 Monitoring During Chaos

### Key Metrics to Watch

```promql
# Request success rate
sum(rate(http_requests_total{status=~"2.."}[5m])) / 
sum(rate(http_requests_total[5m])) * 100

# P99 latency
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# Pod restart rate
sum(rate(kube_pod_container_status_restarts_total[5m])) by (namespace)

# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)

# Active chaos experiments
count(chaos_mesh_chaos_experiments{phase="Running"})
```

### Alerting During Chaos

```yaml
# Alert: High error rate during chaos
- alert: HighErrorRateDuringChaos
  expr: |
    (sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))) > 0.1
    and chaos_mesh_chaos_experiments{phase="Running"} > 0
  for: 2m
  labels:
    severity: warning
```

---

## 📋 Common Patterns

### Backup Retention Policy

```yaml
# Velero schedule with retention
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: production-backup
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces: [production]
    ttl: 168h  # 7 days
```

### Pre/Post Backup Hooks

```yaml
# Deployment with backup hooks
metadata:
  annotations:
    backup.velero.io/backup-volumes: data
    pre.hook.backup.velero.io/command: '["/bin/bash","-c","pg_dump > /backup/dump.sql"]'
    pre.hook.backup.velero.io/container: postgres
    post.hook.backup.velero.io/command: '["/bin/bash","-c","rm /backup/dump.sql"]'
```

### Chaos Workflow

```yaml
# Serial chaos workflow
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: resilience-test
spec:
  entry: main
  templates:
    - name: main
      templateType: Serial
      children: [step1, step2, step3]
```

---

## 📋 Troubleshooting

### Velero Issues

```bash
# Check Velero logs
kubectl logs -n velero deploy/velero

# Check node-agent logs
kubectl logs -n velero -l name=node-agent

# Debug backup
velero backup describe my-backup --details
velero backup logs my-backup

# Check backup storage connectivity
kubectl exec -n velero deploy/velero -- \
  velero debug --backup-location default
```

### Chaos Experiment Issues

```bash
# Check Chaos Mesh controller logs
kubectl logs -n chaos-mesh -l app.kubernetes.io/component=controller-manager

# Check chaos daemon logs
kubectl logs -n chaos-mesh -l app.kubernetes.io/component=chaos-daemon

# Describe chaos experiment
kubectl describe podchaos my-chaos -n chaos-mesh
```

### etcd Issues

```bash
# Check etcd health
etcdctl endpoint health --cluster

# Check etcd member list
etcdctl member list

# Check etcd alarms
etcdctl alarm list

# Defragment etcd
etcdctl defrag --cluster
```

---

## 📋 Best Practices Checklist

### Backup Strategy
- [ ] 3-2-1 rule (3 copies, 2 media, 1 offsite)
- [ ] Regular restore testing
- [ ] Encrypted backups
- [ ] Retention policies defined
- [ ] Monitoring and alerting

### Disaster Recovery
- [ ] RTO/RPO defined per workload
- [ ] Runbooks documented and current
- [ ] Regular DR drills
- [ ] Failover automated where possible
- [ ] Communication plan ready

### Chaos Engineering
- [ ] Start in non-production
- [ ] Hypothesis defined before experiments
- [ ] Monitoring in place
- [ ] Kill switches ready
- [ ] Stakeholders informed
- [ ] Blast radius minimized
