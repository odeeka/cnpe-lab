# Lab 2: Pod Security

## Overview

This lab covers securing workloads at the pod level using Pod Security Standards (PSS), Pod Security Admission (PSA), security contexts, Linux capabilities, and kernel security features like Seccomp and AppArmor.

## Objectives

- Understand Pod Security Standards
- Configure Pod Security Admission
- Implement security contexts
- Manage Linux capabilities
- Apply Seccomp and AppArmor profiles

## Prerequisites

- Completed Lab 1: Cluster Security Fundamentals
- Running Kubernetes cluster (1.28+)
- Basic understanding of Linux security

---

## Pod Security Standards Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                  POD SECURITY STANDARDS                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PRIVILEGED                                                      │
│  ──────────                                                      │
│  • No restrictions                                              │
│  • Full access to host                                          │
│  • Use for: System components, infrastructure                   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  BASELINE                                                │    │
│  │  ────────                                                │    │
│  │  • Prevents known privilege escalations                 │    │
│  │  • Blocks hostNetwork, hostPID, hostIPC                 │    │
│  │  • Limits capabilities to safe subset                   │    │
│  │  • Use for: Standard workloads                          │    │
│  │                                                          │    │
│  │  ┌───────────────────────────────────────────────────┐  │    │
│  │  │  RESTRICTED                                        │  │    │
│  │  │  ──────────                                        │  │    │
│  │  │  • Heavily restricted                              │  │    │
│  │  │  • Must run as non-root                            │  │    │
│  │  │  • Drops ALL capabilities                          │  │    │
│  │  │  • Read-only root filesystem                       │  │    │
│  │  │  • Seccomp required                                │  │    │
│  │  │  • Use for: Security-sensitive workloads           │  │    │
│  │  └───────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### PSS Comparison

| Control | Privileged | Baseline | Restricted |
|---------|------------|----------|------------|
| hostNetwork | ✓ | ✗ | ✗ |
| hostPID | ✓ | ✗ | ✗ |
| hostIPC | ✓ | ✗ | ✗ |
| privileged | ✓ | ✗ | ✗ |
| Capabilities | All | Limited | None (must drop ALL) |
| Host volumes | ✓ | ✓ | ✗ |
| runAsNonRoot | - | - | Required |
| Seccomp | - | - | Required |
| AllowPrivilegeEscalation | ✓ | ✓ | Must be false |

---

## Part 1: Pod Security Admission

### PSA Modes

```
┌─────────────────────────────────────────────────────────────────┐
│                    PSA ADMISSION MODES                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ENFORCE                     AUDIT                   WARN        │
│  ───────                     ─────                   ────        │
│                                                                  │
│  ┌─────────┐              ┌─────────┐            ┌─────────┐    │
│  │ REJECT  │              │  LOG    │            │ DISPLAY │    │
│  │ Pod if  │              │ Audit   │            │ Warning │    │
│  │violates │              │ Event   │            │ to User │    │
│  └─────────┘              └─────────┘            └─────────┘    │
│      │                        │                       │          │
│      │                        │                       │          │
│      ▼                        ▼                       ▼          │
│  Pod NOT                 Pod Created             Pod Created     │
│  Created                 + Log Entry             + Warning       │
│                                                                  │
│  Use: Production         Use: Migration          Use: Testing   │
│                          and audit               before enforce │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 1.1: Create Namespaces with Different PSA Levels

```bash
# Create privileged namespace
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: psa-privileged
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/enforce-version: latest
EOF

# Create baseline namespace
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: psa-baseline
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF

# Create restricted namespace
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: psa-restricted
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF

# Verify labels
kubectl get namespaces -l 'pod-security.kubernetes.io/enforce' --show-labels
```

### Step 1.2: Test Privileged Pod in Different Namespaces

```bash
# This privileged pod definition
cat <<EOF > /tmp/privileged-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    securityContext:
      privileged: true
EOF

# Should succeed in privileged namespace
kubectl apply -f /tmp/privileged-pod.yaml -n psa-privileged
echo "Result: $?"

# Should fail in baseline namespace
kubectl apply -f /tmp/privileged-pod.yaml -n psa-baseline 2>&1 | head -5

