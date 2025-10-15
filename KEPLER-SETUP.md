# Kepler Power Monitoring Setup Guide

## Overview
Kepler (Kubernetes-based Efficient Power Level Exporter) provides real-time power consumption monitoring for Kubernetes workloads, enabling energy efficiency analysis and carbon footprint tracking.

## What Kepler Provides

### Power Metrics
- **Container-level**: Power consumption per pod/container
- **Node-level**: Total node power consumption
- **Process-level**: Fine-grained process power usage
- **Component-level**: CPU, GPU, memory power breakdown

### Key Use Cases
- **Energy Efficiency**: Identify power-hungry workloads
- **Cost Optimization**: Correlate power usage with cloud costs
- **Carbon Footprint**: Track environmental impact
- **Capacity Planning**: Understand power requirements for scaling

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Kubernetes    │    │   Prometheus    │    │    Grafana      │
│     Nodes       │────│   (Scraping)    │────│  (Dashboard)    │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │   Kepler    │ │    │ │ Service     │ |    │ │ Power Usage │ │
│ │ DaemonSet   │ │    │ │ Monitor     │ │    │ │ Dashboard   │ │
│ │ (Port 9102) │ │    │ │             │ │    │ │             │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Deployment Steps

### 1. Prerequisites Check

```bash
# Verify cluster access
kubectl cluster-info

# Check if nodes support power monitoring
kubectl get nodes -o wide

# Verify privileged containers are allowed
kubectl auth can-i create pods/privileged --as=system:serviceaccount:newmonitoring:kepler-sa
```

### 2. Deploy Kepler Components

```bash
# Create namespace
kubectl create namespace newmonitoring

# Deploy Kepler DaemonSet
kubectl apply -f k8s/kepler-daemonset.yaml

# Deploy Service
kubectl apply -f k8s/kepler-service.yaml

# Deploy ServiceMonitor for Prometheus
kubectl apply -f k8s/kepler-servicemonitor.yaml
```

### 3. Verify Deployment

```bash
# Check pod status
kubectl get pods -n newmonitoring -l app=kepler-exporter

# Check logs
kubectl logs -n newmonitoring -l app=kepler-exporter

# Verify metrics endpoint
kubectl port-forward -n newmonitoring svc/kepler-exporter 9102:9102
curl http://localhost:9102/metrics | grep kepler_
```

## Key Metrics Reference

### Container Metrics
```
kepler_container_joules_total{container="my-app"} - Total energy consumed
kepler_container_cpu_cycles_total{container="my-app"} - CPU cycles used
kepler_container_cpu_time_seconds_total{container="my-app"} - CPU time
kepler_container_memory_working_set_bytes{container="my-app"} - Memory usage
```

### Node Metrics
```
kepler_node_power_watts{instance="node1"} - Current power consumption
kepler_node_energy_joules_total{instance="node1"} - Cumulative energy
kepler_node_cpu_power_watts{instance="node1"} - CPU power only
kepler_node_gpu_power_watts{instance="node1"} - GPU power only
```

### Process Metrics
```
kepler_process_power_watts{pid="1234"} - Process power consumption
kepler_process_cpu_cycles_total{pid="1234"} - Process CPU cycles
```

## Prometheus Queries

### Useful PromQL Queries

**Top 10 Power-Consuming Containers:**
```promql
topk(10, rate(kepler_container_joules_total[5m]))
```

**Node Power Consumption Over Time:**
```promql
kepler_node_power_watts
```

**Average Power per Pod:**
```promql
avg by (pod) (kepler_container_joules_total)
```

**Power Efficiency (Operations per Watt):**
```promql
rate(http_requests_total[5m]) / rate(kepler_container_joules_total[5m])
```

## Grafana Dashboard Setup

### Import Kepler Dashboard

1. **Access Grafana**: http://localhost:3000
2. **Import Dashboard**: Use ID `18700` from grafana.com
3. **Configure Data Source**: Select your Prometheus instance

### Custom Dashboard Panels

**Power Consumption Timeline:**
```json
{
  "title": "Container Power Consumption",
  "type": "graph",
  "targets": [
    {
      "expr": "rate(kepler_container_joules_total[5m])",
      "legendFormat": "{{container}}"
    }
  ]
}
```

