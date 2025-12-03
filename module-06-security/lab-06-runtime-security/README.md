# Lab 6: Runtime Security and Compliance

## 🎯 Objectives

By the end of this lab, you will:
- Deploy and configure Falco for runtime threat detection
- Implement custom Falco rules for security monitoring
- Run CIS Kubernetes benchmarks with kube-bench
- Perform security scanning with Kubescape
- Build automated compliance pipelines
- Create security dashboards and alerting

## ⏱️ Estimated Time: 90 minutes

---

## Part 1: Falco Fundamentals

### Understanding Falco

Falco is the de-facto runtime security tool for Kubernetes, detecting threats through syscall monitoring.

**Architecture Overview:**
```
┌─────────────────────────────────────────────────────────────────┐
│                         Falco Architecture                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Kubernetes Node                          │ │
│  │                                                              │ │
│  │   ┌─────────┐     ┌─────────┐     ┌─────────┐              │ │
│  │   │   Pod   │     │   Pod   │     │   Pod   │              │ │
│  │   └────┬────┘     └────┬────┘     └────┬────┘              │ │
│  │        │               │               │                     │ │
│  │        └───────────────┼───────────────┘                     │ │
│  │                        ▼                                      │ │
│  │   ┌──────────────────────────────────────┐                   │ │
│  │   │           System Calls                │                   │ │
│  │   └──────────────────┬───────────────────┘                   │ │
│  │                      ▼                                        │ │
│  │   ┌──────────────────────────────────────┐                   │ │
│  │   │       eBPF / Kernel Module           │◄─── Capture       │ │
│  │   └──────────────────┬───────────────────┘                   │ │
│  │                      ▼                                        │ │
│  │   ┌──────────────────────────────────────┐                   │ │
│  │   │          Falco Engine                 │◄─── Rules        │ │
│  │   │   ┌────────────────────────────────┐ │                   │ │
│  │   │   │  Rule: Shell in Container      │ │                   │ │
│  │   │   │  Rule: Sensitive File Read     │ │                   │ │
│  │   │   │  Rule: Network Connection      │ │                   │ │
│  │   │   └────────────────────────────────┘ │                   │ │
│  │   └──────────────────┬───────────────────┘                   │ │
│  │                      ▼                                        │ │
│  │   ┌──────────────────────────────────────┐                   │ │
│  │   │           Outputs                     │                   │ │
│  │   │  • Stdout • Syslog • gRPC • HTTP     │                   │ │
│  │   │  • Slack  • Kafka  • S3   • PagerDuty│                   │ │
│  │   └──────────────────────────────────────┘                   │ │
│  └──────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Install Falco with Helm

```bash
# Add Falco Helm repository
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Create namespace
kubectl create namespace falco

# Install Falco
helm install falco falcosecurity/falco \
  --namespace falco \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  --set driver.kind=ebpf \
  --set tty=true
```

### Verify Installation

```bash
# Check Falco pods
kubectl get pods -n falco

# View Falco logs
kubectl logs -n falco -l app.kubernetes.io/name=falco -f

# Check Falco rules loaded
kubectl exec -n falco $(kubectl get pod -n falco -l app.kubernetes.io/name=falco -o name | head -1) \
  -- falco --list
```

### Understanding Falco Rules

```yaml
# Anatomy of a Falco Rule
#
# - rule: <name>              # Unique rule name
#   desc: <description>       # Human-readable description
#   condition: <filter>       # Boolean expression
#   output: <message>         # Alert message with fields
#   priority: <level>         # EMERGENCY|ALERT|CRITICAL|ERROR|WARNING|NOTICE|INFO|DEBUG
#   tags: [<tags>]           # Categorization tags
#   enabled: true|false      # Enable/disable rule
```

---

## Part 2: Custom Falco Rules

### Create Custom Rules ConfigMap

```yaml
# custom-falco-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-custom-rules
  namespace: falco