# Should fail in restricted namespace
kubectl apply -f /tmp/privileged-pod.yaml -n psa-restricted 2>&1 | head -5

# Cleanup
kubectl delete pod privileged-pod -n psa-privileged --ignore-not-found
```

### Step 1.3: Test Baseline-Compliant Pod

```bash
# Create baseline-compliant pod
cat <<EOF > /tmp/baseline-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: baseline-pod
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    # No privileged settings
EOF

# Should succeed in privileged and baseline
kubectl apply -f /tmp/baseline-pod.yaml -n psa-privileged
kubectl apply -f /tmp/baseline-pod.yaml -n psa-baseline

# Will get warnings in restricted namespace (may still succeed due to audit mode)
kubectl apply -f /tmp/baseline-pod.yaml -n psa-restricted 2>&1

# Check warnings
kubectl get events -n psa-restricted --field-selector reason=FailedCreate
```

### Step 1.4: Create Restricted-Compliant Pod

```bash
# Fully restricted-compliant pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: psa-restricted
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF

# Verify
kubectl get pod restricted-pod -n psa-restricted
kubectl describe pod restricted-pod -n psa-restricted | grep -A10 "Security Context"
```

### Step 1.5: Migrate Namespace to Restricted

```bash
# First, check what would fail with dry-run
kubectl label namespace psa-baseline \
  pod-security.kubernetes.io/enforce=restricted \
  --dry-run=server --overwrite

# Apply audit and warn first
kubectl label namespace psa-baseline \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite

# Check for violations in existing pods
kubectl get pods -n psa-baseline -o yaml | \
  kubectl apply --dry-run=server -f - 2>&1 | grep -i warning

# After fixing violations, enforce restricted
# kubectl label namespace psa-baseline \
#   pod-security.kubernetes.io/enforce=restricted \
#   --overwrite
```

---

## Part 2: Security Contexts

### Security Context Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                 SECURITY CONTEXT HIERARCHY                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Pod Level (spec.securityContext)                               │
│  ─────────────────────────────────                              │
│  Applied to all containers in the pod                           │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ • runAsUser / runAsGroup                                 │    │
│  │ • runAsNonRoot                                           │    │
│  │ • fsGroup / fsGroupChangePolicy                          │    │
│  │ • supplementalGroups                                     │    │
│  │ • seccompProfile                                         │    │
│  │ • sysctls                                                │    │
│  └─────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  Container Level (containers[].securityContext)                 │
│  ──────────────────────────────────────────────                 │
│  Overrides pod-level for specific container                     │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ • runAsUser / runAsGroup                                 │    │
│  │ • runAsNonRoot                                           │    │
│  │ • privileged                                             │    │
│  │ • allowPrivilegeEscalation                               │    │
│  │ • readOnlyRootFilesystem                                 │    │
│  │ • capabilities (add/drop)                                │    │
│  │ • seccompProfile                                         │    │
│  │ • seLinuxOptions                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 2.1: Configure Pod-Level Security Context

```bash
# Create pod with pod-level security context
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
  namespace: psa-baseline
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    fsGroupChangePolicy: "OnRootMismatch"
    supplementalGroups: [4000]
  containers:
  - name: demo
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF

kubectl wait --for=condition=Ready pod/security-context-demo -n psa-baseline --timeout=60s

# Check the running user
kubectl exec -n psa-baseline security-context-demo -- id
# Output: uid=1000 gid=3000 groups=2000,3000,4000

# Check file ownership
kubectl exec -n psa-baseline security-context-demo -- ls -la /data
# Files will be owned by fsGroup (2000)
```

### Step 2.2: Container-Level Security Context

```bash
# Create pod with container-level overrides
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: container-context-demo
  namespace: psa-baseline
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
  containers:
  - name: container1
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
    # Uses pod-level context
  - name: container2
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      runAsUser: 2000
      runAsGroup: 2000
      # Overrides pod-level
EOF

kubectl wait --for=condition=Ready pod/container-context-demo -n psa-baseline --timeout=60s

