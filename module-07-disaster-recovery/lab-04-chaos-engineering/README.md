# Lab 4: Chaos Engineering

## 🎯 Objectives

By the end of this lab, you will:
- Understand chaos engineering principles
- Deploy and use Litmus Chaos
- Implement Chaos Mesh experiments
- Design GameDay exercises
- Build resilience through controlled failure injection

## ⏱️ Estimated Time: 90 minutes

---

## Part 1: Chaos Engineering Fundamentals

### What is Chaos Engineering?

```
┌─────────────────────────────────────────────────────────────────┐
│                  Chaos Engineering Principles                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  "Chaos Engineering is the discipline of experimenting on a      │
│   system in order to build confidence in the system's            │
│   capability to withstand turbulent conditions in production."   │
│                                              - Principles of CE  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    The Scientific Method                     │ │
│  │                                                               │ │
│  │  1. Define steady state                                      │ │
│  │     └─ What does "normal" look like?                         │ │
│  │                                                               │ │
│  │  2. Form hypothesis                                          │ │
│  │     └─ "System will remain stable when X fails"              │ │
│  │                                                               │ │
│  │  3. Introduce variables (chaos)                              │ │
│  │     └─ Inject failure X                                      │ │
│  │                                                               │ │
│  │  4. Observe results                                          │ │
│  │     └─ Did steady state change?                              │ │
│  │                                                               │ │
│  │  5. Improve or validate                                      │ │
│  │     └─ Fix issues or confirm resilience                      │ │
│  │                                                               │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Key Principles:                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  ✓ Build hypothesis around steady state behavior            │ │
│  │  ✓ Vary real-world events                                   │ │
│  │  ✓ Run experiments in production                            │ │
│  │  ✓ Automate experiments to run continuously                 │ │
│  │  ✓ Minimize blast radius                                    │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Types of Chaos Experiments

```
┌─────────────────────────────────────────────────────────────────┐
│                    Chaos Experiment Categories                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Infrastructure                    Application                   │
│  ┌─────────────────────┐          ┌─────────────────────┐       │
│  │ • Node failure      │          │ • Pod termination   │       │
│  │ • Disk failure      │          │ • Container crash   │       │
│  │ • Network partition │          │ • CPU stress        │       │
│  │ • Zone outage       │          │ • Memory pressure   │       │
│  │ • DNS failure       │          │ • I/O latency       │       │
│  └─────────────────────┘          └─────────────────────┘       │
│                                                                   │
│  Network                           State                         │
│  ┌─────────────────────┐          ┌─────────────────────┐       │
│  │ • Latency injection │          │ • Database failure  │       │
│  │ • Packet loss       │          │ • Cache eviction    │       │
│  │ • Bandwidth limit   │          │ • Queue overflow    │       │
│  │ • Port block        │          │ • State corruption  │       │
│  │ • DNS manipulation  │          │ • Clock skew        │       │
│  └─────────────────────┘          └─────────────────────┘       │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Safety Guidelines

```yaml
# chaos-safety-guidelines.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: chaos-safety-guidelines
data:
  guidelines.md: |
    # Chaos Engineering Safety Guidelines
    
    ## ⚠️ CRITICAL RULES ⚠️
    
    1. **NEVER** run chaos in production without:
       - Proper approval from stakeholders
       - Monitoring and alerting in place
       - Rollback procedures ready
       - Team on standby
    
    2. **ALWAYS** start in non-production
       - Dev → Staging → Production
       - Increase blast radius gradually
    
    3. **MINIMIZE** blast radius
       - Start with single pod/container
       - Limit duration
       - Limit scope (namespace, labels)
    
    4. **HAVE** kill switches ready
       - Know how to stop experiments immediately
       - Test abort procedures
    
    5. **INFORM** stakeholders
       - Notify before experiments
       - Have communication channels ready
    
    ## Maturity Levels
    
    | Level | Environment | Scope | Automation |
    |-------|-------------|-------|------------|
    | 1 | Dev only | Single pod | Manual |
    | 2 | Staging | Namespace | Scheduled |
    | 3 | Prod (off-peak) | Service | CI/CD |
    | 4 | Prod (anytime) | Cross-service | Continuous |
```