data:
  custom_rules.yaml: |-
    # =============================================================
    # Custom Kubernetes Security Rules
    # =============================================================
    
    # -------------------- Container Security ---------------------
    
    # Detect shell spawned in container
    - rule: Shell Spawned in Container
      desc: Detect shell process spawned in a container
      condition: >
        spawned_process and
        container and
        shell_procs
      output: >
        Shell spawned in container
        (user=%user.name user_uid=%user.uid 
        container_id=%container.id container_name=%container.name 
        image=%container.image.repository
        shell=%proc.name parent=%proc.pname 
        cmdline=%proc.cmdline terminal=%proc.tty)
      priority: WARNING
      tags: [container, shell, mitre_execution]
    
    # Detect package manager usage
    - rule: Package Manager in Container
      desc: Detect package manager execution in container
      condition: >
        spawned_process and
        container and
        proc.name in (apt, apt-get, yum, dnf, apk, pip, npm, gem)
      output: >
        Package manager executed in container
        (user=%user.name container=%container.name 
        image=%container.image.repository
        command=%proc.cmdline)
      priority: WARNING
      tags: [container, package_management]
    
    # -------------------- File Access Rules ----------------------
    
    # Sensitive file access
    - rule: Read Sensitive File in Container
      desc: Detect read access to sensitive files
      condition: >
        open_read and
        container and
        (fd.name startswith /etc/shadow or
         fd.name startswith /etc/passwd or
         fd.name startswith /etc/sudoers or
         fd.name startswith /root/.ssh/ or
         fd.name startswith /home/)
      output: >
        Sensitive file read in container
        (user=%user.name container=%container.name 
        file=%fd.name image=%container.image.repository)
      priority: WARNING
      tags: [filesystem, sensitive_files]
    
    # Detect writes to /etc
    - rule: Write to /etc in Container
      desc: Detect any write operations to /etc directory
      condition: >
        open_write and
        container and
        fd.name startswith /etc/
      output: >
        File written to /etc in container
        (user=%user.name container=%container.name 
        file=%fd.name command=%proc.cmdline)
      priority: ERROR
      tags: [filesystem, mitre_persistence]
    
    # -------------------- Network Rules --------------------------
    
    # Detect outbound connection to non-standard ports
    - rule: Outbound Connection to Suspicious Port
      desc: Detect outbound connections to commonly abused ports
      condition: >
        outbound and
        container and
        fd.sport in (4444, 5555, 6666, 8888, 9001, 31337)
      output: >
        Suspicious outbound connection
        (container=%container.name image=%container.image.repository
        connection=%fd.name user=%user.name)
      priority: WARNING
      tags: [network, mitre_command_and_control]
    
    # Detect network tool usage
    - rule: Network Tool in Container
      desc: Detect network reconnaissance tools
      condition: >
        spawned_process and
        container and
        proc.name in (nc, ncat, netcat, nmap, tcpdump, tshark, curl, wget)
      output: >
        Network tool executed in container
        (tool=%proc.name container=%container.name 
        cmdline=%proc.cmdline image=%container.image.repository)
      priority: NOTICE
      tags: [network, reconnaissance]
    
    # -------------------- Kubernetes Specific --------------------
    
    # Detect kubectl exec
    - rule: K8s Exec into Pod
      desc: Detect kubectl exec command
      condition: >
        spawned_process and
        container and
        proc.pname = "runc:[2:INIT]" and
        proc.name != "pause"
      output: >
        Exec into pod detected
        (user=%user.name container=%container.name 
        namespace=%k8s.ns.name pod=%k8s.pod.name 
        command=%proc.cmdline)
      priority: NOTICE
      tags: [k8s, exec]
    
    # Detect ServiceAccount token access
    - rule: Service Account Token Read
      desc: Detect access to Kubernetes service account tokens
      condition: >
        open_read and
        container and
        fd.name startswith /var/run/secrets/kubernetes.io/
      output: >
        ServiceAccount token accessed
        (container=%container.name file=%fd.name 
        process=%proc.name image=%container.image.repository)
      priority: INFO
      tags: [k8s, credentials]
    
    # -------------------- Process Anomalies ----------------------
    
    # Detect reverse shell patterns
    - rule: Reverse Shell Detected
      desc: Detect common reverse shell patterns
      condition: >
        spawned_process and
        container and
        ((proc.cmdline contains "/dev/tcp" or
          proc.cmdline contains "bash -i" or
          proc.cmdline contains "sh -i") or
         (proc.name in (nc, ncat, netcat) and 
          proc.args contains "-e"))
      output: >
        Possible reverse shell detected
        (container=%container.name cmdline=%proc.cmdline 
        user=%user.name image=%container.image.repository)
      priority: CRITICAL
      tags: [process, mitre_execution, reverse_shell]
    
    # Detect crypto mining
    - rule: Crypto Mining Detected
      desc: Detect cryptocurrency mining processes
      condition: >
        spawned_process and
        container and
        (proc.name in (xmrig, minerd, cgminer, ccminer) or
         proc.cmdline contains "stratum+tcp" or
         proc.cmdline contains "stratum+ssl" or
         proc.cmdline contains "nicehash" or
         proc.cmdline contains "pool.")
      output: >
        Crypto mining activity detected
        (container=%container.name process=%proc.name 
        cmdline=%proc.cmdline user=%user.name)
      priority: CRITICAL
      tags: [process, cryptomining]
    
    # -------------------- Privilege Escalation -------------------
    
    # Detect setuid/setgid binary execution
    - rule: Setuid Binary Executed
      desc: Detect execution of setuid/setgid binaries
      condition: >
        spawned_process and
        container and
        proc.is_setuid_or_setgid=true and
        not proc.name in (su, sudo, ping)
      output: >
        Setuid/setgid binary executed
        (container=%container.name binary=%proc.name 
        cmdline=%proc.cmdline user=%user.name)
      priority: WARNING
      tags: [process, privilege_escalation]
    
    # Detect capability manipulation
    - rule: Capability Changed
      desc: Detect capability modifications
      condition: >
        syscall.type = "capset" and
        container
      output: >
        Capabilities modified in container
        (container=%container.name user=%user.name 
        process=%proc.name)
      priority: WARNING
      tags: [process, capabilities]
```

### Apply Custom Rules

```bash
# Apply the ConfigMap
kubectl apply -f custom-falco-rules.yaml

# Update Falco Helm release to use custom rules
helm upgrade falco falcosecurity/falco \
  --namespace falco \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  --set driver.kind=ebpf \
  --set tty=true \
  --set customRules."custom_rules\.yaml"=$(cat custom-falco-rules.yaml | base64 -w0)

# Or mount the ConfigMap
helm upgrade falco falcosecurity/falco \
  --namespace falco \
  --set falcosidekick.enabled=true \
  --set "extraVolumes[0].name=custom-rules" \
  --set "extraVolumes[0].configMap.name=falco-custom-rules" \
  --set "extraVolumeMounts[0].name=custom-rules" \
  --set "extraVolumeMounts[0].mountPath=/etc/falco/rules.d" \
  --set driver.kind=ebpf