# Check different users in containers
kubectl exec -n psa-baseline container-context-demo -c container1 -- id
# uid=1000 gid=1000

kubectl exec -n psa-baseline container-context-demo -c container2 -- id
# uid=2000 gid=2000
```

### Step 2.3: Read-Only Root Filesystem

```bash
# Create pod with read-only root filesystem
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: readonly-fs-demo
  namespace: psa-baseline
spec:
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF

kubectl wait --for=condition=Ready pod/readonly-fs-demo -n psa-baseline --timeout=60s

# Test write to root filesystem (should fail)
kubectl exec -n psa-baseline readonly-fs-demo -- touch /test.txt 2>&1 || echo "Write blocked - as expected"

# Test write to mounted volume (should succeed)
kubectl exec -n psa-baseline readonly-fs-demo -- touch /tmp/test.txt
echo "Write to /tmp succeeded"
```

### Step 2.4: Prevent Privilege Escalation

```bash
# Create pod that prevents privilege escalation
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-privesc-demo
  namespace: psa-baseline
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      allowPrivilegeEscalation: false
      runAsUser: 1000
EOF

kubectl wait --for=condition=Ready pod/no-privesc-demo -n psa-baseline --timeout=60s

# Verify the setting
kubectl get pod no-privesc-demo -n psa-baseline -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}'
echo ""
```

---

## Part 3: Linux Capabilities

### Common Capabilities

```
┌─────────────────────────────────────────────────────────────────┐
│                    LINUX CAPABILITIES                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  DANGEROUS CAPABILITIES (avoid if possible)                     │
│  ──────────────────────────────────────────                     │
│  CAP_SYS_ADMIN    - Most dangerous, near-root                   │
│  CAP_NET_ADMIN    - Network configuration                       │
│  CAP_SYS_PTRACE   - Debug processes, read memory                │
│  CAP_DAC_OVERRIDE - Bypass file permissions                     │
│  CAP_SETUID       - Change user IDs                             │
│  CAP_SETGID       - Change group IDs                            │
│                                                                  │
│  COMMON SAFE CAPABILITIES                                       │
│  ────────────────────────                                       │
│  CAP_NET_BIND_SERVICE  - Bind to ports < 1024                   │
│  CAP_CHOWN             - Change file ownership                  │
│  CAP_SETFCAP           - Set file capabilities                  │
│                                                                  │
│  DEFAULT DOCKER CAPABILITIES (14 total):                        │
│  ─────────────────────────────────────────                       │
│  AUDIT_WRITE, CHOWN, DAC_OVERRIDE, FOWNER, FSETID,             │
│  KILL, MKNOD, NET_BIND_SERVICE, NET_RAW, SETFCAP,              │
│  SETGID, SETPCAP, SETUID, SYS_CHROOT                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 3.1: Drop All Capabilities

```bash
# Create pod dropping all capabilities
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: drop-caps-demo
  namespace: psa-baseline
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      capabilities:
        drop:
        - ALL
EOF

kubectl wait --for=condition=Ready pod/drop-caps-demo -n psa-baseline --timeout=60s

# Check capabilities (will be empty)
kubectl exec -n psa-baseline drop-caps-demo -- cat /proc/1/status | grep -i cap
```

### Step 3.2: Add Specific Capabilities

```bash
# Create pod with NET_BIND_SERVICE capability
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: net-bind-demo
  namespace: psa-baseline
spec:
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      runAsUser: 0  # Need root to use capability
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
EOF

kubectl wait --for=condition=Ready pod/net-bind-demo -n psa-baseline --timeout=60s

# Check capabilities
kubectl exec -n psa-baseline net-bind-demo -- cat /proc/1/status | grep -i cap

# Nginx can bind to port 80 despite minimal capabilities
kubectl exec -n psa-baseline net-bind-demo -- netstat -tlnp 2>/dev/null || \
kubectl exec -n psa-baseline net-bind-demo -- ss -tlnp
```

### Step 3.3: Compare Capability Sets

