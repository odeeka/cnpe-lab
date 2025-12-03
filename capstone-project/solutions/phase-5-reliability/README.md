# Phase 5: Reliability Solutions

This directory contains the reliability and disaster recovery configuration for the BookStore application.

## Directory Structure

```
phase-5-reliability/
├── velero/
│   ├── velero-config.yaml        # Velero installation config
│   ├── backup-schedule.yaml      # Scheduled backup configuration
│   └── restore-procedures.yaml   # Restore procedures
├── chaos/
│   ├── litmus-experiments.yaml   # Chaos engineering experiments
│   └── chaos-schedule.yaml       # Scheduled chaos tests
└── high-availability/
    ├── pod-topology.yaml         # Pod topology spread constraints
    └── priority-classes.yaml     # Pod priority classes
```

## Quick Deploy

```bash
# Install Velero
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.7.0 \
  --bucket bookstore-backups \
  --backup-location-config region=us-west-2 \
  --snapshot-location-config region=us-west-2 \
  --secret-file ./credentials-velero

# Apply backup schedules
kubectl apply -f velero/backup-schedule.yaml

# Install LitmusChaos
helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
helm install chaos litmuschaos/litmus -n litmus --create-namespace

# Apply HA configurations
kubectl apply -f high-availability/
```
