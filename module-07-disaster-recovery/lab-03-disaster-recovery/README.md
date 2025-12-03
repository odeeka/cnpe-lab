# Lab 3: Disaster Recovery Planning

## 🎯 Objectives

By the end of this lab, you will:
- Design DR strategies based on RTO/RPO requirements
- Implement multi-region architectures
- Create failover procedures and runbooks
- Execute DR drills and validation
- Build automated DR orchestration

## ⏱️ Estimated Time: 90 minutes

---

## Part 1: DR Strategy Design

### Understanding RTO and RPO

```
┌─────────────────────────────────────────────────────────────────┐
│                     RTO vs RPO Explained                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Timeline:                                                        │
│  ─────────────────────────────────────────────────────────────── │
│        │                    │                    │                │
│   Last Backup          Disaster            Recovery               │
│        │                    │                    │                │
│        │◄────── RPO ───────►│◄────── RTO ───────►│               │
│        │    (Data Loss)     │    (Downtime)     │                │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                                                               │ │
│  │  RPO = Recovery Point Objective                              │ │
│  │  • Maximum acceptable data loss                               │ │
│  │  • Measured in time                                           │ │
│  │  • Determines backup frequency                                │ │
│  │                                                               │ │
│  │  Examples:                                                     │ │
│  │  • RPO = 0: No data loss (sync replication)                  │ │
│  │  • RPO = 1 hour: Max 1 hour of data loss                     │ │
│  │  • RPO = 24 hours: Max 1 day of data loss                    │ │
│  │                                                               │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                                                               │ │
│  │  RTO = Recovery Time Objective                               │ │
│  │  • Maximum acceptable downtime                                │ │
│  │  • Measured in time                                           │ │
│  │  • Determines DR architecture                                 │ │
│  │                                                               │ │
│  │  Examples:                                                     │ │
│  │  • RTO = 0: No downtime (active-active)                      │ │
│  │  • RTO = 15 min: Quick failover                              │ │
│  │  • RTO = 4 hours: Standard DR                                │ │
│  │                                                               │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### DR Strategy Tiers

```
┌─────────────────────────────────────────────────────────────────┐
│                    DR Strategy Comparison                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Tier 1: Active-Active (Multi-Region)                            │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Region A              Region B                              │ │
│  │  ┌─────────┐          ┌─────────┐                           │ │
│  │  │  App    │◄────────►│  App    │  ◄─ Sync Replication      │ │
│  │  │  + DB   │          │  + DB   │                           │ │
│  │  └─────────┘          └─────────┘                           │ │
│  │       │                    │                                 │ │
│  │       └────────────────────┘                                 │ │
│  │              Global LB                                       │ │
│  │                                                               │ │
│  │  RTO: ~0  |  RPO: 0  |  Cost: $$$$$                         │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Tier 2: Hot Standby                                              │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Primary             DR Site                                 │ │
│  │  ┌─────────┐        ┌─────────┐                             │ │
│  │  │  App    │───────►│  App    │  ◄─ Async Replication       │ │
│  │  │  + DB   │        │  (hot)  │                             │ │
│  │  └─────────┘        └─────────┘                             │ │
│  │                                                               │ │
│  │  RTO: Minutes  |  RPO: Seconds-Minutes  |  Cost: $$$$       │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Tier 3: Warm Standby                                             │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Primary             DR Site                                 │ │
│  │  ┌─────────┐        ┌─────────┐                             │ │
│  │  │  App    │───────►│  App    │  ◄─ Reduced capacity        │ │
│  │  │  + DB   │        │ (scaled │                             │ │
│  │  └─────────┘        │  down)  │                             │ │
│  │                     └─────────┘                              │ │
│  │  RTO: Hours  |  RPO: Hours  |  Cost: $$$                    │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Tier 4: Pilot Light                                              │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Primary             DR Site                                 │ │
│  │  ┌─────────┐        ┌─────────┐                             │ │
│  │  │  App    │───────►│  Core   │  ◄─ Minimal infra           │ │
│  │  │  + DB   │        │  only   │                             │ │
│  │  └─────────┘        └─────────┘                             │ │
│  │                                                               │ │
│  │  RTO: Hours-Day  |  RPO: Hours  |  Cost: $$                 │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Tier 5: Backup & Restore                                         │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Primary             Backup Storage                          │ │
│  │  ┌─────────┐        ┌─────────┐                             │ │
│  │  │  App    │───────►│ Backups │  ◄─ No running infra        │ │
│  │  │  + DB   │        │  only   │                             │ │
│  │  └─────────┘        └─────────┘                             │ │
│  │                                                               │ │
│  │  RTO: Days  |  RPO: Days  |  Cost: $                        │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### DR Requirements Worksheet