---

## Part 2: Litmus Chaos

### Install Litmus Chaos

```bash
# Add Litmus Helm repository
helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
helm repo update

# Create namespace
kubectl create namespace litmus

# Install Litmus
helm install litmus litmuschaos/litmus \
  --namespace litmus \
  --set portal.frontend.service.type=ClusterIP \
  --set portal.server.service.type=ClusterIP

# Wait for installation
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=litmus-frontend -n litmus --timeout=300s

# Access Litmus Portal
kubectl port-forward svc/litmusportal-frontend-service -n litmus 9091:9091
# Default credentials: admin / litmus
```

### Install Chaos Experiments

```bash
# Install chaos experiments for Kubernetes
kubectl apply -f https://hub.litmuschaos.io/api/chaos/3.0.0?file=charts/generic/experiments.yaml -n litmus

# Verify experiments installed
kubectl get chaosexperiments -n litmus
```

### Pod Delete Experiment

```yaml
# pod-delete-experiment.yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: nginx-pod-delete
  namespace: default
spec:
  # Application under test
  appinfo:
    appns: default
    applabel: "app=nginx"
    appkind: deployment
  
  # Chaos experiment settings
  engineState: "active"
  chaosServiceAccount: litmus-admin
  
  experiments:
  - name: pod-delete
    spec:
      components:
        env:
          # Target specific pods
          - name: TARGET_PODS
            value: ""  # Empty = random selection
          
          # Number of pods to kill
          - name: PODS_AFFECTED_PERC
            value: "50"
          
          # Duration of chaos
          - name: TOTAL_CHAOS_DURATION
            value: "60"
          
          # Interval between pod kills
          - name: CHAOS_INTERVAL
            value: "10"
          
          # Force delete
          - name: FORCE
            value: "false"
          
          # Sequence of chaos
          - name: SEQUENCE
            value: "parallel"  # or "serial"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: litmus-admin
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: litmus-admin
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec", "pods/log", "events", "replicationcontrollers"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["litmuschaos.io"]
  resources: ["chaosengines", "chaosexperiments", "chaosresults"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: litmus-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: litmus-admin
subjects:
- kind: ServiceAccount
  name: litmus-admin
  namespace: default
```

### Network Chaos Experiment

```yaml
# network-chaos-experiment.yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: network-loss
  namespace: default
spec:
  appinfo:
    appns: default
    applabel: "app=web-api"
    appkind: deployment
  
  engineState: "active"
  chaosServiceAccount: litmus-admin
  
  experiments:
  - name: pod-network-loss
    spec:
      components:
        env:
          # Network loss percentage
          - name: NETWORK_PACKET_LOSS_PERCENTAGE
            value: "30"
          
          # Target network interface
          - name: NETWORK_INTERFACE
            value: "eth0"
          
          # Duration
          - name: TOTAL_CHAOS_DURATION
            value: "120"
          
          # Container to target
          - name: TARGET_CONTAINER
            value: ""  # Empty = first container
          
          # Destination IPs/hosts to affect
          - name: DESTINATION_IPS
            value: ""
          
          - name: DESTINATION_HOSTS
            value: "database.default.svc.cluster.local"
---
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: network-latency
  namespace: default
spec:
  appinfo:
    appns: default
    applabel: "app=web-api"
    appkind: deployment
  
  engineState: "active"
  chaosServiceAccount: litmus-admin
  
  experiments:
  - name: pod-network-latency
    spec:
      components:
        env:
          # Latency in milliseconds
          - name: NETWORK_LATENCY
            value: "200"
          
          # Jitter
          - name: JITTER
            value: "50"
          
          - name: NETWORK_INTERFACE
            value: "eth0"
          
          - name: TOTAL_CHAOS_DURATION
            value: "120"
          
          - name: DESTINATION_HOSTS
            value: "database.default.svc.cluster.local"
```

