#!/bin/bash

# deploy-monitoring.sh - Deploy Prometheus monitoring stack
set -e

echo "📊 Starting deployment of monitoring stack..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_warning "Helm is not installed. Installing monitoring components manually..."
    HELM_AVAILABLE=false
else
    HELM_AVAILABLE=true
fi

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

print_status "Project root: $PROJECT_ROOT"

# Ensure monitoring namespace exists
print_status "Ensuring monitoring namespace exists..."
kubectl apply -f "$PROJECT_ROOT/k8s/namespace.yaml"

# Deploy Thanos secret
print_status "Deploying Thanos remote write secret..."
if kubectl apply -f "$PROJECT_ROOT/k8s/secret-thanos.yaml"; then
    print_success "Thanos secret deployed"
else
    print_error "Failed to deploy Thanos secret"
    exit 1
fi

if [ "$HELM_AVAILABLE" = true ]; then
    # Deploy using Helm
    print_status "Adding Prometheus Helm repository..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    print_status "Installing Prometheus using Helm..."
    if helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace newmonitoring \
        --values "$PROJECT_ROOT/helm/prometheus-values.yaml" \
        --create-namespace; then
        print_success "Prometheus installed via Helm"
    else
        print_warning "Prometheus installation may have issues. Checking status..."
        helm status prometheus -n newmonitoring
    fi
    
    # Wait for Prometheus to be ready
    print_status "Waiting for Prometheus to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n newmonitoring --timeout=300s || true
    
else
    print_warning "Helm not available. You'll need to install Prometheus Operator manually."
    print_status "Please refer to: https://github.com/prometheus-operator/prometheus-operator"
fi

# Deploy ServiceMonitor
print_status "Deploying ServiceMonitor for application metrics..."
if kubectl apply -f "$PROJECT_ROOT/k8s/service-monitor.yaml"; then
    print_success "ServiceMonitor deployed"
else
    print_error "Failed to deploy ServiceMonitor"
    exit 1
fi

# Show monitoring status
print_status "Monitoring deployment status:"
kubectl get pods -n newmonitoring
kubectl get svc -n newmonitoring

# Check if Prometheus is accessible
print_status "Checking Prometheus accessibility..."
if kubectl get pods -n newmonitoring -l app.kubernetes.io/name=prometheus | grep -q "Running"; then
    print_success "Prometheus is running"
    
    print_status "To access Prometheus UI:"
    echo "  kubectl port-forward -n newmonitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
    echo "  Then visit: http://localhost:9090"
    
    print_status "To check if your application metrics are being scraped:"
    echo "  1. Access Prometheus UI"
    echo "  2. Go to Status -> Targets"
    echo "  3. Look for 'newmonitoring/springboot-servicemonitor/0'"
    
else
    print_warning "Prometheus may not be running yet. Check the pods:"
    kubectl get pods -n newmonitoring
fi

print_success "Monitoring deployment completed!"

if [ "$HELM_AVAILABLE" = true ]; then
    print_status "Installed components via Helm:"
    helm list -n newmonitoring
fi

print_status "Monitoring components:"
echo "  - Prometheus: Metrics collection and alerting"
echo "  - Grafana: Metrics visualization (if enabled in values)"
echo "  - ServiceMonitor: Application metrics scraping configuration"
echo "  - Remote Write: Metrics forwarding to Thanos"