```bash
# Create pod with default capabilities
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: default-caps-demo
  namespace: psa-baseline
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
EOF

kubectl wait --for=condition=Ready pod/default-caps-demo -n psa-baseline --timeout=60s

# Compare capabilities
echo "=== Default Capabilities ==="
kubectl exec -n psa-baseline default-caps-demo -- cat /proc/1/status | grep Cap

echo ""
echo "=== Dropped Capabilities ==="
kubectl exec -n psa-baseline drop-caps-demo -- cat /proc/1/status | grep Cap
```

### Step 3.4: Capability Audit Script

```bash
# Script to audit capabilities across pods
cat > /tmp/audit-caps.sh <<'EOF'
#!/bin/bash

echo "=== Pod Capability Audit ==="
echo ""

for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
  pods=$(kubectl get pods -n $ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  for pod in $pods; do
    caps=$(kubectl get pod $pod -n $ns -o jsonpath='{range .spec.containers[*]}{.name}: add={.securityContext.capabilities.add} drop={.securityContext.capabilities.drop}{"\n"}{end}' 2>/dev/null)
    if [ -n "$caps" ]; then
      echo "Namespace: $ns, Pod: $pod"
      echo "$caps"
      echo ""
    fi
  done
done
EOF

chmod +x /tmp/audit-caps.sh
```

---

## Part 4: Seccomp Profiles

### Seccomp Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECCOMP PROFILES                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Profile Types:                                                  │
│  ─────────────                                                   │
│                                                                  │
│  RuntimeDefault                                                  │
│  ├── Container runtime's default profile                        │
│  ├── Blocks dangerous syscalls                                  │
│  └── Recommended minimum                                        │
│                                                                  │
│  Localhost                                                       │
│  ├── Custom profile from node filesystem                        │
│  ├── Path: /var/lib/kubelet/seccomp/                            │
│  └── Fine-grained syscall control                               │
│                                                                  │
│  Unconfined                                                      │
│  ├── No seccomp filtering                                       │
│  └── NOT recommended for production                             │
│                                                                  │
│  Syscall Actions:                                                │
│  ────────────────                                                │
│  SCMP_ACT_ALLOW  - Allow the syscall                            │
│  SCMP_ACT_ERRNO  - Block and return error                       │
│  SCMP_ACT_LOG    - Allow but log                                │
│  SCMP_ACT_KILL   - Kill the process                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 4.1: Apply RuntimeDefault Seccomp

```bash
# Create pod with RuntimeDefault seccomp
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-runtime-default
  namespace: psa-baseline
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
EOF

kubectl wait --for=condition=Ready pod/seccomp-runtime-default -n psa-baseline --timeout=60s

# Verify seccomp is applied
kubectl get pod seccomp-runtime-default -n psa-baseline -o jsonpath='{.spec.securityContext.seccompProfile}'
echo ""
```

### Step 4.2: Create Custom Seccomp Profile