### CPU and Memory Stress

```yaml
# stress-experiment.yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: cpu-stress
  namespace: default
spec:
  appinfo:
    appns: default
    applabel: "app=compute-heavy"
    appkind: deployment
  
  engineState: "active"
  chaosServiceAccount: litmus-admin
  
  experiments:
  - name: pod-cpu-hog
    spec:
      components:
        env:
          # Number of CPU cores to consume
          - name: CPU_CORES
            value: "2"
          
          # CPU load percentage (per core)
          - name: CPU_LOAD
            value: "80"
          
          - name: TOTAL_CHAOS_DURATION
            value: "60"
          
          - name: TARGET_PODS
            value: ""
          
          - name: PODS_AFFECTED_PERC
            value: "50"
---
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: memory-stress
  namespace: default
spec:
  appinfo:
    appns: default
    applabel: "app=memory-heavy"
    appkind: deployment
  
  engineState: "active"
  chaosServiceAccount: litmus-admin
  
  experiments:
  - name: pod-memory-hog
    spec:
      components:
        env:
          # Memory consumption in MB
          - name: MEMORY_CONSUMPTION
            value: "500"
          
          # Or percentage of available memory
          - name: MEMORY_PERCENTAGE
            value: ""
          
          - name: TOTAL_CHAOS_DURATION
            value: "60"
          
          - name: NUMBER_OF_WORKERS
            value: "1"
```

### Monitor Chaos Results

```bash
# Check chaos engine status
kubectl get chaosengine -n default

# Get detailed results
kubectl get chaosresult -n default -o yaml

# Watch chaos execution
kubectl get pods -n default -w

# Describe chaos engine
kubectl describe chaosengine nginx-pod-delete -n default
```

---

## Part 3: Chaos Mesh

### Install Chaos Mesh

```bash
# Add Chaos Mesh Helm repository
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Create namespace
kubectl create namespace chaos-mesh

# Install Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace chaos-mesh \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
  --set dashboard.securityMode=false

# Wait for installation
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=chaos-dashboard -n chaos-mesh --timeout=300s

# Access dashboard
kubectl port-forward svc/chaos-dashboard -n chaos-mesh 2333:2333
```

### Pod Chaos with Chaos Mesh

```yaml
# pod-chaos.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-failure
  namespace: chaos-mesh
spec:
  action: pod-failure
  mode: one  # one, all, fixed, fixed-percent, random-max-percent
  selector:
    namespaces:
      - default
    labelSelectors:
      app: nginx
  duration: "60s"
---
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill
  namespace: chaos-mesh
spec:
  action: pod-kill
  mode: fixed-percent
  value: "50"  # Kill 50% of pods
  selector:
    namespaces:
      - default
    labelSelectors:
      app: nginx
  gracePeriod: 0  # Force kill
---
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: container-kill
  namespace: chaos-mesh
spec:
  action: container-kill
  mode: one
  selector:
    namespaces:
      - default
    labelSelectors:
      app: multi-container-app
  containerNames:
    - sidecar
  duration: "30s"
```

### Network Chaos with Chaos Mesh

```yaml
# network-chaos.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-delay
  namespace: chaos-mesh
spec:
  action: delay
  mode: all
  selector:
    namespaces:
      - default
    labelSelectors:
      app: web-api
  delay:
    latency: "100ms"
    correlation: "25"
    jitter: "50ms"
  duration: "120s"
  direction: to
  target:
    selector:
      namespaces:
        - default
      labelSelectors:
        app: database
    mode: all
---
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-partition
  namespace: chaos-mesh
spec:
  action: partition
  mode: all
  selector:
    namespaces:
      - default
    labelSelectors:
      app: service-a
  direction: both
  target:
    selector:
      namespaces:
        - default
      labelSelectors:
        app: service-b
    mode: all
  duration: "60s"
---
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-loss
  namespace: chaos-mesh
spec:
  action: loss
  mode: fixed-percent
  value: "30"
  selector:
    namespaces:
      - default
    labelSelectors:
      app: web-api
  loss:
    loss: "25"
    correlation: "25"
  duration: "60s"
---
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: bandwidth-limit
  namespace: chaos-mesh
spec:
  action: bandwidth
  mode: all
  selector:
    namespaces:
      - default
    labelSelectors:
      app: web-api
  bandwidth:
    rate: "1mbps"
    limit: 100
    buffer: 10000
  duration: "120s"
```

