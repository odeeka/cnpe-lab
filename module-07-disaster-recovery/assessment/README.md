# Module 7 Assessment: Disaster Recovery and Business Continuity

## 📋 Assessment Overview

| Attribute | Value |
|-----------|-------|
| **Total Points** | 100 |
| **Passing Score** | 70% |
| **Time Limit** | 2.5 hours |
| **Environment** | Two Kubernetes clusters with shared storage |

---

## 🎯 Assessment Objectives

This assessment evaluates your ability to:
- Implement backup and restore procedures
- Configure Velero for Kubernetes backup
- Design and execute DR procedures
- Conduct chaos engineering experiments
- Document and validate recovery procedures

---

## 📝 Prerequisites

Before starting, ensure:
- Two Kubernetes clusters available (primary + DR)
- Velero CLI installed
- Object storage accessible (S3/MinIO)
- Chaos Mesh or Litmus installed
- kubectl configured for both clusters

---

## Section 1: Backup Operations (25 points)

### Task 1.1: etcd Backup (7 points)

Create an automated etcd backup solution:

**Requirements:**
1. Create a CronJob that backs up etcd every 4 hours
2. Store backups in `/backup/etcd` with timestamp naming
3. Verify snapshot integrity after creation
4. Retain only the last 6 backups
5. Upload backups to S3 bucket `exam-backups/etcd/`

**Validation:**
```bash
# Verify CronJob exists
kubectl get cronjob etcd-backup -n kube-system

# Verify backup created (check the Job pod created by CronJob)
kubectl get pods -n kube-system -l job-name=etcd-backup --sort-by=.metadata.creationTimestamp

# Check backup files
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l job-name=etcd-backup -o jsonpath='{.items[-1].metadata.name}') -- ls -la /backup/etcd/

# Verify snapshot integrity
etcdctl snapshot status /backup/etcd/etcd-snapshot-YYYYMMDD-HHMMSS.db --write-out=table
```

### Task 1.2: Velero Installation (6 points)

Install and configure Velero:

**Requirements:**
1. Install Velero with AWS plugin
2. Configure backup storage location pointing to `s3://exam-backups/velero/`
3. Enable file-system backup (Restic/Kopia)
4. Verify installation is healthy

**Validation:**
```bash
velero version
velero backup-location get
kubectl get pods -n velero
```

### Task 1.3: Application Backup (7 points)

Create a comprehensive backup of the `exam-app` namespace:

**Requirements:**
1. Create backup named `exam-app-backup`
2. Include all resources in `exam-app` namespace
3. Use volume snapshots for PVCs
4. Set TTL to 72 hours
5. Wait for backup to complete

**Validation:**
```bash
velero backup describe exam-app-backup --details
```

### Task 1.4: Backup Hooks (5 points)

Configure backup hooks for a PostgreSQL deployment:

**Requirements:**
1. Add pre-backup hook to run `pg_dump`
2. Add post-backup hook for cleanup
3. Store dump in `/backup/dump.sql`
4. Set timeout to 120 seconds

**Apply to deployment:** `postgresql` in namespace `exam-app`

---

## Section 2: Restore Operations (20 points)

### Task 2.1: Namespace Restore (8 points)

Restore from backup to a different namespace:

**Requirements:**
1. Restore `exam-app-backup` to namespace `exam-app-restored`
2. Exclude events and replicasets from restore
3. Wait for restore to complete
4. Verify all pods are running

**Validation:**
```bash
kubectl get pods -n exam-app-restored
kubectl get pvc -n exam-app-restored
```

### Task 2.2: Selective Restore (6 points)

Perform a selective restore:

**Requirements:**
1. Create restore named `selective-restore` from backup `exam-app-backup`
2. Only restore deployments and services
3. Restore to original namespace (`exam-app`)
4. Verify restored resources

**Validation:**
```bash
velero restore describe selective-restore
kubectl get deployments,services -n exam-app
```

### Task 2.3: Restore Verification (6 points)

Create a verification job that validates restored data:

