# AC3 Model Configuration - Deployment Guide

## Overview
This project provides a comprehensive monitoring and configuration solution for AC3 models, featuring Spring Boot applications with Prometheus metrics, Grafana dashboards, and power consumption monitoring via Kepler.

## Architecture Components

### Core Application
- **Spring Boot Application**: RESTful service with actuator endpoints
- **Prometheus Metrics**: Application and JVM metrics exposure
- **Kafka Integration**: Message streaming capabilities

### Monitoring Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Kepler**: Kubernetes power consumption monitoring

## Prerequisites

### Local Development
- Java 24
- Maven 3.6+
- Docker & Docker Compose

### Kubernetes Deployment
- Kubernetes cluster (v1.20+)
- kubectl configured
- Helm 3.x
- Sufficient cluster resources for monitoring stack

## Quick Start

### 1. Local Development Setup

```bash
# Clone and build the application
cd exampleconfig
mvn clean install

# Run locally
mvn spring-boot:run
```

The application will be available at:
- **Application**: http://localhost:8080
- **Health Check**: http://localhost:8080/actuator/health
- **Metrics**: http://localhost:8080/actuator/prometheus

### 2. Docker Deployment

```bash
# Build Docker image
docker build -t ac3-model-config:latest ./exampleconfig

# Run with Docker Compose (includes monitoring stack)
docker-compose up -d
```

**Services Available:**
- **Application**: http://localhost:8080
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)

### 3. Kubernetes Deployment

#### Step 1: Deploy Core Monitoring Stack

```bash
# Deploy Prometheus Stack with Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  -f helm/prometheus-values.yaml \
  --namespace monitoring --create-namespace
```

#### Step 2: Deploy Kepler Power Monitoring

```bash
# Create monitoring namespace for Kepler
kubectl create namespace newmonitoring

# Deploy Kepler DaemonSet for power consumption monitoring
kubectl apply -f k8s/kepler-daemonset.yaml
kubectl apply -f k8s/kepler-service.yaml
kubectl apply -f k8s/kepler-servicemonitor.yaml
```

#### Step 3: Deploy Application

```bash
# Deploy the Spring Boot application
kubectl apply -f k8s/app-deployment.yaml
kubectl apply -f k8s/app-service.yaml
kubectl apply -f k8s/app-servicemonitor.yaml
```

## Monitoring and Observability

### Application Metrics
The Spring Boot application exposes the following metrics:

- **JVM Metrics**: Memory, GC, threads
- **HTTP Metrics**: Request counts, latencies, status codes
- **Custom Business Metrics**: Application-specific measurements
- **Health Checks**: Comprehensive health monitoring

### Infrastructure Metrics
- **Node Metrics**: CPU, memory, disk, network via node-exporter
- **Kubernetes Metrics**: Pod, service, deployment status
- **Power Consumption**: Per-pod and per-node power usage via Kepler

### Power Monitoring with Kepler

Kepler provides comprehensive power consumption monitoring:

**Key Metrics Available:**
- `kepler_container_joules_total` - Energy consumption by container
- `kepler_node_power_watts` - Current power consumption by node
- `kepler_container_cpu_cycles_total` - CPU cycles per container
- `kepler_container_gpu_joules_total` - GPU energy consumption
- `kepler_process_power_watts` - Process-level power consumption

**Viewing Power Metrics:**
```bash
# Check Kepler pod status
kubectl get pods -n newmonitoring -l app=kepler-exporter

# View Kepler logs
kubectl logs -n newmonitoring -l app=kepler-exporter

# Access Kepler metrics directly
kubectl port-forward -n newmonitoring svc/kepler-exporter 9102:9102
curl http://localhost:9102/metrics | grep kepler_
```

### Grafana Dashboards

Access Grafana at http://localhost:3000 (or your configured ingress):

**Default Dashboards:**
- **Application Dashboard**: Spring Boot metrics and health
- **Kubernetes Cluster Overview**: Node and pod status
- **Power Consumption Dashboard**: Energy usage and efficiency metrics

**Importing Additional Dashboards:**
```bash
# Import Kepler power monitoring dashboard
# Dashboard ID: 18700 (from grafana.com)
```

## Configuration

### Application Configuration

Key configuration files:
- `application.properties`: Spring Boot configuration
- `pom.xml`: Maven dependencies and build configuration

**Important Settings:**
```properties
# Actuator endpoints
management.endpoints.web.exposure.include=*
management.endpoint.health.show-details=always
management.health.probes.enabled=true

# Server configuration
server.port=8080
server.address=0.0.0.0
```

### Monitoring Configuration

**Prometheus Configuration:**
- `helm/prometheus-values.yaml`: Prometheus Helm values
- Service discovery for both `monitoring` and `newmonitoring` namespaces
- Retention: 15 days local storage