**Power Efficiency Heatmap:**
```json
{
  "title": "Power Efficiency by Node",
  "type": "heatmap",
  "targets": [
    {
      "expr": "kepler_node_power_watts / kepler_node_cpu_utilization"
    }
  ]
}
```

## Alerting Rules

### Sample Prometheus Alerts

```yaml
# filepath: k8s/kepler-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kepler-alerts
  namespace: newmonitoring
spec:
  groups:
  - name: kepler.rules
    rules:
    - alert: HighPowerConsumption
      expr: kepler_node_power_watts > 200
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High power consumption on node {{ $labels.instance }}"
        description: "Node {{ $labels.instance }} is consuming {{ $value }}W"
    
    - alert: PowerConsumptionSpike
      expr: increase(kepler_container_joules_total[10m]) > 1000
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Power consumption spike in container {{ $labels.container }}"
        description: "Container {{ $labels.container }} power usage increased by {{ $value }}J"
```

## Troubleshooting

### Common Issues

**1. Kepler Pods Not Starting**
```bash
# Check node selectors
kubectl describe daemonset kepler-exporter -n newmonitoring

# Verify privileged security context
kubectl get pods -n newmonitoring -o yaml | grep privileged

# Check node taints
kubectl describe nodes | grep Taints
```

**2. No Power Metrics Available**
```bash
# Check if hardware supports power monitoring
kubectl exec -n newmonitoring <kepler-pod> -- cat /sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj

# Verify sysfs mounts
kubectl exec -n newmonitoring <kepler-pod> -- ls -la /sys/fs/cgroup/
```

**3. Prometheus Not Scraping**
```bash
# Check ServiceMonitor labels
kubectl get servicemonitor -n newmonitoring -o yaml

# Verify Prometheus configuration
kubectl get prometheus -o yaml | grep namespaceSelector

# Check Prometheus targets
curl http://prometheus:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="kepler")'
```

### Debug Commands

```bash
# Check Kepler metrics directly
kubectl port-forward -n newmonitoring svc/kepler-exporter 9102:9102
curl -s http://localhost:9102/metrics | grep -E "(kepler_node_power|kepler_container_joules)"

# Monitor Kepler logs in real-time
kubectl logs -n newmonitoring -l app=kepler-exporter -f

# Check resource usage
kubectl top pods -n newmonitoring
```

## Performance Optimization

### Resource Tuning

**CPU Requests/Limits:**
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

**Metrics Collection Interval:**
```yaml
env:
- name: KEPLER_METRICS_INTERVAL
  value: "30s"  # Adjust based on requirements
```

### Scaling Considerations

- **Node Count**: Kepler scales linearly with node count
- **Metrics Retention**: Consider Prometheus storage requirements
- **Network Bandwidth**: Monitor scraping overhead

## Security Best Practices

### RBAC Configuration
- Minimal required permissions for Kepler ServiceAccount
- Cluster-wide read access for node metrics only
- No write permissions required

### Security Context
```yaml
securityContext:
  privileged: true  # Required for hardware access
  runAsUser: 0      # Required for sysfs access
  capabilities:
    add: ["SYS_ADMIN"]
```

### Network Security
- Kepler only needs outbound metrics exposure
- No external network access required
- Metrics endpoint should be internal only

## Integration Examples

### Cost Analysis Integration
```promql
# Calculate cost per joule (example rates)
(rate(kepler_container_joules_total[1h]) * 0.0001) * on(node) group_left(instance_type) kube_node_labels
```

### Carbon Footprint Calculation
```promql
# Estimate CO2 emissions (example carbon intensity)
rate(kepler_node_power_watts[1h]) * 0.000233 # kg CO2 per Wh (varies by region)
```

### Workload Optimization
```promql
# Power efficiency per request
rate(http_requests_total[5m]) / rate(kepler_container_joules_total[5m])
```

## References

- [Kepler Official Documentation](https://sustainable-computing.io/kepler/)
- [Kepler GitHub Repository](https://github.com/sustainable-computing-io/kepler)
- [CNCF Energy Efficiency Working Group](https://github.com/cncf/tag-env-sustainability)
- [Green Software Foundation](https://greensoftware.foundation/)