```bash
# Custom seccomp profile (would be placed on node at /var/lib/kubelet/seccomp/)
cat > /tmp/custom-seccomp.json <<EOF
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": [
    "SCMP_ARCH_X86_64",
    "SCMP_ARCH_X86",
    "SCMP_ARCH_AARCH64"
  ],
  "syscalls": [
    {
      "names": [
        "read",
        "write",
        "open",
        "close",
        "stat",
        "fstat",
        "lstat",
        "poll",
        "lseek",
        "mmap",
        "mprotect",
        "munmap",
        "brk",
        "rt_sigaction",
        "rt_sigprocmask",
        "rt_sigreturn",
        "ioctl",
        "access",
        "pipe",
        "select",
        "sched_yield",
        "mremap",
        "msync",
        "mincore",
        "madvise",
        "dup",
        "dup2",
        "pause",
        "nanosleep",
        "getitimer",
        "alarm",
        "setitimer",
        "getpid",
        "sendfile",
        "socket",
        "connect",
        "accept",
        "sendto",
        "recvfrom",
        "sendmsg",
        "recvmsg",
        "shutdown",
        "bind",
        "listen",
        "getsockname",
        "getpeername",
        "socketpair",
        "setsockopt",
        "getsockopt",
        "clone",
        "fork",
        "vfork",
        "execve",
        "exit",
        "wait4",
        "kill",
        "uname",
        "fcntl",
        "flock",
        "fsync",
        "fdatasync",
        "truncate",
        "ftruncate",
        "getdents",
        "getcwd",
        "chdir",
        "fchdir",
        "rename",
        "mkdir",
        "rmdir",
        "creat",
        "unlink",
        "symlink",
        "readlink",
        "chmod",
        "fchmod",
        "chown",
        "fchown",
        "lchown",
        "umask",
        "gettimeofday",
        "getrlimit",
        "getrusage",
        "sysinfo",
        "times",
        "getuid",
        "syslog",
        "getgid",
        "setuid",
        "setgid",
        "geteuid",
        "getegid",
        "setpgid",
        "getppid",
        "getpgrp",
        "setsid",
        "setreuid",
        "setregid",
        "getgroups",
        "setgroups",
        "setresuid",
        "getresuid",
        "setresgid",
        "getresgid",
        "getpgid",
        "setfsuid",
        "setfsgid",
        "getsid",
        "capget",
        "capset",
        "rt_sigpending",
        "rt_sigtimedwait",
        "rt_sigqueueinfo",
        "rt_sigsuspend",
        "sigaltstack",
        "utime",
        "mknod",
        "uselib",
        "personality",
        "ustat",
        "statfs",
        "fstatfs",
        "sysfs",
        "getpriority",
        "setpriority",
        "sched_setparam",
        "sched_getparam",
        "sched_setscheduler",
        "sched_getscheduler",
        "sched_get_priority_max",
        "sched_get_priority_min",
        "sched_rr_get_interval",
        "mlock",
        "munlock",
        "mlockall",
        "munlockall",
        "vhangup",
        "pivot_root",
        "prctl",
        "arch_prctl",
        "adjtimex",
        "setrlimit",
        "chroot",
        "sync",
        "acct",
        "settimeofday",
        "mount",
        "umount2",
        "swapon",
        "swapoff",
        "reboot",
        "sethostname",
        "setdomainname",
        "iopl",
        "ioperm",
        "create_module",
        "init_module",
        "delete_module",
        "get_kernel_syms",
        "query_module",
        "quotactl",
        "nfsservctl",
        "getpmsg",
        "putpmsg",
        "afs_syscall",
        "tuxcall",
        "security",
        "gettid",
        "readahead",
        "setxattr",
        "lsetxattr",
        "fsetxattr",
        "getxattr",
        "lgetxattr",
        "fgetxattr",
        "listxattr",
        "llistxattr",
        "flistxattr",
        "removexattr",
        "lremovexattr",
        "fremovexattr",
        "tkill",
        "time",
        "futex",
        "sched_setaffinity",
        "sched_getaffinity",
        "set_thread_area",
        "io_setup",
        "io_destroy",
        "io_getevents",
        "io_submit",
        "io_cancel",
        "get_thread_area",
        "lookup_dcookie",
        "epoll_create",
        "epoll_ctl_old",
        "epoll_wait_old",
        "remap_file_pages",
        "getdents64",
        "set_tid_address",
        "restart_syscall",
        "semtimedop",
        "fadvise64",
        "timer_create",
        "timer_settime",
        "timer_gettime",
        "timer_getoverrun",
        "timer_delete",
        "clock_settime",
        "clock_gettime",
        "clock_getres",
        "clock_nanosleep",
        "exit_group",
        "epoll_wait",
        "epoll_ctl",
        "tgkill",
        "utimes",
        "mbind",
        "set_mempolicy",
        "get_mempolicy",
        "mq_open",
        "mq_unlink",
        "mq_timedsend",
        "mq_timedreceive",
        "mq_notify",
        "mq_getsetattr",
        "kexec_load",
        "waitid",
        "add_key",
        "request_key",
        "keyctl",
        "ioprio_set",
        "ioprio_get",
        "inotify_init",
        "inotify_add_watch",
        "inotify_rm_watch",
        "migrate_pages",
        "openat",
        "mkdirat",
        "mknodat",
        "fchownat",
        "futimesat",
        "newfstatat",
        "unlinkat",
        "renameat",
        "linkat",
        "symlinkat",
        "readlinkat",
        "fchmodat",
        "faccessat",
        "pselect6",
        "ppoll",
        "unshare",
        "set_robust_list",
        "get_robust_list",
        "splice",
        "tee",
        "sync_file_range",
        "vmsplice",
        "move_pages",
        "utimensat",
        "epoll_pwait",
        "signalfd",
        "timerfd_create",
        "eventfd",
        "fallocate",
        "timerfd_settime",
        "timerfd_gettime",
        "accept4",
        "signalfd4",
        "eventfd2",
        "epoll_create1",
        "dup3",
        "pipe2",
        "inotify_init1",
        "preadv",
        "pwritev",
        "rt_tgsigqueueinfo",
        "perf_event_open",
        "recvmmsg",
        "fanotify_init",
        "fanotify_mark",
        "prlimit64",
        "name_to_handle_at",
        "open_by_handle_at",
        "clock_adjtime",
        "syncfs",
        "sendmmsg",
        "setns",
        "getcpu",
        "process_vm_readv",
        "process_vm_writev",
        "kcmp",
        "finit_module",
        "sched_setattr",
        "sched_getattr",
        "renameat2",
        "seccomp",
        "getrandom",
        "memfd_create",
        "kexec_file_load",
        "bpf",
        "execveat",
        "userfaultfd",
        "membarrier",
        "mlock2",
        "copy_file_range",
        "preadv2",
        "pwritev2",
        "pkey_mprotect",
        "pkey_alloc",
        "pkey_free",
        "statx"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF

echo "Custom seccomp profile created at /tmp/custom-seccomp.json"
echo "To use: Copy to /var/lib/kubelet/seccomp/ on worker nodes"
```

