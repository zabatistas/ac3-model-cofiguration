#!/bin/bash

# deploy.sh - Automated deployment script for the Spring Boot application
set -e

echo "🚀 Starting deployment of Spring Boot application to Kubernetes..."

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

# Step 2: Create namespaces
print_status "Creating Kubernetes namespaces..."
if kubectl apply -f "$PROJECT_ROOT/k8s/namespace.yaml"; then
    print_success "Namespaces created/updated"
else
    print_error "Failed to create namespaces"
    exit 1
fi

# Step 3: Deploy ConfigMap
print_status "Deploying ConfigMap..."
if kubectl apply -f "$PROJECT_ROOT/k8s/app-configmap.yaml"; then
    print_success "ConfigMap deployed"
else
    print_error "Failed to deploy ConfigMap"
    exit 1
fi

# Step 4: Deploy application
print_status "Deploying Spring Boot application..."
if kubectl apply -f "$PROJECT_ROOT/k8s/app-deployment.yaml"; then
    print_success "Application deployed"
else
    print_error "Failed to deploy application"
    exit 1
fi

# Step 5: Wait for deployment to be ready
print_status "Waiting for deployment to be ready..."
if kubectl wait --for=condition=available --timeout=300s deployment/springboot-app -n app; then
    print_success "Deployment is ready"
else
    print_warning "Deployment may not be fully ready yet"
fi

# Step 6: Show deployment status
print_status "Deployment status:"
kubectl get pods -n app
kubectl get svc -n app
kubectl get deployment -n app

# Step 7: Test the application
print_status "Testing application health..."
if kubectl get pods -n app -l app=springboot | grep -q "Running"; then
    print_success "Application pods are running"
    
    print_status "Setting up port forwarding for testing..."
    kubectl port-forward -n app svc/springboot-svc 8080:8080 &
    PORT_FORWARD_PID=$!
    
    # Wait a moment for port forwarding to be established
    sleep 3
    
    # Test health endpoint
    if curl -f http://localhost:8080/actuator/health > /dev/null 2>&1; then
        print_success "Health check passed"
    else
        print_warning "Health check failed - application might still be starting"
    fi
    
    # Kill port forwarding
    kill $PORT_FORWARD_PID 2>/dev/null || true
else
    print_warning "Application pods are not yet running"
fi

print_success "Deployment completed!"
print_status "To access your application:"
echo "  kubectl port-forward -n app svc/springboot-svc 8080:8080"
echo "  Then visit: http://localhost:8080/actuator/health"

print_status "To view logs:"
echo "  kubectl logs -n app deployment/springboot-app -f"

print_status "To deploy monitoring, run:"
echo "  ./deploy-monitoring.sh"