### Stress Chaos

```yaml
# stress-chaos.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: cpu-stress
  namespace: chaos-mesh
spec:
  mode: all
  selector:
    namespaces:
      - default
    labelSelectors:
      app: compute-service
  stressors:
    cpu:
      workers: 2
      load: 80
  duration: "60s"
---
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: memory-stress
  namespace: chaos-mesh
spec:
  mode: one
  selector:
    namespaces:
      - default
    labelSelectors:
      app: memory-service
  stressors:
    memory:
      workers: 2
      size: "256MB"
  duration: "60s"
```

### IO Chaos

```yaml
# io-chaos.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-latency
  namespace: chaos-mesh
spec:
  action: latency
  mode: all
  selector:
    namespaces:
      - default
    labelSelectors:
      app: database
  volumePath: /var/lib/postgresql/data
  path: "*"
  delay: "100ms"
  percent: 50
  duration: "120s"
---
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-fault
  namespace: chaos-mesh
spec:
  action: fault
  mode: one
  selector:
    namespaces:
      - default
    labelSelectors:
      app: storage-service
  volumePath: /data
  path: "*.log"
  errno: 5  # EIO
  percent: 100
  duration: "30s"
```

### Time Chaos

```yaml
# time-chaos.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: TimeChaos
metadata:
  name: time-skew
  namespace: chaos-mesh
spec:
  mode: all
  selector:
    namespaces:
      - default
    labelSelectors:
      app: scheduler
  timeOffset: "-2h"  # Shift time back 2 hours
  duration: "120s"
```

### Scheduled Chaos with Workflows

```yaml
# chaos-workflow.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: resilience-test
  namespace: chaos-mesh
spec:
  entry: main
  templates:
    - name: main
      templateType: Serial
      deadline: 30m
      children:
        - network-test
        - pod-test
        - stress-test
    
    - name: network-test
      templateType: Parallel
      children:
        - network-delay
        - network-loss
    
    - name: network-delay
      templateType: NetworkChaos
      deadline: 5m
      networkChaos:
        action: delay
        mode: all
        selector:
          namespaces:
            - default
          labelSelectors:
            app: web-api
        delay:
          latency: "100ms"
        duration: "2m"
    
    - name: network-loss
      templateType: NetworkChaos
      deadline: 5m
      networkChaos:
        action: loss
        mode: all
        selector:
          namespaces:
            - default
          labelSelectors:
            app: web-api
        loss:
          loss: "10"
        duration: "2m"
    
    - name: pod-test
      templateType: PodChaos
      deadline: 5m
      podChaos:
        action: pod-kill
        mode: fixed-percent
        value: "30"
        selector:
          namespaces:
            - default
          labelSelectors:
            app: web-api
    
    - name: stress-test
      templateType: StressChaos
      deadline: 5m
      stressChaos:
        mode: all
        selector:
          namespaces:
            - default
          labelSelectors:
            app: web-api
        stressors:
          cpu:
            workers: 1
            load: 50
        duration: "2m"
---
apiVersion: chaos-mesh.org/v1alpha1
kind: Schedule
metadata:
  name: weekly-chaos
  namespace: chaos-mesh
spec:
  schedule: "0 10 * * 1"  # Every Monday at 10 AM
  type: Workflow
  historyLimit: 5
  concurrencyPolicy: Forbid
  workflow:
    entry: main
    templates:
      - name: main
        templateType: PodChaos
        deadline: 10m
        podChaos:
          action: pod-kill
          mode: one
          selector:
            namespaces:
              - staging
            labelSelectors:
              app: api
```