**Requirements:**
1. Create Job `verify-restore` in `exam-app-restored`
2. Connect to PostgreSQL and verify table count
3. Check data integrity (row counts match expected)
4. Exit 0 if successful, 1 if failed

---

## Section 3: Disaster Recovery (30 points)

### Task 3.1: DR Architecture (8 points)

Design a DR solution with the following requirements:

- **RTO:** 15 minutes
- **RPO:** 5 minutes
- **Application:** 3-tier web application with PostgreSQL

**Setup:**
```bash
# Create the disaster-recovery namespace first
kubectl create namespace disaster-recovery
```

Create a ConfigMap `dr-design` in namespace `disaster-recovery` containing:
1. Recommended DR strategy tier
2. Replication configuration
3. Failover procedure outline
4. Cost estimation (relative: $, $$, $$$)

### Task 3.2: Database Replication (8 points)

Configure database replication for DR:

**Requirements:**
1. Deploy PostgreSQL primary in `primary-ns`
2. Configure streaming replication to replica in `dr-ns`
3. Verify replication lag < 10 seconds
4. Document promotion procedure

**Validation:**
```bash
# Check replication status
kubectl exec -n primary-ns postgres-0 -- \
  psql -c "SELECT * FROM pg_stat_replication;"
```

### Task 3.3: Failover Procedure (8 points)

Create and execute a failover procedure:

**Requirements:**
1. Create ConfigMap `failover-runbook` with step-by-step procedure
2. Create Job `execute-failover` that:
   - Promotes DR database replica
   - Updates application database connection
   - Scales DR applications
   - Verifies service health
3. Document rollback procedure

### Task 3.4: DR Drill (6 points)

Execute a DR drill and document results:

**Requirements:**
1. Create namespace `dr-drill-test`
2. Restore application from backup
3. Verify functionality
4. Document:
   - Actual RTO achieved
   - Issues encountered
   - Lessons learned
5. Clean up drill resources

---

## Section 4: Chaos Engineering (25 points)

### Task 4.1: Pod Chaos (7 points)

Create a pod chaos experiment:

**Requirements:**
1. Install Chaos Mesh (if not installed)
2. Create PodChaos experiment `pod-failure-test` in namespace `chaos-mesh`
3. Target pods with label `app=web-api` in namespace `exam-app`
4. Kill 30% of pods every 60 seconds
5. Duration: 5 minutes
6. Observe and document application behavior

**Validation:**
```bash
# Check chaos experiment status
kubectl get podchaos pod-failure-test -n chaos-mesh
kubectl describe podchaos pod-failure-test -n chaos-mesh

# Watch target pods
kubectl get pods -n exam-app -l app=web-api -w
```

### Task 4.2: Network Chaos (7 points)

Create a network chaos experiment:

**Requirements:**
1. Create NetworkChaos experiment `network-delay-test` in namespace `chaos-mesh`
2. Inject 200ms latency with 50ms jitter
3. Target traffic from pods with label `app=web-api` to pods with label `app=database` in namespace `exam-app`
4. Duration: 3 minutes
5. Monitor P99 latency during experiment

**Validation:**
```bash
# Check network chaos status
kubectl get networkchaos network-delay-test -n chaos-mesh
kubectl describe networkchaos network-delay-test -n chaos-mesh

# Test latency from web-api pod
kubectl exec -n exam-app deploy/web-api -- curl -w "\nTime: %{time_total}s\n" -o /dev/null -s http://database:5432
```

### Task 4.3: Chaos Workflow (6 points)

Create a chaos workflow that runs multiple experiments:

**Requirements:**
1. Create Workflow `resilience-workflow`
2. Steps (serial):
   - Network delay (2 min)
   - Pod kill (1 min)
   - Recovery observation (2 min)
3. Total duration: 5 minutes

### Task 4.4: GameDay Documentation (5 points)

Create a GameDay plan:

**Requirements:**
Create ConfigMap `gameday-plan` containing:
1. GameDay objectives
2. 3 chaos scenarios to execute
3. Success criteria for each
4. Rollback procedures
5. Communication plan