### Step 4.3: Using Localhost Seccomp Profile

```bash
# Example of using localhost seccomp profile (requires profile on node)
cat <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-localhost
  namespace: psa-baseline
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/custom-seccomp.json
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
EOF
```

---

## Part 5: AppArmor Profiles

### AppArmor Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    APPARMOR PROFILES                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Profile Modes:                                                  │
│  ─────────────                                                   │
│                                                                  │
│  Enforce Mode                                                    │
│  ├── Violations are blocked and logged                         │
│  └── Used in production                                         │
│                                                                  │
│  Complain Mode                                                   │
│  ├── Violations are logged but allowed                          │
│  └── Used for testing profiles                                  │
│                                                                  │
│  Unconfined                                                      │
│  ├── No AppArmor restrictions                                   │
│  └── Default without profile                                    │
│                                                                  │
│  Profile Types in Kubernetes:                                   │
│  ────────────────────────────                                   │
│  runtime/default  - Container runtime's default                 │
│  localhost/<name> - Custom profile from node                    │
│  unconfined       - No AppArmor                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 5.1: Check AppArmor Status

```bash
# Check if AppArmor is enabled on nodes
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}: {.status.nodeInfo.containerRuntimeVersion}{"\n"}{end}'

# Check AppArmor profiles on a node (if you have node access)
# aa-status (on the node)
```

### Step 5.2: Apply AppArmor Profile

```bash
# Pod with runtime/default AppArmor profile
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-demo
  namespace: psa-baseline
  annotations:
    # Legacy annotation (still supported)
    container.apparmor.security.beta.kubernetes.io/app: runtime/default
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
EOF

kubectl wait --for=condition=Ready pod/apparmor-demo -n psa-baseline --timeout=60s

# Verify AppArmor is applied
kubectl get pod apparmor-demo -n psa-baseline -o yaml | grep -A2 "annotations"
```

### Step 5.3: Create Custom AppArmor Profile

```bash
# Example custom AppArmor profile
cat > /tmp/deny-write.profile <<'EOF'
#include <tunables/global>

profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # Deny all write operations
  deny /** w,
  
  # Allow network access
  network,
}
EOF

echo "Custom AppArmor profile created"
echo "To use: Load on worker nodes with 'apparmor_parser -r deny-write.profile'"
```

### Step 5.4: AppArmor with Security Context (Kubernetes 1.30+)