**Kepler Configuration:**
- Runs as DaemonSet on all nodes
- Requires privileged access for hardware metrics
- Metrics exposed on port 9102

## Troubleshooting

### Common Issues

**1. Kubectl Access Issues**
```bash
# Check cluster connection
kubectl cluster-info

# Verify kubeconfig
kubectl config current-context

# Check if cluster is running (for local clusters)
docker ps | grep k8s
minikube status  # if using minikube
```

**2. Kepler Not Collecting Metrics**
```bash
# Check Kepler pod status
kubectl get pods -n newmonitoring

# Check Kepler logs for errors
kubectl logs -n newmonitoring -l app=kepler-exporter

# Verify node permissions
kubectl describe daemonset kepler-exporter -n newmonitoring
```

**3. Prometheus Not Scraping Kepler**
```bash
# Check ServiceMonitor
kubectl get servicemonitor -n newmonitoring

# Verify Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Visit http://localhost:9090/targets
```

**4. Application Metrics Missing**
```bash
# Check application health
kubectl get pods -l app=ac3-model-config

# Verify actuator endpoints
kubectl port-forward svc/ac3-model-config-service 8080:8080
curl http://localhost:8080/actuator/health
curl http://localhost:8080/actuator/prometheus
```

### Log Collection
```bash
# Application logs
kubectl logs -l app=ac3-model-config

# Monitoring stack logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Kepler logs
kubectl logs -n newmonitoring -l app=kepler-exporter
```

## Security Considerations

### RBAC Configuration
- Kepler requires cluster-wide read permissions for node metrics
- Prometheus requires access to both monitoring namespaces
- Application uses minimal required permissions

### Network Policies
- Monitoring traffic isolated within appropriate namespaces
- Kepler communicates only with Prometheus
- External access controlled via services/ingress

## Scaling and Performance

### Resource Requirements

**Minimum Requirements:**
- **Application**: 100m CPU, 128Mi memory
- **Prometheus**: 500m CPU, 1Gi memory
- **Kepler**: 100m CPU, 128Mi memory per node
- **Grafana**: 100m CPU, 128Mi memory

**Recommended for Production:**
- **Application**: 500m CPU, 512Mi memory
- **Prometheus**: 2 CPU, 4Gi memory
- **Kepler**: 200m CPU, 256Mi memory per node
- **Grafana**: 500m CPU, 512Mi memory

### High Availability
- Prometheus configured with multiple replicas
- Application can be scaled horizontally

## Maintenance

### Regular Tasks
- Monitor disk usage for Prometheus storage
- Review and update Grafana dashboards
- Check Kepler power consumption accuracy
- Update Helm charts and container images

### Backup Strategy
- Prometheus data: Regular snapshots of local storage
- Grafana dashboards: Version controlled as JSON
- Application configuration: Stored in Git

## Support and Documentation

### Additional Resources
- [Spring Boot Actuator Documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Kepler Documentation](https://sustainable-computing.io/kepler/)
- [Grafana Dashboard Management](https://grafana.com/docs/grafana/latest/dashboards/)

### Monitoring Best Practices
- Set up alerting for critical metrics
- Monitor power efficiency trends with Kepler
- Regularly review and optimize resource usage
- Plan capacity based on local Prometheus metrics
   kubectl describe pod -n app -l app=springboot
   ```

2. **Health check failing**: Verify actuator endpoints
   ```bash
   kubectl logs -n app -l app=springboot
   ```

3. **Metrics not showing**: Check ServiceMonitor and labels
   ```bash
   kubectl get servicemonitor -n newmonitoring
   kubectl describe servicemonitor springboot-servicemonitor -n newmonitoring
   ```

4. **Network issues**: Check service and endpoint configuration
   ```bash
   kubectl get endpoints -n app
   kubectl get svc -n app
   ```

## Scaling

The application includes Horizontal Pod Autoscaler (HPA):

```bash
# Check HPA status
kubectl get hpa -n app

# Manual scaling
kubectl scale deployment springboot-app --replicas=3 -n app
```

## Cleanup

To remove all deployed resources:

```bash
# Remove application
kubectl delete -f k8s/app-deployment.yaml
kubectl delete -f k8s/app-configmap.yaml

# Remove monitoring (if using Helm)
helm uninstall prometheus -n newmonitoring

# Remove namespaces
kubectl delete -f k8s/namespace.yaml
```

## Notes

- The application exposes metrics at `/actuator/prometheus`
- Health checks are available at `/actuator/health`
- Prometheus is configured to send metrics to Thanos at `http://82.223.13.241:10908/api/v1/receive`
- The application uses Java 24 and Spring Boot 3.5.6