```yaml
# dr-requirements.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dr-requirements
  namespace: disaster-recovery
data:
  requirements.yaml: |
    # DR Requirements Assessment
    
    business_requirements:
      # Financial impact of downtime
      hourly_revenue_loss: "$50,000"
      max_acceptable_downtime: "4 hours"
      max_acceptable_data_loss: "1 hour"
      
      # Regulatory requirements
      compliance:
        - "SOC 2 - Business Continuity"
        - "HIPAA - Contingency Plan"
        - "PCI-DSS - DR Requirements"
    
    workload_classification:
      tier_1_critical:
        description: "Revenue-generating, customer-facing"
        rto: "15 minutes"
        rpo: "5 minutes"
        examples:
          - "payment-service"
          - "order-service"
          - "customer-api"
        strategy: "hot-standby"
      
      tier_2_important:
        description: "Business operations, internal"
        rto: "4 hours"
        rpo: "1 hour"
        examples:
          - "inventory-service"
          - "reporting-service"
          - "notification-service"
        strategy: "warm-standby"
      
      tier_3_standard:
        description: "Non-critical, can tolerate downtime"
        rto: "24 hours"
        rpo: "24 hours"
        examples:
          - "analytics-service"
          - "batch-jobs"
          - "dev-tools"
        strategy: "backup-restore"
    
    infrastructure:
      primary_region: "us-east-1"
      dr_region: "us-west-2"
      backup_storage: "s3://company-dr-backups"
      
    testing:
      frequency: "quarterly"
      type: "full-failover"
      notification_required: true
```

---

## Part 2: Multi-Region Architecture

### GitOps Multi-Region Setup

```yaml
# multi-region-argocd.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-region-app
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: production-east
        url: https://k8s-east.example.com
        region: us-east-1
        role: primary
      - cluster: production-west
        url: https://k8s-west.example.com
        region: us-west-2
        role: dr
  template:
    metadata:
      name: 'app-{{cluster}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/company/k8s-apps.git
        targetRevision: HEAD
        path: 'apps/{{cluster}}'
        helm:
          valueFiles:
          - values.yaml
          - 'values-{{region}}.yaml'
      destination:
        server: '{{url}}'
        namespace: production
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Database Replication Configuration

```yaml
# postgresql-ha.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster
  namespace: production
spec:
  instances: 3
  
  # Primary configuration
  primaryUpdateStrategy: unsupervised
  
  # Replication configuration
  postgresql:
    parameters:
      max_connections: "200"
      wal_level: replica
      max_wal_senders: "10"
      max_replication_slots: "10"
      hot_standby: "on"
      wal_keep_size: "1GB"
  
  # Storage
  storage:
    size: 100Gi
    storageClass: fast-ssd
  
  # Backup configuration
  backup:
    barmanObjectStore:
      destinationPath: s3://company-postgres-backups/
      s3Credentials:
        accessKeyId:
          name: postgres-backup-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: postgres-backup-creds
          key: SECRET_ACCESS_KEY
      wal:
        compression: gzip
        maxParallel: 4
      data:
        compression: gzip
    retentionPolicy: "30d"
  
  # Monitoring
  monitoring:
    enablePodMonitor: true
---
# Cross-region replica
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-replica
  namespace: production
  annotations:
    cnpg.io/cluster-role: replica
spec:
  instances: 2
  
  replica:
    enabled: true
    source: postgres-cluster
    
  externalClusters:
  - name: postgres-cluster
    connectionParameters:
      host: postgres-cluster-rw.production.svc
      port: "5432"
      user: streaming_replica
    password:
      name: replica-credentials
      key: password