---

## 📊 Scoring Rubric

### Section 1: Backup Operations (25 points)

| Task | Points | Criteria |
|------|--------|----------|
| 1.1 etcd Backup | 7 | CronJob created, retention works, S3 upload works |
| 1.2 Velero Install | 6 | All components running, storage configured |
| 1.3 App Backup | 7 | Backup complete, volumes included, TTL set |
| 1.4 Backup Hooks | 5 | Hooks configured, dump created |

### Section 2: Restore Operations (20 points)

| Task | Points | Criteria |
|------|--------|----------|
| 2.1 Namespace Restore | 8 | Restore complete, namespace mapping works |
| 2.2 Selective Restore | 6 | Only specified resources restored |
| 2.3 Verification | 6 | Job validates data integrity |

### Section 3: Disaster Recovery (30 points)

| Task | Points | Criteria |
|------|--------|----------|
| 3.1 DR Design | 8 | Appropriate strategy, complete documentation |
| 3.2 DB Replication | 8 | Replication working, lag acceptable |
| 3.3 Failover | 8 | Procedure documented and executable |
| 3.4 DR Drill | 6 | Drill executed, documented |

### Section 4: Chaos Engineering (25 points)

| Task | Points | Criteria |
|------|--------|----------|
| 4.1 Pod Chaos | 7 | Experiment runs, behavior documented |
| 4.2 Network Chaos | 7 | Latency injected, metrics captured |
| 4.3 Workflow | 6 | Workflow executes in sequence |
| 4.4 GameDay | 5 | Complete plan with all elements |

---

## 🔍 Validation Commands

### Backup Validation

```bash
# Check Velero backup
velero backup describe exam-app-backup --details

# Check backup logs
velero backup logs exam-app-backup

# Verify etcd backup
etcdctl snapshot status /backup/etcd/snapshot.db --write-out=table
```

### Restore Validation

```bash
# Check restore status
velero restore describe <restore-name> --details

# Verify restored resources
kubectl get all -n exam-app-restored

# Check PVC data
kubectl exec -n exam-app-restored deploy/app -- ls -la /data
```

### DR Validation

```bash
# Check replication lag
kubectl exec postgres-0 -n primary-ns -- \
  psql -c "SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) FROM pg_stat_replication;"

# Verify DR site health
kubectl get pods -n dr-ns
```

### Chaos Validation

```bash
# Check chaos experiments
kubectl get podchaos,networkchaos,workflow -n chaos-mesh

# Check experiment status
kubectl describe podchaos pod-failure-test -n chaos-mesh
```

---

## ⚠️ Important Notes

1. **Backup Storage:** Ensure S3 credentials are configured before starting
2. **etcd Access:** You may need host access for etcd backup tasks
3. **Chaos Safety:** Only run chaos experiments in the `chaos-mesh` namespace, targeting only `exam-app`
4. **Time Management:** Section 3 (DR) typically takes longest - allocate 45-60 minutes
5. **Documentation:** Written procedures are evaluated for completeness
6. **Namespace Setup:** Create required namespaces before starting tasks:
   ```bash
   kubectl create namespace exam-app
   kubectl create namespace disaster-recovery
   kubectl create namespace primary-ns
   kubectl create namespace dr-ns
   ```

---

## 📝 Submission Checklist

Before completing the assessment:

- [ ] All backup operations completed and verified
- [ ] Restore operations tested and validated
- [ ] DR procedures documented and tested
- [ ] Chaos experiments executed safely
- [ ] All ConfigMaps and documentation created
- [ ] Verification commands run successfully
- [ ] Cleanup completed where specified

---

## 🎓 Assessment Tips

1. **Start with Velero** - Many tasks depend on it
2. **Document as you go** - Don't leave documentation to the end
3. **Test restores** - Don't assume backups work
4. **Monitor during chaos** - Capture metrics and observations
5. **Keep it simple** - Don't over-engineer solutions

Good luck! 🚀
