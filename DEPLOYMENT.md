# Kubernetes Deployment Guide

This guide will help you deploy the Spring Boot application with monitoring to your Kubernetes cluster.

## Prerequisites

1. **Kubernetes cluster** running on your VM
2. **kubectl** configured to access your cluster
3. **Docker** installed for building images
4. **Helm** (optional, for Prometheus monitoring)

## Step 1: Build the Docker Image

```bash
# Navigate to the application directory
cd exampleconfig

# Build the Docker image
docker build -t ac3modelcofiguration:latest .

# If using a remote registry, tag and push:
# docker tag ac3modelcofiguration:latest your-registry/ac3modelcofiguration:latest
# docker push your-registry/ac3modelcofiguration:latest
```

## Step 2: Create Kubernetes Namespaces

```bash
kubectl apply -f k8s/namespace.yaml
```

This creates:
- `app` namespace for the application
- `newmonitoring` namespace for monitoring components

## Step 3: Deploy the Application

```bash
# Apply the configuration
kubectl apply -f k8s/app-configmap.yaml

# Deploy the application
kubectl apply -f k8s/app-deployment.yaml
```

## Step 4: Verify Deployment

```bash
# Check if pods are running
kubectl get pods -n app

# Check service
kubectl get svc -n app

# Check deployment status
kubectl get deployment -n app

# View logs
kubectl logs -n app deployment/springboot-app
```

## Step 5: Access the Application

```bash
# Port forward to access the application locally
kubectl port-forward -n app svc/springboot-svc 8080:8080

# Test the application
curl http://localhost:8080/actuator/health
curl http://localhost:8080/actuator/prometheus
```

## Step 6: Deploy Monitoring (Optional)

### Option A: Using Helm (Recommended)

```bash
# Add the Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace if not exists
kubectl create namespace newmonitoring

# Apply the Thanos secret for remote write
kubectl apply -f k8s/secret-thanos.yaml

# Install Prometheus using Helm
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace newmonitoring \
  --values helm/prometheus-values.yaml

# Apply ServiceMonitor for application monitoring
kubectl apply -f k8s/service-monitor.yaml
```

### Option B: Manual Prometheus Deployment

If you prefer not to use Helm, you can deploy Prometheus manually:

```bash
# Apply all monitoring components
kubectl apply -f k8s/secret-thanos.yaml
kubectl apply -f k8s/service-monitor.yaml

# Note: You'll need to deploy Prometheus Operator manually
# This is more complex and Helm is recommended
```

## Step 7: Verify Monitoring

```bash
# Check if Prometheus is running
kubectl get pods -n newmonitoring

# Port forward to access Prometheus UI
kubectl port-forward -n newmonitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Access Prometheus at http://localhost:9090
# Check if your application metrics are being scraped
```

## Troubleshooting

### Common Issues:

1. **Pod not starting**: Check image availability
   ```bash
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