```

### Cross-Region Data Sync

```yaml
# data-replication-job.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cross-region-sync
  namespace: disaster-recovery
spec:
  schedule: "*/15 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: sync
            image: amazon/aws-cli:latest
            command:
            - /bin/bash
            - -c
            - |
              set -e
              
              echo "Starting cross-region sync..."
              
              # Sync S3 buckets
              aws s3 sync s3://primary-bucket s3://dr-bucket \
                --source-region us-east-1 \
                --region us-west-2 \
                --delete
              
              # Verify sync
              PRIMARY_COUNT=$(aws s3 ls s3://primary-bucket --recursive | wc -l)
              DR_COUNT=$(aws s3 ls s3://dr-bucket --recursive | wc -l)
              
              if [ "$PRIMARY_COUNT" -ne "$DR_COUNT" ]; then
                echo "ERROR: Object count mismatch"
                exit 1
              fi
              
              echo "Sync completed: $PRIMARY_COUNT objects"
            env:
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: aws-credentials
                  key: access-key
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: aws-credentials
                  key: secret-key
          restartPolicy: OnFailure
```

---

## Part 3: Failover Procedures

### Automated Failover Controller

```yaml
# failover-controller.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: failover-controller
  namespace: disaster-recovery
spec:
  replicas: 1
  selector:
    matchLabels:
      app: failover-controller
  template:
    metadata:
      labels:
        app: failover-controller
    spec:
      serviceAccountName: failover-controller
      containers:
      - name: controller
        image: failover-controller:latest
        env:
        - name: PRIMARY_CLUSTER
          value: "https://k8s-east.example.com"
        - name: DR_CLUSTER
          value: "https://k8s-west.example.com"
        - name: HEALTH_CHECK_INTERVAL
          value: "30s"
        - name: FAILURE_THRESHOLD
          value: "3"
        - name: SLACK_WEBHOOK
          valueFrom:
            secretKeyRef:
              name: failover-config
              key: slack-webhook
        volumeMounts:
        - name: config
          mountPath: /etc/failover
      volumes:
      - name: config
        configMap:
          name: failover-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: failover-config
  namespace: disaster-recovery
data:
  config.yaml: |
    # Failover Configuration
    health_checks:
      - name: api-server
        type: kubernetes
        endpoint: /healthz
        timeout: 5s
      
      - name: core-services
        type: http
        endpoints:
          - https://api.example.com/health
          - https://payment.example.com/health
        timeout: 10s
      
      - name: database
        type: tcp
        host: postgres-primary.production.svc
        port: 5432
        timeout: 5s
    
    failover:
      auto_failover: false  # Require manual approval
      notification_channels:
        - slack
        - pagerduty
      
      pre_failover_checks:
        - verify_dr_health
        - check_replication_lag
        - confirm_backup_freshness
      
      steps:
        - name: notify_team
          action: send_notification
          message: "Initiating failover to DR site"
        
        - name: update_dns
          action: update_route53
          record: "api.example.com"
          target: "dr-lb.us-west-2.elb.amazonaws.com"
          ttl: 60
        
        - name: promote_database
          action: promote_replica
          cluster: postgres-replica
        
        - name: scale_dr
          action: scale_deployment
          deployments:
            - name: api-server
              replicas: 5
            - name: worker
              replicas: 3
        
        - name: verify_services
          action: health_check
          services:
            - api-server
            - payment-service
          timeout: 300s
        
        - name: notify_complete
          action: send_notification
          message: "Failover complete. DR site is now primary."
    
    failback:
      requires_approval: true
      steps:
        - sync_data_to_primary
        - update_dns_to_primary
        - demote_dr_database
        - scale_down_dr
```

### DNS Failover Script

```bash
#!/bin/bash
# dns-failover.sh - Automated DNS failover script

set -euo pipefail

# Configuration
PRIMARY_REGION="us-east-1"
DR_REGION="us-west-2"
HOSTED_ZONE_ID="Z1234567890ABC"
DOMAIN="api.example.com"

# Endpoints
PRIMARY_ENDPOINT="primary-lb.us-east-1.elb.amazonaws.com"
DR_ENDPOINT="dr-lb.us-west-2.elb.amazonaws.com"

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_primary_health() {
    log "Checking primary health..."
    curl -s --max-time 10 "https://${PRIMARY_ENDPOINT}/health" > /dev/null 2>&1
}

update_dns() {
    local target=$1
    local action=$2
    
    log "Updating DNS to $target ($action)..."
    
    aws route53 change-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --change-batch '{
            "Changes": [{
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "'"$DOMAIN"'",
                    "Type": "CNAME",
                    "TTL": 60,
                    "ResourceRecords": [{"Value": "'"$target"'"}]
                }
            }]
        }'
}