```

### Test Falco Rules

```bash
# Create test pod
kubectl run test-falco --image=alpine --restart=Never -- sleep 3600

# Trigger shell detection
kubectl exec -it test-falco -- sh

# Trigger package manager detection
kubectl exec test-falco -- apk add curl

# Trigger network tool detection
kubectl exec test-falco -- wget --help

# View Falco alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50 | grep -E "Warning|Error|Critical"

# Cleanup
kubectl delete pod test-falco
```

---

## Part 3: Falcosidekick and Alerting

### Configure Alert Outputs

```yaml
# falcosidekick-values.yaml
config:
  # Slack integration
  slack:
    webhookurl: "https://hooks.slack.com/services/XXX/YYY/ZZZ"
    channel: "#security-alerts"
    username: "Falco"
    icon: "https://falco.org/img/favicon.png"
    minimumpriority: "warning"
    messageformat: |
      *Falco Alert*
      Priority: {{ .Priority }}
      Rule: {{ .Rule }}
      Output: {{ .Output }}
      Time: {{ .Time }}

  # Prometheus metrics
  prometheus:
    enabled: true
    listen: "0.0.0.0:2112"

  # Webhook for custom integration
  webhook:
    address: "http://alert-handler.security.svc:8080/falco"
    customHeaders:
      Authorization: "Bearer $WEBHOOK_TOKEN"
    minimumpriority: "notice"

  # AlertManager integration
  alertmanager:
    hostport: "http://alertmanager.monitoring.svc:9093"
    minimumpriority: "warning"

  # Loki for log aggregation
  loki:
    hostport: "http://loki.logging.svc:3100"
    minimumpriority: "notice"

webui:
  enabled: true
  replicaCount: 1
  service:
    type: ClusterIP
    port: 2802
```

### Deploy Enhanced Falcosidekick

```bash
# Install with alerting configuration
helm upgrade falco falcosecurity/falco \
  --namespace falco \
  --values falcosidekick-values.yaml \
  --set falcosidekick.enabled=true \
  --set driver.kind=ebpf

# Access Falcosidekick UI
kubectl port-forward svc/falco-falcosidekick-ui -n falco 2802:2802
```

### Create Alert Handler Service

```yaml
# alert-handler.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alert-handler-config
  namespace: security
data:
  handler.py: |
    from flask import Flask, request, jsonify
    import json
    import logging
    from datetime import datetime
    
    app = Flask(__name__)
    logging.basicConfig(level=logging.INFO)
    
    # Priority levels for action decisions
    PRIORITY_LEVELS = {
        'emergency': 0,
        'alert': 1,
        'critical': 2,
        'error': 3,
        'warning': 4,
        'notice': 5,
        'informational': 6,
        'debug': 7
    }
    
    # Actions based on priority
    def determine_action(priority, rule):
        priority_num = PRIORITY_LEVELS.get(priority.lower(), 7)
        
        if priority_num <= 2:  # Critical or higher
            return {
                'action': 'isolate',
                'notify': ['security-team', 'on-call'],
                'ticket': True,
                'escalation': 'immediate'
            }
        elif priority_num <= 4:  # Warning or higher
            return {
                'action': 'alert',
                'notify': ['security-team'],
                'ticket': True,
                'escalation': 'standard'
            }
        else:
            return {
                'action': 'log',
                'notify': [],
                'ticket': False,
                'escalation': None
            }
    
    @app.route('/falco', methods=['POST'])
    def handle_falco_alert():
        data = request.json
        
        priority = data.get('priority', 'unknown')
        rule = data.get('rule', 'unknown')
        output = data.get('output', '')
        output_fields = data.get('output_fields', {})
        
        # Log the alert
        logging.info(f"Falco Alert: {priority} - {rule}")
        logging.info(f"Details: {output}")
        
        # Determine action
        action = determine_action(priority, rule)
        
        # Extract container info
        container = output_fields.get('container.name', 'unknown')
        namespace = output_fields.get('k8s.ns.name', 'unknown')
        pod = output_fields.get('k8s.pod.name', 'unknown')
        
        # Take automated action if critical
        if action['action'] == 'isolate':
            # Here you would implement pod isolation
            # e.g., apply network policy, scale down, etc.
            logging.warning(f"ISOLATION triggered for {namespace}/{pod}")
            
            # Example: Label pod for network isolation
            # This could trigger a NetworkPolicy
            isolation_result = {
                'isolated': True,
                'timestamp': datetime.now().isoformat(),
                'target': f"{namespace}/{pod}"
            }
        else:
            isolation_result = None
        
        response = {
            'received': True,
            'timestamp': datetime.now().isoformat(),
            'priority': priority,
            'rule': rule,
            'action_taken': action,
            'isolation': isolation_result
        }
        
        return jsonify(response)
    
    @app.route('/health', methods=['GET'])
    def health():
        return jsonify({'status': 'healthy'})
    
    if __name__ == '__main__':
        app.run(host='0.0.0.0', port=8080)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alert-handler
  namespace: security
spec:
  replicas: 2
  selector:
    matchLabels:
      app: alert-handler
  template:
    metadata:
      labels:
        app: alert-handler
    spec:
      containers:
      - name: handler
        image: python:3.11-slim
        command: ["python", "/app/handler.py"]
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: handler-code
          mountPath: /app
        resources:
          limits:
            memory: 256Mi
            cpu: 200m
      volumes:
      - name: handler-code
        configMap:
          name: alert-handler-config