---

## Part 4: GameDay Exercises

### GameDay Framework

```yaml
# gameday-framework.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gameday-framework
  namespace: chaos-mesh
data:
  gameday-template.md: |
    # GameDay Exercise Template
    
    ## Overview
    
    | Field | Value |
    |-------|-------|
    | GameDay ID | GD-YYYY-MM-DD |
    | Date | |
    | Duration | 4 hours |
    | Scope | Production/Staging |
    | Participants | |
    
    ## Objectives
    
    1. Validate system resilience to [failure type]
    2. Test runbook accuracy and completeness
    3. Measure incident response time
    4. Identify improvement opportunities
    
    ## Pre-GameDay Checklist
    
    - [ ] Stakeholder approval obtained
    - [ ] Participants briefed
    - [ ] Monitoring dashboards prepared
    - [ ] Communication channels ready (#gameday-war-room)
    - [ ] Kill switches tested
    - [ ] Rollback procedures ready
    - [ ] Customer notification prepared (if needed)
    
    ## Scenarios
    
    ### Scenario 1: Database Failover
    
    **Hypothesis:** The system will automatically failover to replica
    database within 30 seconds with no data loss.
    
    **Steps:**
    1. Baseline metrics captured
    2. Primary database killed
    3. Observe failover behavior
    4. Verify data consistency
    5. Restore primary
    
    **Success Criteria:**
    - Failover completes in < 30 seconds
    - No 5xx errors to customers
    - No data loss
    
    ### Scenario 2: Service Degradation
    
    **Hypothesis:** Circuit breakers will activate when downstream
    service latency exceeds 1 second.
    
    **Steps:**
    1. Inject 2 second latency to payment-service
    2. Observe circuit breaker behavior
    3. Verify fallback responses
    4. Remove latency injection
    5. Observe circuit recovery
    
    **Success Criteria:**
    - Circuit opens within 10 seconds
    - Fallback returns cached/default response
    - Circuit closes after recovery
    
    ## Execution Log
    
    | Time | Action | Observation | Notes |
    |------|--------|-------------|-------|
    | | | | |
    
    ## Metrics to Track
    
    - Request success rate
    - P99 latency
    - Error rate
    - Pod restarts
    - Database replication lag
    - Circuit breaker state
    
    ## Post-GameDay Review
    
    ### What Went Well
    1.
    2.
    
    ### What Could Be Improved
    1.
    2.
    
    ### Action Items
    
    | Item | Owner | Due Date |
    |------|-------|----------|
    | | | |
    
    ### Runbook Updates Required
    1.
    2.
```

### GameDay Automation Script

