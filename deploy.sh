#!/bin/bash
# Deployment script for Arabic RAG Pipeline across multiple environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

show_menu() {
    echo ""
    echo "=================================="
    echo "Arabic RAG Pipeline - Deployment"
    echo "=================================="
    echo "1. Local Development (Docker Compose)"
    echo "2. Build Docker Image"
    echo "3. EC2 Quick Deploy"
    echo "4. Kubernetes Deploy"
    echo "5. ECS Deploy"
    echo "6. Clean Up"
    echo "0. Exit"
    echo "=================================="
}

check_requirements() {
    local missing_tools=0

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        missing_tools=$((missing_tools + 1))
    fi

    case "$1" in
        "compose")
            if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
                print_error "Docker Compose is not installed"
                missing_tools=$((missing_tools + 1))
            fi
            ;;
        "k8s")
            if ! command -v kubectl &> /dev/null; then
                print_error "kubectl is not installed"
                missing_tools=$((missing_tools + 1))
            fi
            ;;
        "aws")
            if ! command -v aws &> /dev/null; then
                print_error "AWS CLI is not installed"
                missing_tools=$((missing_tools + 1))
            fi
            ;;
    esac

    if [ $missing_tools -gt 0 ]; then
        print_error "$missing_tools required tools are missing"
        return 1
    fi

    return 0
}

local_dev() {
    print_info "Starting local development environment..."

    if [ ! -f .env ]; then
        print_warning ".env file not found"
        echo "Creating .env from .env.example..."
        if [ -f .env.example ]; then
            cp .env.example .env
            print_success ".env created, please edit and add your GEMINI_API_KEY"
        else
            print_error ".env.example not found"
            return 1
        fi
    fi

    if check_requirements "compose"; then
        print_info "Pulling and starting containers..."
        docker compose up -d

        # Wait for service to be ready
        echo "Waiting for service to be ready..."
        for i in {1..30}; do
            if curl -s http://localhost:8501/_stcore/health > /dev/null 2>&1; then
                print_success "Service is ready!"
                echo ""
                echo "Access the application at: http://localhost:8501"
                echo "View logs with: docker compose logs -f"
                echo "Stop containers with: docker compose down"
                return 0
            fi
            echo -n "."
            sleep 1
        done

        print_warning "Service did not start within 30 seconds"
        echo "Check logs with: docker compose logs"
        return 1
    else
        return 1
    fi
}

build_image() {
    print_info "Building Docker image..."

    read -p "Enter image name (default: rag-pipeline): " image_name
    image_name=${image_name:-rag-pipeline}

    read -p "Enter image tag (default: latest): " image_tag
    image_tag=${image_tag:-latest}

    print_info "Building $image_name:$image_tag..."

    if docker build -t "$image_name:$image_tag" .; then
        print_success "Image built successfully: $image_name:$image_tag"

        echo ""
        read -p "Push to registry? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter registry URL (e.g., docker.io/username or ECR URI): " registry

            docker tag "$image_name:$image_tag" "$registry/$image_name:$image_tag"

            print_info "Pushing to $registry..."
            if docker push "$registry/$image_name:$image_tag"; then
                print_success "Image pushed successfully"
            else
                print_error "Failed to push image"
                return 1
            fi
        fi
    else
        print_error "Failed to build image"
        return 1
    fi
}

ec2_deploy() {
    print_info "EC2 Deployment Helper"
    echo ""
    echo "Prerequisites:"
    echo "  1. EC2 instance with Ubuntu 22.04 or Amazon Linux 2"
    echo "  2. Security group allows ports 80, 443, 8501"
    echo "  3. SSH access to the instance"
    echo ""

    read -p "Enter EC2 instance IP/DNS: " ec2_host
    read -p "Enter SSH key path (default: ~/.ssh/id_rsa): " ssh_key
    ssh_key=${ssh_key:-~/.ssh/id_rsa}

    if [ ! -f "$ssh_key" ]; then
        print_error "SSH key not found at $ssh_key"
        return 1
    fi

    print_info "Deploying to $ec2_host..."

    # Copy files
    print_info "Copying deployment files..."
    scp -i "$ssh_key" docker-compose.yml .env.example Dockerfile requirements.txt rag_pipeline.py "ec2-user@$ec2_host:~/rag-pipeline/" 2>/dev/null || \
    scp -i "$ssh_key" docker-compose.yml .env.example Dockerfile requirements.txt rag_pipeline.py "ubuntu@$ec2_host:~/rag-pipeline/" 2>/dev/null || \
    print_error "Failed to copy files via SCP"

    # Install and start
    print_info "Installing Docker and starting containers..."
    ssh -i "$ssh_key" "ec2-user@$ec2_host" << 'EOF' 2>/dev/null || \
    ssh -i "$ssh_key" "ubuntu@$ec2_host" << 'EOF'
        set -e
        sudo apt-get update -qq
        sudo apt-get install -y docker.io docker-compose 2>/dev/null || \
        sudo yum install -y docker docker-compose 2>/dev/null

        cd ~/rag-pipeline
        sudo cp .env.example .env

        echo "Edit .env and add your GEMINI_API_KEY, then run:"
        echo "  docker-compose up -d"
EOF

    print_success "Files deployed to $ec2_host"
    echo ""
    echo "Next steps:"
    echo "  1. SSH into instance: ssh -i $ssh_key ec2-user@$ec2_host"
    echo "  2. Edit ~/rag-pipeline/.env"
    echo "  3. Run: docker-compose up -d"
}

k8s_deploy() {
    if ! check_requirements "k8s"; then
        return 1
    fi

    print_info "Kubernetes Deployment"
    echo ""

    read -p "Enter namespace (default: rag-pipeline): " namespace
    namespace=${namespace:-rag-pipeline}

    read -p "Enter image URI: " image_uri

    read -s -p "Enter GEMINI_API_KEY: " api_key
    echo ""

    print_info "Deploying to namespace: $namespace"
    print_info "Using image: $image_uri"

    # Update manifests
    sed "s|image: rag-pipeline:latest|image: $image_uri|g; s|your-gemini-api-key-here|$api_key|g" k8s-deployment.yaml > /tmp/k8s-deployment-temp.yaml

    kubectl apply -f /tmp/k8s-deployment-temp.yaml

    print_success "Kubernetes manifests applied"
    echo ""
    echo "Check deployment status:"
    echo "  kubectl rollout status deployment/rag-pipeline -n $namespace"
    echo ""
    echo "Get service IP:"
    echo "  kubectl get svc -n $namespace"
    echo ""
    echo "View logs:"
    echo "  kubectl logs -f deployment/rag-pipeline -n $namespace"
}

cleanup() {
    print_warning "This will remove Docker containers, volumes, and images"
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Stopping Docker Compose..."
        docker compose down -v || true

        read -p "Remove Docker images? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker rmi rag-pipeline:latest 2>/dev/null || true
            print_success "Images removed"
        fi

        print_success "Cleanup complete"
    fi
}

# Main menu loop
while true; do
    show_menu
    read -p "Select option: " choice

    case $choice in
        1) local_dev ;;
        2) build_image ;;
        3) ec2_deploy ;;
        4) k8s_deploy ;;
        5) print_info "ECS deployment: Use ecs-task-definition.json manually or AWS Console" ;;
        6) cleanup ;;
        0) print_info "Exiting"; exit 0 ;;
        *) print_error "Invalid option" ;;
    esac

    echo ""
done