---
apiVersion: v1
kind: Service
metadata:
  name: alert-handler
  namespace: security
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: alert-handler
```

---

## Part 4: CIS Kubernetes Benchmarks with kube-bench

### Understanding CIS Benchmarks

The CIS Kubernetes Benchmark provides security configuration recommendations:

```
┌─────────────────────────────────────────────────────────────────┐
│              CIS Kubernetes Benchmark Categories                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Control Plane Components                                      │
│     ├── API Server Configuration                                  │
│     ├── Controller Manager                                        │
│     ├── Scheduler                                                 │
│     └── etcd                                                      │
│                                                                   │
│  2. Worker Node Security                                          │
│     ├── Kubelet Configuration                                     │
│     ├── Container Runtime                                         │
│     └── File Permissions                                          │
│                                                                   │
│  3. Policies                                                      │
│     ├── RBAC and Service Accounts                                 │
│     ├── Pod Security                                              │
│     └── Network Policies                                          │
│                                                                   │
│  4. Control Plane Configuration                                   │
│     ├── Authentication                                            │
│     ├── Authorization                                             │
│     └── Logging                                                   │
│                                                                   │
│  5. Data Plane                                                    │
│     ├── Secrets Management                                        │
│     └── General Policies                                          │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Run kube-bench

```bash
# Run kube-bench as a Job
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench
  namespace: security
spec:
  template:
    spec:
      hostPID: true
      containers:
      - name: kube-bench
        image: aquasec/kube-bench:latest
        command: ["kube-bench", "run", "--targets", "node,policies", "--json"]
        volumeMounts:
        - name: var-lib-etcd
          mountPath: /var/lib/etcd
          readOnly: true
        - name: var-lib-kubelet
          mountPath: /var/lib/kubelet
          readOnly: true
        - name: var-lib-kube-scheduler
          mountPath: /var/lib/kube-scheduler
          readOnly: true
        - name: var-lib-kube-controller-manager
          mountPath: /var/lib/kube-controller-manager
          readOnly: true
        - name: etc-systemd
          mountPath: /etc/systemd
          readOnly: true
        - name: lib-systemd
          mountPath: /lib/systemd/
          readOnly: true
        - name: etc-kubernetes
          mountPath: /etc/kubernetes
          readOnly: true
        - name: etc-cni-netd
          mountPath: /etc/cni/net.d/
          readOnly: true
      restartPolicy: Never
      volumes:
      - name: var-lib-etcd
        hostPath:
          path: /var/lib/etcd
      - name: var-lib-kubelet
        hostPath:
          path: /var/lib/kubelet
      - name: var-lib-kube-scheduler
        hostPath:
          path: /var/lib/kube-scheduler
      - name: var-lib-kube-controller-manager
        hostPath:
          path: /var/lib/kube-controller-manager
      - name: etc-systemd
        hostPath:
          path: /etc/systemd
      - name: lib-systemd
        hostPath:
          path: /lib/systemd
      - name: etc-kubernetes
        hostPath:
          path: /etc/kubernetes
      - name: etc-cni-netd
        hostPath:
          path: /etc/cni/net.d/
  backoffLimit: 1
EOF

# Get results
kubectl logs job/kube-bench -n security

# Save JSON output
kubectl logs job/kube-bench -n security > kube-bench-results.json
```

### Automated CIS Benchmark CronJob

```yaml
# kube-bench-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: kube-bench-scheduled
  namespace: security
spec:
  schedule: "0 6 * * *"  # Daily at 6 AM
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          hostPID: true
          serviceAccountName: kube-bench-sa
          containers:
          - name: kube-bench
            image: aquasec/kube-bench:latest
            command:
            - /bin/sh
            - -c
            - |
              # Run benchmark
              kube-bench run --json > /tmp/results.json
              
              # Parse and format results
              cat /tmp/results.json | jq '{
                timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
                total_pass: [.Controls[].tests[].results[] | select(.status == "PASS")] | length,
                total_fail: [.Controls[].tests[].results[] | select(.status == "FAIL")] | length,
                total_warn: [.Controls[].tests[].results[] | select(.status == "WARN")] | length,
                critical_failures: [.Controls[].tests[].results[] | select(.status == "FAIL" and .scored == true)]
              }'
              
              # Check for critical failures
              FAILS=$(cat /tmp/results.json | jq '[.Controls[].tests[].results[] | select(.status == "FAIL" and .scored == true)] | length')
              
              if [ "$FAILS" -gt 0 ]; then
                echo "WARNING: $FAILS critical CIS benchmark failures detected"
                exit 1
              fi
            volumeMounts:
            - name: var-lib-kubelet
              mountPath: /var/lib/kubelet
              readOnly: true
            - name: etc-kubernetes
              mountPath: /etc/kubernetes
              readOnly: true
          restartPolicy: OnFailure
          volumes:
          - name: var-lib-kubelet
            hostPath:
              path: /var/lib/kubelet
          - name: etc-kubernetes
            hostPath:
              path: /etc/kubernetes
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-bench-sa
  namespace: security
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-bench-role
rules:
- apiGroups: [""]
  resources: ["nodes", "pods", "configmaps"]
  verbs: ["get", "list"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-bench-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-bench-role
subjects:
- kind: ServiceAccount
  name: kube-bench-sa
  namespace: security
```

### CIS Remediation Tracking