```bash
#!/bin/bash
# gameday-runner.sh - Automated GameDay execution

set -euo pipefail

# Configuration
GAMEDAY_ID="GD-$(date +%Y-%m-%d)"
LOG_DIR="/tmp/gameday/${GAMEDAY_ID}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
DURATION_SECONDS="${DURATION_SECONDS:-300}"

mkdir -p "$LOG_DIR"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_DIR/gameday.log"
}

notify() {
    local message=$1
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"🎮 GameDay: $message\"}" || true
    fi
}

capture_metrics() {
    local phase=$1
    log "Capturing metrics for phase: $phase"
    
    # Capture pod states
    kubectl get pods -A -o wide > "$LOG_DIR/pods-${phase}.txt"
    
    # Capture events
    kubectl get events -A --sort-by='.lastTimestamp' | tail -100 > "$LOG_DIR/events-${phase}.txt"
    
    # Capture resource usage
    kubectl top pods -A > "$LOG_DIR/resources-${phase}.txt" 2>/dev/null || true
}

wait_for_steady_state() {
    log "Waiting for steady state..."
    local ready_pods
    for i in {1..30}; do
        ready_pods=$(kubectl get pods -n default -o jsonpath='{.items[*].status.phase}' | tr ' ' '\n' | grep -c Running || true)
        total_pods=$(kubectl get pods -n default --no-headers | wc -l)
        if [ "$ready_pods" -eq "$total_pods" ]; then
            log "Steady state achieved: $ready_pods/$total_pods pods running"
            return 0
        fi
        sleep 10
    done
    log "WARNING: Steady state not achieved"
    return 1
}

run_scenario() {
    local name=$1
    local chaos_file=$2
    
    log "=== Starting Scenario: $name ==="
    notify "Starting scenario: $name"
    
    # Capture baseline
    capture_metrics "baseline-${name}"
    
    # Apply chaos
    log "Applying chaos experiment..."
    kubectl apply -f "$chaos_file"
    
    # Monitor during chaos
    local end_time=$(($(date +%s) + DURATION_SECONDS))
    while [ $(date +%s) -lt $end_time ]; do
        log "Chaos in progress... $(( end_time - $(date +%s) ))s remaining"
        
        # Check for critical failures
        error_count=$(kubectl get pods -n default | grep -c Error || true)
        if [ "$error_count" -gt 5 ]; then
            log "ERROR: Too many pod errors, aborting chaos"
            kubectl delete -f "$chaos_file" --ignore-not-found
            return 1
        fi
        
        sleep 30
    done
    
    # Capture chaos state
    capture_metrics "during-${name}"
    
    # Remove chaos
    log "Removing chaos experiment..."
    kubectl delete -f "$chaos_file" --ignore-not-found
    
    # Wait for recovery
    log "Waiting for recovery..."
    wait_for_steady_state
    
    # Capture recovery state
    capture_metrics "recovery-${name}"
    
    log "=== Scenario Complete: $name ==="
    notify "Scenario complete: $name"
}

generate_report() {
    log "Generating GameDay report..."
    
    cat > "$LOG_DIR/report.md" << EOF
# GameDay Report: $GAMEDAY_ID

## Summary

- Date: $(date)
- Duration: ${DURATION_SECONDS}s per scenario

## Scenarios Executed

$(ls -1 "$LOG_DIR"/*.yaml 2>/dev/null | while read f; do
    echo "- $(basename $f .yaml)"
done)

## Metrics Summary

### Pod States

\`\`\`
$(cat "$LOG_DIR"/pods-*.txt | head -50)
\`\`\`

### Events

\`\`\`
$(cat "$LOG_DIR"/events-*.txt | tail -30)
\`\`\`

## Findings

(Add manual observations here)

## Action Items

- [ ] 
- [ ] 

EOF

    log "Report generated: $LOG_DIR/report.md"
}

# Main execution
main() {
    log "=== GameDay Started: $GAMEDAY_ID ==="
    notify "GameDay started: $GAMEDAY_ID"
    
    # Pre-flight checks
    log "Running pre-flight checks..."
    kubectl cluster-info
    wait_for_steady_state
    
    # Run scenarios
    if [ -d "./scenarios" ]; then
        for scenario in ./scenarios/*.yaml; do
            if [ -f "$scenario" ]; then
                cp "$scenario" "$LOG_DIR/"
                run_scenario "$(basename $scenario .yaml)" "$scenario"
                sleep 60  # Gap between scenarios
            fi
        done
    else
        log "No scenarios directory found. Running default pod-kill..."
        cat > "$LOG_DIR/default-chaos.yaml" << 'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: gameday-pod-kill
  namespace: chaos-mesh
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces:
      - default
    labelSelectors:
      app: nginx
EOF
        run_scenario "default-pod-kill" "$LOG_DIR/default-chaos.yaml"
    fi
    
    # Generate report
    generate_report
    
    log "=== GameDay Complete: $GAMEDAY_ID ==="
    notify "GameDay complete! Report: $LOG_DIR/report.md"
}

main "$@"
```