notify_team() {
    local message=$1
    log "Sending notification: $message"
    
    curl -X POST "$SLACK_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"🚨 DR Alert: $message\"}"
}

# Main failover logic
failover_to_dr() {
    log "=== INITIATING FAILOVER TO DR ==="
    
    # Pre-checks
    log "Running pre-failover checks..."
    
    # Check DR is healthy
    if ! curl -s --max-time 10 "https://${DR_ENDPOINT}/health" > /dev/null 2>&1; then
        log "ERROR: DR site is not healthy. Aborting failover."
        exit 1
    fi
    
    # Notify team
    notify_team "Initiating failover from $PRIMARY_REGION to $DR_REGION"
    
    # Update DNS
    update_dns "$DR_ENDPOINT" "FAILOVER"
    
    # Wait for DNS propagation
    log "Waiting for DNS propagation (60s)..."
    sleep 60
    
    # Verify failover
    RESOLVED=$(dig +short "$DOMAIN" | head -1)
    if [[ "$RESOLVED" == *"$DR_REGION"* ]]; then
        log "SUCCESS: DNS now points to DR site"
        notify_team "Failover complete. Traffic now routing to $DR_REGION"
    else
        log "WARNING: DNS verification inconclusive"
    fi
    
    log "=== FAILOVER COMPLETE ==="
}

failback_to_primary() {
    log "=== INITIATING FAILBACK TO PRIMARY ==="
    
    # Pre-checks
    log "Running pre-failback checks..."
    
    # Check primary is healthy
    if ! check_primary_health; then
        log "ERROR: Primary site is not healthy. Aborting failback."
        exit 1
    fi
    
    # Notify team
    notify_team "Initiating failback from $DR_REGION to $PRIMARY_REGION"
    
    # Update DNS
    update_dns "$PRIMARY_ENDPOINT" "FAILBACK"
    
    # Wait for DNS propagation
    log "Waiting for DNS propagation (60s)..."
    sleep 60
    
    # Verify failback
    log "SUCCESS: Failback complete"
    notify_team "Failback complete. Traffic now routing to $PRIMARY_REGION"
    
    log "=== FAILBACK COMPLETE ==="
}

# Parse arguments
case "${1:-}" in
    failover)
        failover_to_dr
        ;;
    failback)
        failback_to_primary
        ;;
    status)
        CURRENT=$(dig +short "$DOMAIN" | head -1)
        log "Current endpoint: $CURRENT"
        ;;
    *)
        echo "Usage: $0 {failover|failback|status}"
        exit 1
        ;;
esac
```

### Kubernetes Failover Job

```yaml
# failover-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: execute-failover
  namespace: disaster-recovery
spec:
  template:
    spec:
      serviceAccountName: failover-executor
      containers:
      - name: failover
        image: bitnami/kubectl:latest
        command:
        - /bin/bash
        - -c
        - |
          set -e
          
          echo "=== Starting Failover Process ==="
          
          # Step 1: Verify DR cluster connectivity
          echo "Step 1: Verifying DR cluster..."
          kubectl --kubeconfig=/etc/kubeconfig/dr-cluster get nodes
          
          # Step 2: Scale up DR deployments
          echo "Step 2: Scaling DR deployments..."
          kubectl --kubeconfig=/etc/kubeconfig/dr-cluster \
            scale deployment -n production --all --replicas=3
          
          # Step 3: Wait for pods to be ready
          echo "Step 3: Waiting for pods..."
          kubectl --kubeconfig=/etc/kubeconfig/dr-cluster \
            wait --for=condition=ready pod -n production -l tier=web --timeout=300s
          
          # Step 4: Promote database replica
          echo "Step 4: Promoting database..."
          kubectl --kubeconfig=/etc/kubeconfig/dr-cluster \
            cnpg promote postgres-replica -n production
          
          # Step 5: Update external DNS/LB
          echo "Step 5: Updating traffic routing..."
          # This would call external DNS update API
          
          # Step 6: Verify services
          echo "Step 6: Verifying services..."
          kubectl --kubeconfig=/etc/kubeconfig/dr-cluster \
            get pods -n production
          
          echo "=== Failover Complete ==="
        volumeMounts:
        - name: kubeconfig
          mountPath: /etc/kubeconfig
          readOnly: true
      volumes:
      - name: kubeconfig
        secret:
          secretName: dr-cluster-kubeconfig
      restartPolicy: Never
  backoffLimit: 1