```yaml
# cis-remediation-tracker.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cis-remediation-tracker
  namespace: security
data:
  remediation-plan.yaml: |
    # CIS Kubernetes Benchmark Remediation Tracking
    
    remediation_items:
      # API Server hardening
      - id: "1.2.6"
        check: "Ensure that the --kubelet-certificate-authority argument is set"
        status: "in_progress"
        owner: "platform-team"
        due_date: "2024-02-15"
        remediation: |
          Add to kube-apiserver manifest:
          --kubelet-certificate-authority=/etc/kubernetes/pki/ca.crt
      
      - id: "1.2.16"
        check: "Ensure that the admission control plugin PodSecurityPolicy is not set"
        status: "completed"
        owner: "security-team"
        completed_date: "2024-01-10"
        remediation: |
          Migrated to Pod Security Admission with restricted profile
      
      # Kubelet hardening
      - id: "4.2.6"
        check: "Ensure that the --protect-kernel-defaults argument is set to true"
        status: "pending"
        owner: "platform-team"
        due_date: "2024-02-28"
        remediation: |
          Update kubelet config:
          protectKernelDefaults: true
      
      # RBAC
      - id: "5.1.6"
        check: "Ensure that Service Account Tokens are only mounted where necessary"
        status: "in_progress"
        owner: "dev-teams"
        due_date: "2024-03-01"
        remediation: |
          Set automountServiceAccountToken: false in all pod specs
          where service account access is not required

    exceptions:
      - id: "1.2.22"
        check: "Ensure that the --audit-log-maxbackup argument is set"
        status: "exception"
        reason: "Using external log aggregation (Loki)"
        approved_by: "security-lead"
        expiry: "2024-12-31"
```

---

## Part 5: Kubescape Security Scanning

### Install Kubescape

```bash
# Install Kubescape CLI
curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash

# Verify installation
kubescape version
```

### Run Security Scans

```bash
# Full cluster scan with NSA framework
kubescape scan --format json --output kubescape-nsa.json framework nsa

# CIS Benchmark scan
kubescape scan framework cis-v1.23-t1.0.1 --format json --output kubescape-cis.json

# MITRE ATT&CK framework
kubescape scan framework mitre --format json --output kubescape-mitre.json

# Scan specific namespace
kubescape scan --include-namespaces production framework nsa

# Scan before deployment
kubescape scan manifests/*.yaml

# Get human-readable summary
kubescape scan framework nsa --format pretty
```

### In-Cluster Kubescape Operator

```yaml
# kubescape-operator.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kubescape
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: kubescape
  namespace: kubescape
spec:
  interval: 1h
  chart:
    spec:
      chart: kubescape-operator
      version: "1.x"
      sourceRef:
        kind: HelmRepository
        name: kubescape
        namespace: flux-system
  values:
    # Enable continuous scanning
    continuousScan:
      enabled: true
      schedule: "0 */6 * * *"  # Every 6 hours
    
    # Enable admission controller
    admissionController:
      enabled: true
      mode: "monitor"  # or "enforce"
    
    # Configure scanning
    scanner:
      frameworks:
        - nsa
        - mitre
        - cis-v1.23-t1.0.1
      
      # Exclude namespaces
      excludeNamespaces:
        - kube-system
        - kubescape
    
    # Enable metrics
    prometheus:
      enabled: true
      serviceMonitor:
        enabled: true
```

### Custom Kubescape Controls

```yaml
# custom-controls.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubescape-custom-controls
  namespace: kubescape
data:
  custom-controls.json: |
    {
      "name": "Custom Security Controls",
      "description": "Organization-specific security controls",
      "controls": [
        {
          "controlID": "C-0100",
          "name": "Require resource limits",
          "description": "All containers must have CPU and memory limits defined",
          "remediation": "Add resources.limits to container spec",
          "rules": [
            {
              "name": "resource-limits-required",
              "match": [
                {
                  "apiGroups": ["apps"],
                  "resources": ["deployments", "statefulsets", "daemonsets"]
                }
              ],
              "rule": "containers[*].resources.limits.cpu && containers[*].resources.limits.memory"
            }
          ]
        },
        {
          "controlID": "C-0101",
          "name": "Require security context",
          "description": "All pods must have securityContext defined",
          "remediation": "Add securityContext to pod spec with runAsNonRoot: true",
          "rules": [
            {
              "name": "security-context-required",
              "match": [
                {
                  "apiGroups": ["apps"],
                  "resources": ["deployments", "statefulsets", "daemonsets"]
                }
              ],
              "rule": "spec.template.spec.securityContext.runAsNonRoot == true"
            }
          ]
        },
        {
          "controlID": "C-0102",
          "name": "Approved registries only",
          "description": "Container images must come from approved registries",
          "remediation": "Use images from approved registries: gcr.io/org-name, docker.io/org-name",
          "rules": [
            {
              "name": "approved-registries",
              "match": [
                {
                  "apiGroups": ["", "apps"],
                  "resources": ["pods", "deployments"]
                }
              ],
              "rule": "containers[*].image =~ '^(gcr.io/org-name|docker.io/org-name)/'"
            }
          ]
        }
      ]
    }
```

---

## Part 6: Compliance Pipeline

### GitOps Security Pipeline

