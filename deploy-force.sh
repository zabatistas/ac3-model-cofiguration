#!/bin/bash

# deploy-force.sh - Force deployment script with validation disabled
set -e

echo "🚀 Force deploying Spring Boot application to Kubernetes..."

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

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

print_status "Project root: $PROJECT_ROOT"

# Step 1: Build Docker image
print_status "Building Docker image..."
cd "$PROJECT_ROOT/exampleconfig"

if docker build -t ac3modelcofiguration:latest .; then
    print_success "Docker image built successfully"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Step 2: Force create namespaces
print_status "Force creating Kubernetes namespaces..."
if kubectl apply -f "$PROJECT_ROOT/k8s/namespace.yaml" --validate=false --force; then
    print_success "Namespaces created/updated"
else
    print_error "Failed to create namespaces"
    exit 1
fi

# Step 3: Force deploy ConfigMap
print_status "Force deploying ConfigMap..."
kubectl delete configmap spring-config -n app --ignore-not-found=true
if kubectl apply -f "$PROJECT_ROOT/k8s/app-configmap.yaml" --validate=false; then
    print_success "ConfigMap deployed"
else
    print_error "Failed to deploy ConfigMap"
    exit 1
fi

# Step 4: Force deploy application
print_status "Force deploying Spring Boot application..."
kubectl delete deployment springboot-app -n app --ignore-not-found=true
kubectl delete service springboot-svc -n app --ignore-not-found=true
kubectl delete hpa springboot-hpa -n app --ignore-not-found=true

if kubectl apply -f "$PROJECT_ROOT/k8s/app-deployment.yaml" --validate=false; then
    print_success "Application deployed"
else
    print_error "Failed to deploy application"
    exit 1
fi

# Step 5: Wait for deployment to be ready
print_status "Waiting for deployment to be ready..."
for i in {1..30}; do
    if kubectl get pods -n app -l app=springboot | grep -q "Running"; then
        print_success "Deployment is ready"
        break
    else
        print_status "Waiting for pods to start... ($i/30)"
        sleep 10
    fi
done

# Step 6: Force restart if needed
print_status "Ensuring fresh pod restart..."
kubectl rollout restart deployment/springboot-app -n app || true
kubectl rollout status deployment/springboot-app -n app --timeout=300s || true

# Step 7: Show deployment status
print_status "Deployment status:"
kubectl get pods -n app --show-labels
kubectl get svc -n app
kubectl get deployment -n app

# Step 8: Show logs for troubleshooting
print_status "Recent application logs:"
kubectl logs -n app deployment/springboot-app --tail=20 || print_warning "Could not fetch logs yet"

print_success "Force deployment completed!"
print_status "To access your application:"
echo "  kubectl port-forward -n app svc/springboot-svc 8080:8080"
echo "  Then visit: http://localhost:8080/actuator/health"

print_status "To view real-time logs:"
echo "  kubectl logs -n app deployment/springboot-app -f"

print_status "To manually restart pods:"
echo "  kubectl rollout restart deployment/springboot-app -n app"