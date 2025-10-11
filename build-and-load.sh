#!/bin/bash

# build-and-load.sh - Build image and load it into Kubernetes cluster
set -e

echo "🔨 Building and loading Docker image into Kubernetes..."

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

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

print_status "Building Docker image..."
cd "$PROJECT_ROOT/exampleconfig"

# Build the image
if docker build -t ac3modelcofiguration:latest .; then
    print_success "Docker image built successfully"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Detect the type of Kubernetes cluster and load image accordingly
print_status "Detecting Kubernetes cluster type..."

# Check for kind
if command -v kind &> /dev/null && kind get clusters 2>/dev/null | grep -q .; then
    CLUSTER_NAME=$(kind get clusters | head -n1)
    print_status "Detected kind cluster: $CLUSTER_NAME"
    print_status "Loading image into kind cluster..."
    if kind load docker-image ac3modelcofiguration:latest --name "$CLUSTER_NAME"; then
        print_success "Image loaded into kind cluster"
    else
        print_error "Failed to load image into kind cluster"
        exit 1
    fi

# Check for minikube
elif command -v minikube &> /dev/null && minikube status &> /dev/null; then
    print_status "Detected minikube cluster"
    print_status "Loading image into minikube..."
    if minikube image load ac3modelcofiguration:latest; then
        print_success "Image loaded into minikube"
    else
        print_error "Failed to load image into minikube"
        exit 1
    fi

# Check for k3d
elif command -v k3d &> /dev/null && k3d cluster list 2>/dev/null | grep -q .; then
    CLUSTER_NAME=$(k3d cluster list -o json | jq -r '.[0].name' 2>/dev/null || echo "k3s-default")
    print_status "Detected k3d cluster: $CLUSTER_NAME"
    print_status "Loading image into k3d cluster..."
    if k3d image import ac3modelcofiguration:latest -c "$CLUSTER_NAME"; then
        print_success "Image loaded into k3d cluster"
    else
        print_error "Failed to load image into k3d cluster"
        exit 1
    fi

# Check for microk8s
elif command -v microk8s &> /dev/null; then
    print_status "Detected microk8s cluster"
    print_status "Saving and importing image into microk8s..."
    if docker save ac3modelcofiguration:latest | microk8s ctr image import -; then
        print_success "Image imported into microk8s"
    else
        print_error "Failed to import image into microk8s"
        exit 1
    fi

# For other clusters (like k3s on VM), save and import manually
else
    print_warning "Could not detect cluster type automatically"
    print_status "Trying generic approaches..."
    
    # Try to save the image and provide instructions
    print_status "Saving image to tar file..."
    if docker save ac3modelcofiguration:latest -o /tmp/ac3modelcofiguration.tar; then
        print_success "Image saved to /tmp/ac3modelcofiguration.tar"
        print_status "For k3s clusters, try:"
        echo "  sudo k3s ctr images import /tmp/ac3modelcofiguration.tar"
        print_status "For containerd clusters, try:"
        echo "  sudo ctr -n k8s.io images import /tmp/ac3modelcofiguration.tar"
    fi
    
    print_warning "Manual image loading may be required"
    print_status "Alternatively, the deployment has been updated to use imagePullPolicy: Never"
fi

print_success "Image build and load process completed!"
print_status "The deployment YAML has been updated to use imagePullPolicy: Never"
print_status "You can now apply the deployment:"
echo "  kubectl apply -f k8s/app-deployment.yaml --validate=false --force"