```

---

## Part 4: DR Runbooks

### Comprehensive DR Runbook

```yaml
# dr-runbook.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dr-runbook
  namespace: disaster-recovery
data:
  runbook.md: |
    # Disaster Recovery Runbook
    
    ## Document Control
    - **Version:** 2.1
    - **Last Updated:** 2024-02-01
    - **Owner:** Platform Team
    - **Approved By:** CTO
    
    ---
    
    ## 1. Overview
    
    This runbook provides step-by-step procedures for disaster recovery 
    operations. Follow these procedures exactly as written.
    
    ### 1.1 DR Sites
    
    | Site | Region | Role | Capacity |
    |------|--------|------|----------|
    | Primary | us-east-1 | Production | 100% |
    | DR | us-west-2 | Standby | 50% (scalable) |
    
    ### 1.2 Contact Information
    
    | Role | Name | Phone | Email |
    |------|------|-------|-------|
    | DR Lead | John Smith | +1-555-0100 | john@example.com |
    | DBA | Jane Doe | +1-555-0101 | jane@example.com |
    | Network | Bob Wilson | +1-555-0102 | bob@example.com |
    | On-Call | PagerDuty | N/A | oncall@example.com |
    
    ---
    
    ## 2. Disaster Declaration
    
    ### 2.1 Criteria for DR Declaration
    
    Declare disaster if ANY of the following:
    - [ ] Primary region completely unavailable > 15 minutes
    - [ ] Primary database corruption detected
    - [ ] Security breach requiring primary isolation
    - [ ] Natural disaster affecting primary data center
    
    ### 2.2 Authorization
    
    DR declaration requires approval from:
    - [ ] VP of Engineering OR
    - [ ] CTO OR
    - [ ] On-call Director
    
    ### 2.3 Declaration Steps
    
    1. Confirm disaster criteria met
    2. Get verbal authorization
    3. Document authorization: _______________
    4. Notify all stakeholders via PagerDuty
    5. Begin failover procedures
    
    ---
    
    ## 3. Failover Procedure
    
    **Estimated Time:** 30-45 minutes
    
    ### 3.1 Pre-Failover Checklist
    
    - [ ] DR declaration authorized
    - [ ] DR team assembled
    - [ ] Communication channel established (Slack: #dr-war-room)
    - [ ] DR site health verified
    - [ ] Last backup status confirmed
    
    ### 3.2 Database Failover
    
    **Responsible:** DBA Team
    **Time:** 10-15 minutes
    
    ```bash
    # 1. Check replication lag
    kubectl --context dr-cluster exec -n production \
      postgres-replica-0 -- psql -c "SELECT pg_last_wal_receive_lsn();"
    
    # 2. Promote replica to primary
    kubectl --context dr-cluster cnpg promote postgres-replica -n production
    
    # 3. Verify promotion
    kubectl --context dr-cluster get cluster postgres-replica -n production
    
    # 4. Update application database endpoints
    kubectl --context dr-cluster patch configmap app-config -n production \
      --patch '{"data":{"DATABASE_HOST":"postgres-replica-rw"}}'
    ```
    
    - [ ] Replica promoted
    - [ ] New primary accepting writes
    - [ ] Application configs updated
    
    ### 3.3 Application Failover
    
    **Responsible:** Platform Team
    **Time:** 10 minutes
    
    ```bash
    # 1. Scale up DR deployments
    kubectl --context dr-cluster scale deployment -n production \
      api-server --replicas=5
    kubectl --context dr-cluster scale deployment -n production \
      worker --replicas=3
    
    # 2. Verify pod health
    kubectl --context dr-cluster get pods -n production
    kubectl --context dr-cluster wait --for=condition=ready \
      pod -l app=api-server -n production --timeout=300s
    
    # 3. Run smoke tests
    kubectl --context dr-cluster run smoke-test --rm -it \
      --image=curlimages/curl -- curl http://api-server.production.svc/health
    ```
    
    - [ ] All deployments scaled
    - [ ] Pods healthy
    - [ ] Smoke tests passing
    
    ### 3.4 Traffic Failover
    
    **Responsible:** Network Team
    **Time:** 5 minutes
    
    ```bash
    # 1. Update Route53 records
    aws route53 change-resource-record-sets \
      --hosted-zone-id Z1234567890ABC \
      --change-batch file://dns-failover.json
    
    # 2. Verify DNS propagation
    dig api.example.com +short
    
    # 3. Monitor traffic shift
    # Check CloudWatch/Grafana for traffic metrics
    ```
    
    - [ ] DNS updated
    - [ ] Traffic flowing to DR
    - [ ] No errors in logs
    
    ### 3.5 Post-Failover Verification
    
    **Time:** 10 minutes
    
    - [ ] All critical services responding
    - [ ] Database read/write operations working
    - [ ] External integrations functional
    - [ ] Monitoring and alerting active
    - [ ] Customer-facing services accessible
    
    ---
    
    ## 4. Failback Procedure
    
    **Prerequisite:** Primary site fully recovered and tested
    **Estimated Time:** 2-4 hours
    
    ### 4.1 Pre-Failback Checklist
    
    - [ ] Primary site health verified
    - [ ] Data sync from DR to Primary complete
    - [ ] Maintenance window scheduled
    - [ ] Stakeholders notified
    
    ### 4.2 Data Synchronization
    
    ```bash
    # 1. Create backup of current DR state
    velero backup create pre-failback-$(date +%s) \
      --include-namespaces production \
      --wait
    
    # 2. Sync database to primary
    pg_dump -h dr-postgres -U admin production | \
      psql -h primary-postgres -U admin production
    
    # 3. Verify data integrity
    # Run data validation queries
    ```
    
    ### 4.3 Execute Failback
    
    Follow failover procedure in reverse:
    1. Traffic to primary
    2. Application switchover
    3. Database switchover
    4. Verify all services
    
    ---
    
    ## 5. Communication Templates
    
    ### 5.1 Internal Notification
    
    ```
    Subject: [DR ACTIVATED] Production Failover in Progress
    
    Team,
    
    We are initiating disaster recovery procedures.
    
    - Status: Failover in progress
    - Reason: [REASON]
    - Expected Duration: 30-45 minutes
    - War Room: #dr-war-room
    
    Updates will be provided every 15 minutes.
    ```
    
    ### 5.2 Customer Notification
    
    ```
    Subject: Service Disruption Notice
    
    We are currently experiencing a service disruption.
    Our team is actively working to restore full service.
    
    - Status: Degraded
    - Affected Services: [LIST]
    - Estimated Resolution: [TIME]
    
    Updates: status.example.com
    ```
    
    ---
    
    ## 6. Post-Incident Review
    
    Complete within 48 hours of incident:
    
    - [ ] Timeline documented
    - [ ] Root cause identified
    - [ ] Action items created
    - [ ] Runbook updates identified
    - [ ] Stakeholder debrief scheduled
```

---

## Part 5: DR Testing and Drills

### DR Drill Framework

```yaml
# dr-drill-framework.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dr-drill-framework
  namespace: disaster-recovery
data:
  drill-plan.yaml: |
    # DR Drill Plan
    
    drill_types:
      tabletop:
        description: "Discussion-based walkthrough"
        frequency: monthly
        duration: 2 hours
        participants:
          - engineering leads
          - dba team
          - sre team
        objectives:
          - Review runbooks
          - Identify gaps
          - Update contacts
      
      component:
        description: "Test individual components"
        frequency: monthly
        duration: 2 hours
        participants:
          - component owners
        objectives:
          - Database failover
          - DNS switching
          - Backup restoration
      
      partial:
        description: "Limited scope failover"
        frequency: quarterly
        duration: 4 hours
        participants:
          - full dr team
        objectives:
          - Non-critical services failover
          - Data replication verification
          - Runbook validation
      
      full:
        description: "Complete failover drill"
        frequency: annually
        duration: 8 hours
        participants:
          - all stakeholders
        objectives:
          - Full production failover
          - RTO/RPO measurement
          - Complete runbook execution
    
    drill_checklist:
      before:
        - [ ] Drill scheduled and communicated
        - [ ] Participants confirmed
        - [ ] Success criteria defined
        - [ ] Rollback plan ready
        - [ ] Monitoring enhanced
      
      during:
        - [ ] Start time recorded
        - [ ] Each step timed
        - [ ] Issues documented
        - [ ] Communications logged
      
      after:
        - [ ] End time recorded
        - [ ] RTO/RPO calculated
        - [ ] Issues reviewed
        - [ ] Action items created
        - [ ] Report distributed
```

### Automated DR Drill Job

```yaml
# dr-drill-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: dr-drill-automated
  namespace: disaster-recovery
  labels:
    drill-type: component
spec:
  template:
    spec:
      serviceAccountName: dr-drill
      containers:
      - name: drill
        image: dr-drill-runner:latest
        command:
        - /bin/bash
        - -c
        - |
          set -e
          
          DRILL_ID="drill-$(date +%Y%m%d-%H%M%S)"
          RESULTS_FILE="/results/${DRILL_ID}.json"
          
          echo "=== DR Drill Started: $DRILL_ID ==="
          
          # Initialize results
          echo '{"drill_id": "'$DRILL_ID'", "steps": []}' > $RESULTS_FILE
          
          record_step() {
            local name=$1
            local status=$2
            local duration=$3
            jq '.steps += [{"name": "'$name'", "status": "'$status'", "duration_seconds": '$duration'}]' \
              $RESULTS_FILE > /tmp/results.json && mv /tmp/results.json $RESULTS_FILE
          }
          
          # Step 1: Verify DR cluster health
          echo "Step 1: Checking DR cluster health..."
          START=$(date +%s)
          kubectl --kubeconfig=/etc/kubeconfig/dr get nodes
          if [ $? -eq 0 ]; then
            record_step "dr_cluster_health" "pass" $(($(date +%s) - START))
          else
            record_step "dr_cluster_health" "fail" $(($(date +%s) - START))
            exit 1
          fi
          
          # Step 2: Test backup restoration
          echo "Step 2: Testing backup restoration..."
          START=$(date +%s)
          velero restore create drill-restore-$DRILL_ID \
            --from-backup daily-backup \
            --namespace-mappings "production:drill-test" \
            --wait
          if [ $? -eq 0 ]; then
            record_step "backup_restore" "pass" $(($(date +%s) - START))
          else
            record_step "backup_restore" "fail" $(($(date +%s) - START))
          fi
          
          # Step 3: Verify restored data
          echo "Step 3: Verifying restored data..."
          START=$(date +%s)
          kubectl --kubeconfig=/etc/kubeconfig/dr \
            get pods -n drill-test -l app=api-server
          record_step "data_verification" "pass" $(($(date +%s) - START))
          
          # Step 4: Test database connectivity
          echo "Step 4: Testing database..."
          START=$(date +%s)
          kubectl --kubeconfig=/etc/kubeconfig/dr \
            exec -n drill-test deploy/api-server -- \
            curl -s localhost:8080/health/db
          record_step "database_connectivity" "pass" $(($(date +%s) - START))
          
          # Cleanup
          echo "Cleaning up drill resources..."
          kubectl --kubeconfig=/etc/kubeconfig/dr delete namespace drill-test
          velero restore delete drill-restore-$DRILL_ID --confirm
          
          # Generate report
          echo "=== Drill Results ==="
          cat $RESULTS_FILE | jq .
          
          # Send results
          curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d @$RESULTS_FILE
          
          echo "=== DR Drill Complete ==="
        env:
        - name: WEBHOOK_URL
          valueFrom:
            secretKeyRef:
              name: drill-config
              key: webhook-url
        volumeMounts:
        - name: kubeconfig
          mountPath: /etc/kubeconfig
        - name: results
          mountPath: /results
      volumes:
      - name: kubeconfig
        secret:
          secretName: dr-kubeconfig
      - name: results
        emptyDir: {}
      restartPolicy: Never
  backoffLimit: 0
```

### DR Metrics Dashboard

```yaml
# dr-metrics-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dr-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  dr-dashboard.json: |
    {
      "dashboard": {
        "title": "Disaster Recovery Status",
        "panels": [
          {
            "title": "Replication Lag",
            "type": "gauge",
            "gridPos": {"x": 0, "y": 0, "w": 6, "h": 6},
            "targets": [
              {
                "expr": "pg_replication_lag_seconds"
              }
            ],
            "options": {
              "thresholds": {
                "steps": [
                  {"value": 0, "color": "green"},
                  {"value": 60, "color": "yellow"},
                  {"value": 300, "color": "red"}
                ]
              }
            }
          },
          {
            "title": "Last Backup Age",
            "type": "stat",
            "gridPos": {"x": 6, "y": 0, "w": 6, "h": 6},
            "targets": [
              {
                "expr": "(time() - velero_backup_last_successful_timestamp) / 3600",
                "legendFormat": "Hours since last backup"
              }
            ]
          },
          {
            "title": "DR Site Health",
            "type": "stat",
            "gridPos": {"x": 12, "y": 0, "w": 6, "h": 6},
            "targets": [
              {
                "expr": "up{job='dr-health-check'}"
              }
            ],
            "options": {
              "colorMode": "background",
              "mappings": [
                {"value": 1, "text": "HEALTHY", "color": "green"},
                {"value": 0, "text": "UNHEALTHY", "color": "red"}
              ]
            }
          },
          {
            "title": "Last DR Drill Results",
            "type": "table",
            "gridPos": {"x": 0, "y": 6, "w": 12, "h": 8},
            "targets": [
              {
                "expr": "dr_drill_step_duration_seconds",
                "format": "table"
              }
            ]
          },
          {
            "title": "RTO Trend",
            "type": "timeseries",
            "gridPos": {"x": 12, "y": 6, "w": 12, "h": 8},
            "targets": [
              {
                "expr": "dr_drill_total_duration_seconds",
                "legendFormat": "Actual RTO"
              },
              {
                "expr": "900",
                "legendFormat": "Target RTO (15 min)"
              }
            ]
          }
        ]
      }
    }
```

---

## 🎯 Practical Exercises

### Exercise 1: DR Strategy Design

1. Define RTO/RPO for a sample application
2. Choose appropriate DR tier
3. Design architecture diagram
4. Calculate cost estimates
5. Create implementation plan

### Exercise 2: Failover Procedure Implementation

1. Set up two clusters (Kind)
2. Configure shared backup storage
3. Deploy application with database
4. Create failover scripts
5. Execute complete failover
6. Verify data consistency

### Exercise 3: DR Drill Execution

1. Create drill schedule
2. Write drill checklist
3. Execute tabletop exercise
4. Document findings
5. Update runbooks based on learnings

---

## 📚 Key Takeaways

### DR Strategy Selection

| Requirement | Recommended Strategy |
|-------------|---------------------|
| RTO < 1 min | Active-Active |
| RTO < 15 min | Hot Standby |
| RTO < 4 hours | Warm Standby |
| RTO < 24 hours | Pilot Light |
| RTO > 24 hours | Backup/Restore |

### DR Best Practices

1. **Document everything** - Runbooks must be current
2. **Test regularly** - Untested DR is not DR
3. **Automate failover** - Reduce human error
4. **Monitor replication** - Know your RPO reality
5. **Practice, practice, practice** - Drills build muscle memory

---

## ✅ Lab Checklist

Before completing this lab, verify:

- [ ] Understand RTO/RPO concepts
- [ ] Can design DR strategy for requirements
- [ ] Multi-region architecture understood
- [ ] Failover procedures documented
- [ ] DR runbook created
- [ ] DR drill framework implemented
- [ ] Metrics and monitoring configured

---

## Next Steps

Continue to [Lab 4: Chaos Engineering →](../lab-04-chaos-engineering/README.md)