```yaml
# .github/workflows/security-compliance.yaml
name: Security Compliance Pipeline

on:
  push:
    branches: [main]
    paths:
      - 'kubernetes/**'
      - 'helm/**'
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 8 * * 1'  # Weekly on Monday at 8 AM

jobs:
  manifest-scanning:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Kubescape
        run: curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
      
      - name: Scan Kubernetes manifests
        run: |
          kubescape scan kubernetes/**/*.yaml \
            --format junit \
            --output kubescape-results.xml \
            --compliance-threshold 70
      
      - name: Upload scan results
        uses: actions/upload-artifact@v4
        with:
          name: kubescape-results
          path: kubescape-results.xml
      
      - name: Publish test results
        uses: EnricoMi/publish-unit-test-result-action@v2
        if: always()
        with:
          files: kubescape-results.xml

  image-scanning:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Extract images from manifests
        id: images
        run: |
          IMAGES=$(grep -rh "image:" kubernetes/ | awk '{print $2}' | sort -u | tr '\n' ' ')
          echo "images=$IMAGES" >> $GITHUB_OUTPUT
      
      - name: Scan images with Trivy
        run: |
          for image in ${{ steps.images.outputs.images }}; do
            echo "Scanning: $image"
            docker run --rm aquasec/trivy:latest image \
              --severity HIGH,CRITICAL \
              --exit-code 1 \
              "$image"
          done

  cis-benchmark:
    runs-on: ubuntu-latest
    needs: [manifest-scanning]
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    steps:
      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          kubeconfig: ${{ secrets.KUBECONFIG }}
      
      - name: Run kube-bench
        run: |
          kubectl apply -f - <<EOF
          apiVersion: batch/v1
          kind: Job
          metadata:
            name: kube-bench-${{ github.run_id }}
            namespace: security
          spec:
            template:
              spec:
                hostPID: true
                containers:
                - name: kube-bench
                  image: aquasec/kube-bench:latest
                  command: ["kube-bench", "run", "--json"]
                restartPolicy: Never
            backoffLimit: 1
          EOF
          
          # Wait for completion
          kubectl wait --for=condition=complete job/kube-bench-${{ github.run_id }} -n security --timeout=300s
          
          # Get results
          kubectl logs job/kube-bench-${{ github.run_id }} -n security > kube-bench-results.json
      
      - name: Parse and report results
        run: |
          PASS=$(jq '[.Controls[].tests[].results[] | select(.status == "PASS")] | length' kube-bench-results.json)
          FAIL=$(jq '[.Controls[].tests[].results[] | select(.status == "FAIL")] | length' kube-bench-results.json)
          WARN=$(jq '[.Controls[].tests[].results[] | select(.status == "WARN")] | length' kube-bench-results.json)
          
          echo "## CIS Benchmark Results" >> $GITHUB_STEP_SUMMARY
          echo "| Status | Count |" >> $GITHUB_STEP_SUMMARY
          echo "|--------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| ✅ Pass | $PASS |" >> $GITHUB_STEP_SUMMARY
          echo "| ❌ Fail | $FAIL |" >> $GITHUB_STEP_SUMMARY
          echo "| ⚠️ Warn | $WARN |" >> $GITHUB_STEP_SUMMARY
          
          if [ "$FAIL" -gt 0 ]; then
            echo "### Critical Failures" >> $GITHUB_STEP_SUMMARY
            jq -r '.Controls[].tests[].results[] | select(.status == "FAIL" and .scored == true) | "- \(.test_number): \(.test_desc)"' kube-bench-results.json >> $GITHUB_STEP_SUMMARY
          fi
      
      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: cis-benchmark-results
          path: kube-bench-results.json

  compliance-report:
    runs-on: ubuntu-latest
    needs: [manifest-scanning, image-scanning]
    steps:
      - uses: actions/checkout@v4
      
      - name: Download all artifacts
        uses: actions/download-artifact@v4
      
      - name: Generate compliance report
        run: |
          cat > compliance-report.md << 'EOF'
          # Security Compliance Report
          
          Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
          Commit: ${{ github.sha }}
          
          ## Summary
          
          | Check | Status |
          |-------|--------|
          | Manifest Scanning | ${{ needs.manifest-scanning.result }} |
          | Image Scanning | ${{ needs.image-scanning.result }} |
          
          ## Details
          
          See attached artifacts for detailed results.
          EOF
      
      - name: Upload compliance report
        uses: actions/upload-artifact@v4
        with:
          name: compliance-report
          path: compliance-report.md
```

### Argo CD Pre-Sync Security Hooks

```yaml
# security-presync-hook.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: security-presync-check
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: security-scanner
        image: kubescape/kubescape:latest
        command:
        - /bin/sh
        - -c
        - |
          # Clone the repo and scan
          git clone $ARGOCD_APP_SOURCE_REPO_URL /tmp/repo
          cd /tmp/repo
          git checkout $ARGOCD_APP_REVISION
          
          # Run Kubescape scan
          kubescape scan $ARGOCD_APP_SOURCE_PATH \
            --compliance-threshold 80 \
            --format json \
            --output /tmp/results.json
          
          # Check for critical issues
          CRITICAL=$(jq '.resourcesSeverityCounters.criticalSeverity' /tmp/results.json)
          
          if [ "$CRITICAL" -gt 0 ]; then
            echo "ERROR: $CRITICAL critical security issues found"
            jq '.results[] | select(.prioritizedResource.severity == "Critical")' /tmp/results.json
            exit 1
          fi
          
          echo "Security check passed"
        env:
        - name: ARGOCD_APP_SOURCE_REPO_URL
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['argocd.argoproj.io/app-source-repo-url']
        - name: ARGOCD_APP_SOURCE_PATH
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['argocd.argoproj.io/app-source-path']
        - name: ARGOCD_APP_REVISION
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['argocd.argoproj.io/app-revision']
      restartPolicy: Never
  backoffLimit: 1
```

---

## Part 7: Security Dashboard

### Grafana Security Dashboard

