#!/bin/bash

# cleanup.sh - Remove all deployed resources
set -e

echo "🧹 Starting cleanup of deployed resources..."

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

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Ask for confirmation
read -p "Are you sure you want to remove all deployed resources? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleanup cancelled."
    exit 0
fi

# Remove application resources
print_status "Removing application deployment..."
kubectl delete -f "$PROJECT_ROOT/k8s/app-deployment.yaml" --ignore-not-found=true

print_status "Removing application ConfigMap..."
kubectl delete -f "$PROJECT_ROOT/k8s/app-configmap.yaml" --ignore-not-found=true

# Remove monitoring resources
print_status "Removing ServiceMonitor..."
kubectl delete -f "$PROJECT_ROOT/k8s/service-monitor.yaml" --ignore-not-found=true

print_status "Removing Thanos secret..."
kubectl delete -f "$PROJECT_ROOT/k8s/secret-thanos.yaml" --ignore-not-found=true

# Remove Prometheus if installed via Helm
if command -v helm &> /dev/null; then
    if helm list -n newmonitoring | grep -q prometheus; then
        print_status "Removing Prometheus Helm release..."
        helm uninstall prometheus -n newmonitoring
        print_success "Prometheus removed"
    else
        print_status "No Prometheus Helm release found"
    fi
else
    print_warning "Helm not available. Manual Prometheus cleanup may be required."
fi

# Remove namespaces (this will remove everything in them)
print_status "Removing namespaces..."
kubectl delete namespace app --ignore-not-found=true
kubectl delete namespace newmonitoring --ignore-not-found=true

# Remove Docker image (optional)
read -p "Do you want to remove the Docker image 'ac3modelcofiguration:latest'? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v docker &> /dev/null; then
        print_status "Removing Docker image..."
        docker rmi ac3modelcofiguration:latest --force || print_warning "Docker image may not exist or cannot be removed"
    else
        print_warning "Docker not available"
    fi
fi

print_success "Cleanup completed!"
print_status "All resources have been removed from the Kubernetes cluster."