### GameDay Scenarios Library

```yaml
# scenarios/database-failover.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: database-primary-kill
  namespace: chaos-mesh
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces:
      - production
    labelSelectors:
      role: primary
      app: postgres
---
# scenarios/network-partition.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: api-database-partition
  namespace: chaos-mesh
spec:
  action: partition
  mode: all
  selector:
    namespaces:
      - production
    labelSelectors:
      tier: api
  direction: both
  target:
    selector:
      namespaces:
        - production
      labelSelectors:
        tier: database
    mode: all
  duration: "120s"
---
# scenarios/cascading-failure.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: cascading-failure-test
  namespace: chaos-mesh
spec:
  entry: cascading-test
  templates:
    - name: cascading-test
      templateType: Serial
      deadline: 20m
      children:
        - slow-database
        - circuit-breaker-test
        - recovery
    
    - name: slow-database
      templateType: NetworkChaos
      deadline: 5m
      networkChaos:
        action: delay
        mode: all
        selector:
          namespaces:
            - production
          labelSelectors:
            app: postgres
        delay:
          latency: "500ms"
        duration: "3m"
    
    - name: circuit-breaker-test
      templateType: StressChaos
      deadline: 5m
      stressChaos:
        mode: all
        selector:
          namespaces:
            - production
          labelSelectors:
            app: api-server
        stressors:
          cpu:
            workers: 2
            load: 90
        duration: "2m"
    
    - name: recovery
      templateType: Suspend
      deadline: 5m
      suspend:
        duration: "3m"
```

---

## Part 5: Observability During Chaos

### Chaos Monitoring Dashboard

```yaml
# chaos-dashboard-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-chaos-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  chaos-monitoring.json: |
    {
      "dashboard": {
        "title": "Chaos Engineering Monitoring",
        "uid": "chaos-monitoring",
        "panels": [
          {
            "title": "Active Chaos Experiments",
            "type": "stat",
            "gridPos": {"x": 0, "y": 0, "w": 6, "h": 4},
            "targets": [
              {
                "expr": "count(chaos_mesh_chaos_experiments{phase=\"Running\"})"
              }
            ]
          },
          {
            "title": "Pod Restart Rate",
            "type": "timeseries",
            "gridPos": {"x": 6, "y": 0, "w": 12, "h": 8},
            "targets": [
              {
                "expr": "sum(rate(kube_pod_container_status_restarts_total[5m])) by (namespace)",
                "legendFormat": "{{namespace}}"
              }
            ]
          },
          {
            "title": "Request Success Rate",
            "type": "gauge",
            "gridPos": {"x": 18, "y": 0, "w": 6, "h": 4},
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{status=~\"2..\"}[5m])) / sum(rate(http_requests_total[5m])) * 100"
              }
            ],
            "options": {
              "thresholds": {
                "steps": [
                  {"value": 0, "color": "red"},
                  {"value": 95, "color": "yellow"},
                  {"value": 99, "color": "green"}
                ]
              }
            }
          },
          {
            "title": "P99 Latency",
            "type": "timeseries",
            "gridPos": {"x": 0, "y": 8, "w": 12, "h": 8},
            "targets": [
              {
                "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))",
                "legendFormat": "{{service}}"
              }
            ]
          },
          {
            "title": "Error Rate by Service",
            "type": "timeseries",
            "gridPos": {"x": 12, "y": 8, "w": 12, "h": 8},
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) by (service)",
                "legendFormat": "{{service}}"
              }
            ]
          },
          {
            "title": "Chaos Events Timeline",
            "type": "logs",
            "gridPos": {"x": 0, "y": 16, "w": 24, "h": 8},
            "targets": [
              {
                "expr": "{namespace=\"chaos-mesh\"} | json | severity =~ \"warning|error\"",
                "queryType": "loki"
              }
            ]
          }
        ]
      }
    }
```

### Prometheus Alerting for Chaos