```yaml
# security-dashboard-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-security-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  security-overview.json: |
    {
      "dashboard": {
        "title": "Kubernetes Security Overview",
        "uid": "k8s-security-overview",
        "timezone": "browser",
        "panels": [
          {
            "title": "Falco Alerts by Priority",
            "type": "piechart",
            "gridPos": {"x": 0, "y": 0, "w": 8, "h": 8},
            "targets": [
              {
                "expr": "sum by (priority) (increase(falco_events_total[24h]))",
                "legendFormat": "{{priority}}"
              }
            ]
          },
          {
            "title": "Falco Alerts Timeline",
            "type": "timeseries",
            "gridPos": {"x": 8, "y": 0, "w": 16, "h": 8},
            "targets": [
              {
                "expr": "sum by (rule) (rate(falco_events_total[5m]))",
                "legendFormat": "{{rule}}"
              }
            ]
          },
          {
            "title": "CIS Benchmark Compliance",
            "type": "gauge",
            "gridPos": {"x": 0, "y": 8, "w": 6, "h": 6},
            "targets": [
              {
                "expr": "(kube_bench_pass_total / (kube_bench_pass_total + kube_bench_fail_total)) * 100"
              }
            ],
            "options": {
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "red"},
                  {"value": 60, "color": "yellow"},
                  {"value": 80, "color": "green"}
                ]
              }
            }
          },
          {
            "title": "Image Vulnerabilities",
            "type": "stat",
            "gridPos": {"x": 6, "y": 8, "w": 6, "h": 6},
            "targets": [
              {
                "expr": "sum(trivy_vulnerability_count{severity=\"CRITICAL\"})"
              }
            ],
            "options": {
              "colorMode": "value",
              "graphMode": "none"
            }
          },
          {
            "title": "Pod Security Violations",
            "type": "bargauge",
            "gridPos": {"x": 12, "y": 8, "w": 12, "h": 6},
            "targets": [
              {
                "expr": "sum by (namespace) (kyverno_policy_results_total{result=\"fail\", policy_type=\"validate\"})",
                "legendFormat": "{{namespace}}"
              }
            ]
          },
          {
            "title": "NetworkPolicy Coverage",
            "type": "table",
            "gridPos": {"x": 0, "y": 14, "w": 12, "h": 8},
            "targets": [
              {
                "expr": "count by (namespace) (kube_pod_info) - count by (namespace) (kube_networkpolicy_spec_pod_selector)",
                "legendFormat": "Unprotected Pods: {{namespace}}"
              }
            ]
          },
          {
            "title": "Recent Security Events",
            "type": "logs",
            "gridPos": {"x": 12, "y": 14, "w": 12, "h": 8},
            "targets": [
              {
                "expr": "{job=\"falco\"} |= \"priority\" | json | priority =~ \"Warning|Error|Critical\"",
                "queryType": "loki"
              }
            ]
          },
          {
            "title": "Secret Access Patterns",
            "type": "heatmap",
            "gridPos": {"x": 0, "y": 22, "w": 12, "h": 8},
            "targets": [
              {
                "expr": "sum by (namespace, secret) (increase(apiserver_request_total{resource=\"secrets\", verb=\"get\"}[1h]))"
              }
            ]
          },
          {
            "title": "RBAC Permission Changes",
            "type": "timeseries",
            "gridPos": {"x": 12, "y": 22, "w": 12, "h": 8},
            "targets": [
              {
                "expr": "sum by (resource) (rate(apiserver_request_total{resource=~\"roles|rolebindings|clusterroles|clusterrolebindings\", verb=~\"create|update|patch|delete\"}[5m]))",
                "legendFormat": "{{resource}}"
              }
            ]
          }
        ],
        "refresh": "30s"
      }
    }
```

### PrometheusRule for Security Alerts

```yaml
# security-prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: security-alerts
  namespace: monitoring
  labels:
    prometheus: k8s
    role: alert-rules
spec:
  groups:
  - name: falco-alerts
    rules:
    - alert: FalcoCriticalAlert
      expr: increase(falco_events_total{priority="Critical"}[5m]) > 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "Falco detected critical security event"
        description: "Falco has detected {{ $value }} critical security events in the last 5 minutes"
    
    - alert: FalcoHighAlertRate
      expr: rate(falco_events_total{priority=~"Warning|Error"}[5m]) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High rate of Falco security alerts"
        description: "More than 1 security alert per second over the last 5 minutes"

  - name: cis-compliance
    rules:
    - alert: CISComplianceDrop
      expr: (kube_bench_pass_total / (kube_bench_pass_total + kube_bench_fail_total)) * 100 < 80
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "CIS compliance score below threshold"
        description: "CIS benchmark compliance is at {{ $value }}%, below 80% threshold"
    
    - alert: CISCriticalFailure
      expr: increase(kube_bench_fail_total{scored="true"}[24h]) > 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "New CIS benchmark failure detected"
        description: "{{ $value }} new scored CIS benchmark failures in the last 24 hours"

  - name: image-security
    rules:
    - alert: CriticalVulnerabilitiesFound
      expr: sum(trivy_vulnerability_count{severity="CRITICAL"}) > 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "Critical vulnerabilities in container images"
        description: "{{ $value }} critical vulnerabilities found in deployed container images"
    
    - alert: UnscannedImages
      expr: (count(kube_pod_container_info) - count(trivy_image_info)) > 0
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "Unscanned container images detected"
        description: "{{ $value }} container images have not been scanned for vulnerabilities"

  - name: rbac-monitoring
    rules:
    - alert: ClusterRoleModification
      expr: increase(apiserver_request_total{resource="clusterroles", verb=~"create|update|patch|delete"}[5m]) > 0
      for: 0m
      labels:
        severity: info
      annotations:
        summary: "ClusterRole modified"
        description: "A ClusterRole was {{ $labels.verb }}d"
    
    - alert: PrivilegedPodCreated
      expr: increase(apiserver_request_total{resource="pods", verb="create"}[5m]) > 0 and on() kube_pod_container_info{container!="", pod!=""} and on(pod) kube_pod_spec_containers_security_context_privileged{privileged="true"}
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "Privileged pod created"
        description: "A privileged pod was created in namespace {{ $labels.namespace }}"

  - name: network-security
    rules:
    - alert: NamespaceWithoutNetworkPolicy
      expr: count by (namespace) (kube_pod_info) unless count by (namespace) (kube_networkpolicy_labels)
      for: 24h
      labels:
        severity: warning
      annotations:
        summary: "Namespace without NetworkPolicy"
        description: "Namespace {{ $labels.namespace }} has pods but no NetworkPolicy"
```