```bash
# New API (Kubernetes 1.30+)
cat <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-new-api
  namespace: psa-baseline
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      appArmorProfile:
        type: RuntimeDefault
EOF
```

---

## Part 6: Complete Security Example

### Step 6.1: Production-Ready Secure Pod

```bash
# Create a fully secured pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: psa-restricted
  labels:
    app: secure-app
spec:
  # Pod-level security
  securityContext:
    runAsNonRoot: true
    runAsUser: 10000
    runAsGroup: 10000
    fsGroup: 10000
    seccompProfile:
      type: RuntimeDefault
  
  # Disable service account token
  automountServiceAccountToken: false
  
  containers:
  - name: app
    image: nginx:alpine
    
    # Container-level security
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    
    # Resource limits
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
    
    # Health probes
    livenessProbe:
      httpGet:
        path: /
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /
        port: 8080
      initialDelaySeconds: 3
      periodSeconds: 5
    
    # Writable directories
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
    - name: config
      mountPath: /etc/nginx/conf.d
      readOnly: true
  
  volumes:
  - name: tmp
    emptyDir:
      sizeLimit: "100Mi"
  - name: cache
    emptyDir:
      sizeLimit: "100Mi"
  - name: run
    emptyDir:
      sizeLimit: "10Mi"
  - name: config
    configMap:
      name: nginx-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: psa-restricted
data:
  default.conf: |
    server {
      listen 8080;
      server_name localhost;
      
      location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
      }
    }
EOF
```

### Step 6.2: Secure Deployment Template

```bash
# Secure deployment template
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-deployment
  namespace: psa-baseline
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      
      serviceAccountName: default
      automountServiceAccountToken: false
      
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 8080
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
      
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
EOF
```

---

## Verification

### Check Namespace Security

```bash
# Verify namespace labels
kubectl get ns psa-privileged psa-baseline psa-restricted --show-labels

# Check for PSA violations
kubectl get events -A --field-selector reason=FailedCreate | grep -i security
```

### Check Pod Security Settings

```bash
# Audit all pods for security settings
kubectl get pods -A -o custom-columns=\
'NAMESPACE:.metadata.namespace,'\
'NAME:.metadata.name,'\
'USER:.spec.securityContext.runAsUser,'\
'NON-ROOT:.spec.securityContext.runAsNonRoot,'\
'SECCOMP:.spec.securityContext.seccompProfile.type'
```

---

## Common Issues and Solutions

### Issue 1: Pod Rejected by PSA

**Symptoms:** Pod creation fails with "violates PodSecurity" error

**Solutions:**
1. Check namespace PSA labels
2. Review pod security context
3. Ensure all containers comply

```bash
# Debug PSA rejection
kubectl --dry-run=server apply -f pod.yaml
```

### Issue 2: Read-Only Filesystem Breaks App

**Symptoms:** Application fails to start with read-only filesystem

**Solutions:**
1. Identify write paths (logs, temp files, cache)
2. Mount emptyDir for writable paths
3. Check app documentation for file requirements

### Issue 3: Capability Required

**Symptoms:** Application needs specific capability

**Solutions:**
1. Identify minimum required capability
2. Drop ALL then add specific one
3. Document why capability is needed

---

## Cleanup

```bash
# Remove lab resources
kubectl delete namespace psa-privileged psa-baseline psa-restricted

rm -f /tmp/privileged-pod.yaml /tmp/baseline-pod.yaml
rm -f /tmp/custom-seccomp.json /tmp/deny-write.profile
rm -f /tmp/audit-caps.sh
```

---

## Key Takeaways

1. **Pod Security Standards** - Use Restricted for sensitive workloads
2. **Security Contexts** - Apply at both pod and container level
3. **Capabilities** - Drop ALL, add only what's needed
4. **Seccomp** - Use RuntimeDefault at minimum
5. **Read-Only Root** - Enable with emptyDir for write paths

---

## Next Steps

Continue to [Lab 3: Network Security](../lab-03-network-security/README.md) to learn about Network Policies and network segmentation.

---

## Additional Resources

- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Security Contexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Seccomp Profiles](https://kubernetes.io/docs/tutorials/security/seccomp/)