```yaml
# chaos-alerting-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: chaos-alerts
  namespace: monitoring
spec:
  groups:
  - name: chaos-safety
    rules:
    - alert: ChaosExperimentRunning
      expr: chaos_mesh_chaos_experiments{phase="Running"} > 0
      for: 0m
      labels:
        severity: info
      annotations:
        summary: "Chaos experiment running"
        description: "{{ $labels.name }} is currently running in {{ $labels.namespace }}"
    
    - alert: HighErrorRateDuringChaos
      expr: |
        (
          sum(rate(http_requests_total{status=~"5.."}[5m])) /
          sum(rate(http_requests_total[5m]))
        ) > 0.1
        and
        chaos_mesh_chaos_experiments{phase="Running"} > 0
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High error rate during chaos experiment"
        description: "Error rate is {{ $value | humanizePercentage }} while chaos is running"
    
    - alert: CriticalServiceDownDuringChaos
      expr: |
        up{job=~"critical-.*"} == 0
        and
        chaos_mesh_chaos_experiments{phase="Running"} > 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Critical service down during chaos"
        description: "{{ $labels.job }} is down - consider stopping chaos experiment"
    
    - alert: ChaosExperimentStuck
      expr: |
        chaos_mesh_chaos_experiments{phase="Running"}
        and
        (time() - chaos_mesh_chaos_experiment_start_time) > 3600
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Chaos experiment running too long"
        description: "{{ $labels.name }} has been running for over 1 hour"
```

---

## 🎯 Practical Exercises

### Exercise 1: First Chaos Experiment

1. Deploy a simple nginx application (3 replicas)
2. Install Chaos Mesh or Litmus
3. Create a pod-kill experiment
4. Observe application behavior
5. Verify self-healing

### Exercise 2: Network Resilience Testing

1. Deploy a multi-tier application (web → api → database)
2. Inject network latency between tiers
3. Verify circuit breaker behavior
4. Test with network partition
5. Document findings

### Exercise 3: GameDay Execution

1. Create GameDay plan with 3 scenarios
2. Set up monitoring dashboards
3. Execute scenarios with team
4. Document observations
5. Create action items for improvements

---

## 📚 Key Takeaways

### Chaos Engineering Maturity Model

| Level | Characteristics | Actions |
|-------|-----------------|---------|
| **1 - Initial** | Ad-hoc experiments, dev only | Start with simple pod kills |
| **2 - Managed** | Documented experiments, staging | Scheduled experiments |
| **3 - Defined** | Hypothesis-driven, production | Automated pipelines |
| **4 - Quantified** | Metrics-based, continuous | SLO-integrated |
| **5 - Optimizing** | Self-healing, predictive | AI-driven resilience |

### Tool Comparison

| Feature | Litmus Chaos | Chaos Mesh |
|---------|--------------|------------|
| UI | Portal | Dashboard |
| CRD-based | ✅ | ✅ |
| Kubernetes-native | ✅ | ✅ |
| Pre-built experiments | 50+ | 20+ |
| Workflows | ✅ | ✅ |
| Scheduling | ✅ | ✅ |
| RBAC | ✅ | ✅ |

---

## ✅ Lab Checklist

Before completing this lab, verify:

- [ ] Understand chaos engineering principles
- [ ] Litmus Chaos installed and working
- [ ] Chaos Mesh installed and working
- [ ] Created pod chaos experiments
- [ ] Created network chaos experiments
- [ ] Created stress experiments
- [ ] Implemented chaos workflows
- [ ] Created GameDay plan
- [ ] Monitoring during chaos configured

---

## Next Steps

Congratulations on completing Module 7! You've learned:

1. ✅ Backup strategies and etcd management
2. ✅ Velero for Kubernetes backup/restore
3. ✅ Disaster recovery planning
4. ✅ Chaos engineering with Litmus and Chaos Mesh

**Proceed to:** [Module 8: Production Operations →](../../module-08-production-operations/README.md)