---

## 🎯 Practical Exercises

### Exercise 1: Falco Threat Simulation

1. Deploy Falco with custom rules
2. Create a test workload
3. Simulate various attack patterns:
   - Shell access
   - File system modifications
   - Network reconnaissance
   - Privilege escalation attempts
4. Verify Falco detects all threats
5. Configure alerting to Slack/webhook

### Exercise 2: CIS Benchmark Remediation

1. Run kube-bench on your cluster
2. Identify top 5 failing controls
3. Create remediation plan for each
4. Implement fixes where possible
5. Document exceptions with justification
6. Re-run benchmark to verify improvements

### Exercise 3: Security Pipeline Implementation

1. Create security scanning pipeline:
   - Pre-commit hooks for secret detection
   - CI scanning with Kubescape
   - Image vulnerability scanning
   - CIS benchmark validation
2. Configure policy gates (block on critical issues)
3. Set up compliance reporting

### Exercise 4: Security Monitoring Dashboard

1. Deploy Grafana with security dashboards
2. Configure Prometheus to collect:
   - Falco metrics
   - kube-bench results
   - Policy violation metrics
3. Create alerting rules for critical events
4. Test alert routing to appropriate channels

---

## 📚 Key Takeaways

### Runtime Security Best Practices

| Practice | Tool | Purpose |
|----------|------|---------|
| Syscall monitoring | Falco | Real-time threat detection |
| Container behavior | Falco rules | Detect anomalies |
| File integrity | Falco + auditd | Track sensitive files |
| Network monitoring | Falco | Detect suspicious connections |

### Compliance Tools Comparison

| Tool | Focus | Output | Use Case |
|------|-------|--------|----------|
| kube-bench | CIS Benchmark | JSON/Console | Node configuration |
| Kubescape | Multiple frameworks | JSON/SARIF | Manifest scanning |
| Trivy | Vulnerabilities | JSON/Table | Image/config scanning |
| Falco | Runtime | Events | Live threat detection |

### Automation Recommendations

```
┌─────────────────────────────────────────────────────────────────┐
│                  Security Automation Layers                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Development (Pre-commit)                                         │
│  ├── Secret detection (git-secrets, trufflehog)                  │
│  └── Basic manifest validation (kubeval)                         │
│                                                                   │
│  CI Pipeline (Pre-merge)                                          │
│  ├── Kubescape scanning (NSA, MITRE, CIS)                        │
│  ├── Image vulnerability scanning (Trivy)                        │
│  ├── Policy validation (Kyverno/OPA)                             │
│  └── SBOM generation (Syft)                                      │
│                                                                   │
│  CD Pipeline (Pre-deploy)                                         │
│  ├── Image signature verification (Cosign)                       │
│  ├── Admission control (Kyverno/Gatekeeper)                      │
│  └── Pre-sync security hooks                                     │
│                                                                   │
│  Runtime (Continuous)                                             │
│  ├── Falco threat detection                                      │
│  ├── CIS benchmark monitoring (kube-bench)                       │
│  ├── Compliance dashboards                                       │
│  └── Automated alerting and response                             │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## ✅ Lab Checklist

Before completing this lab, verify:

- [ ] Falco installed and detecting threats
- [ ] Custom Falco rules deployed and tested
- [ ] Falcosidekick configured with alerting
- [ ] kube-bench CIS benchmarks executed
- [ ] Kubescape scanning configured
- [ ] Custom security controls defined
- [ ] Security pipeline integrated
- [ ] Grafana dashboard displaying security metrics
- [ ] Alert rules configured in Prometheus
- [ ] Compliance reports generating automatically

---

## 🔗 Additional Resources

- [Falco Documentation](https://falco.org/docs/)
- [Falco Rules Reference](https://falco.org/docs/rules/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [kube-bench GitHub](https://github.com/aquasecurity/kube-bench)
- [Kubescape Documentation](https://hub.armosec.io/docs)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- [NIST Container Security Guide](https://csrc.nist.gov/publications/detail/sp/800-190/final)

---

## Next Steps

Congratulations on completing Module 6: Security! You've learned:

1. ✅ Cluster security with RBAC and authentication
2. ✅ Pod security with PSA and security contexts
3. ✅ Network security with policies and service mesh
4. ✅ Secrets management with Vault and ESO
5. ✅ Supply chain security with signing and scanning
6. ✅ Runtime security with Falco and compliance tools

**Proceed to:** [Module 7: Disaster Recovery →](../../module-07-disaster-recovery/README.md)
