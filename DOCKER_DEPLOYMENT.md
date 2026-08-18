# Docker Deployment Guide - Arabic RAG Pipeline

Complete guide for deploying the Arabic RAG Pipeline across multiple environments using Docker.

## Table of Contents
1. [Quick Start](#quick-start)
2. [Local Development](#local-development)
3. [Docker Build](#docker-build)
4. [EC2 Deployment](#ec2-deployment)
5. [ECS Deployment](#ecs-deployment)
6. [Kubernetes Deployment](#kubernetes-deployment)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Prerequisites
- Docker & Docker Compose installed
- GEMINI_API_KEY from [Google AI Studio](https://aistudio.google.com/apikey)

### 1. Set up environment
```bash
cp .env.example .env
# Edit .env and add your GEMINI_API_KEY
nano .env
```

### 2. Run with Docker Compose (Recommended for development)
```bash
docker-compose up -d
```

The app will be available at `http://localhost:8501`

### 3. View logs
```bash
docker-compose logs -f rag-pipeline
```

### 4. Stop containers
```bash
docker-compose down
```

---

## Local Development

### Persistent Storage
- ChromaDB data is stored in a Docker volume `chroma_db_data`
- Data persists even if containers are stopped/recreated
- To clear data: `docker volume rm chroma_db_data`

### Hot Reload
- Source code is mounted as a volume in docker-compose.yml
- Changes to `rag_pipeline.py` auto-reload in the container
- Streamlit configuration can be modified without rebuild

### Environment Variables
Add to `.env` file:
```env
GEMINI_API_KEY=sk-xxx...
STREAMLIT_SERVER_PORT=8501
STREAMLIT_SERVER_HEADLESS=true
```

---

## Docker Build

### Build the image locally
```bash
docker build -t rag-pipeline:latest .
```

### Build with specific tag for registry
```bash
docker build -t your-registry/rag-pipeline:1.0.0 .
```

### Multi-platform build (for ARM64/x86_64)
```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t your-registry/rag-pipeline:latest .
```

### Push to registry
```bash
# Docker Hub
docker push your-username/rag-pipeline:latest

# AWS ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com
docker tag rag-pipeline:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/rag-pipeline:latest
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/rag-pipeline:latest
```

---

## EC2 Deployment

### 1. Launch EC2 Instance
- AMI: Ubuntu 22.04 LTS or Amazon Linux 2
- Instance Type: t3.medium or larger (2GB RAM minimum)
- Security Groups: Allow ports 80, 443, 8501
- Storage: 30GB EBS volume

### 2. Install Docker on EC2
```bash
sudo apt update && sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER
newgrp docker
```

### 3. Clone and deploy
```bash
git clone <repo-url> rag-pipeline
cd rag-pipeline

# Create .env file
cat > .env << 'EOF'
GEMINI_API_KEY=your-key-here
STREAMLIT_SERVER_PORT=8501
EOF

# Run with Docker Compose
docker-compose up -d
```

### 4. Access via Elastic IP
- Assign Elastic IP to EC2 instance
- Access at `http://<elastic-ip>:8501`

### 5. SSL/TLS with Let's Encrypt (optional)
```bash
# Install certbot
sudo apt install certbot

# Generate certificate
sudo certbot certonly --standalone -d your-domain.com

# Use certificate in docker-compose.yml with nginx proxy
```

### 6. Auto-restart on reboot
```bash
# Add to /etc/crontab
@reboot cd /home/ubuntu/rag-pipeline && docker-compose up -d
```

---

## ECS Deployment

### 1. Create ECR Repository
```bash
aws ecr create-repository --repository-name rag-pipeline --region us-east-1
```

### 2. Build and Push Image
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

docker build -t rag-pipeline:latest .

docker tag rag-pipeline:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/rag-pipeline:latest

docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/rag-pipeline:latest
```

### 3. Create ECS Task Definition
```bash
# Use ecs-task-definition.json (provided)
aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json
```

### 4. Create ECS Service
```bash
aws ecs create-service \
  --cluster rag-pipeline-cluster \
  --service-name rag-pipeline-service \
  --task-definition rag-pipeline:1 \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}"
```

### 5. Set up Load Balancer
- Create ALB (Application Load Balancer)
- Add target group pointing to ECS service on port 8501
- Configure security groups to allow ingress on 80/443

---

## Kubernetes Deployment

### Prerequisites
- kubectl CLI installed
- Access to K8s cluster (EKS, GKE, local Kind, etc.)

### 1. Configure API Key Secret
Edit `k8s-deployment.yaml` and replace:
```yaml
stringData:
  GEMINI_API_KEY: "your-gemini-api-key-here"
```

### 2. Deploy to cluster
```bash
# Apply all resources (namespace, configmap, secret, PVC, deployment, service)
kubectl apply -f k8s-deployment.yaml

# Check deployment status
kubectl rollout status deployment/rag-pipeline -n rag-pipeline

# View pods
kubectl get pods -n rag-pipeline -w
```

### 3. Port Forward (for local testing)
```bash
kubectl port-forward -n rag-pipeline svc/rag-pipeline-service 8501:80
# Access at http://localhost:8501
```

### 4. Get External IP
```bash
kubectl get svc -n rag-pipeline rag-pipeline-service
```

### 5. Configure Ingress (optional)
Edit `k8s-ingress.yaml`:
- Replace `rag-pipeline.example.com` with your domain
- Install nginx-ingress or your preferred ingress controller
- Apply: `kubectl apply -f k8s-ingress.yaml`

### 6. Check logs
```bash
# Real-time logs
kubectl logs -f deployment/rag-pipeline -n rag-pipeline

# Logs from specific pod
kubectl logs -f pod/rag-pipeline-xxx -n rag-pipeline
```

### 7. Scale deployment
```bash
kubectl scale deployment rag-pipeline --replicas=3 -n rag-pipeline
```

### 8. Update image
```bash
kubectl set image deployment/rag-pipeline rag-pipeline=<account-id>.dkr.ecr.us-east-1.amazonaws.com/rag-pipeline:1.1.0 -n rag-pipeline
```

### Troubleshooting K8s

Check pod events:
```bash
kubectl describe pod <pod-name> -n rag-pipeline
```

Get all resources:
```bash
kubectl get all -n rag-pipeline
```

Delete and redeploy:
```bash
kubectl delete ns rag-pipeline
kubectl apply -f k8s-deployment.yaml
```

---

## Troubleshooting

### Container won't start
```bash
# Check logs
docker logs rag-pipeline

# Run interactively for debugging
docker run -it --rm -e GEMINI_API_KEY=test rag-pipeline bash
```

### Out of memory
- Increase container memory limits
- Docker Desktop: Preferences → Resources
- ECS Task: Increase task memory
- K8s: Update deployment resource requests/limits

### ChromaDB persistence issues
```bash
# Check volume
docker volume ls | grep chroma

# Inspect volume
docker volume inspect chroma_db_data

# Clean up
docker volume rm chroma_db_data
```

### Streamlit connection timeout
- Ensure port 8501 is exposed
- Check security groups/firewall rules
- Verify STREAMLIT_SERVER_ADDRESS=0.0.0.0

### API Key errors
- Verify GEMINI_API_KEY is set in .env
- Check key is valid at [Google AI Studio](https://aistudio.google.com/apikey)
- Ensure secret is correctly mounted in K8s

### OCR not working
- Image includes Tesseract + Arabic language pack
- Verify PDF is being uploaded correctly
- Check logs for OCR initialization errors

---

## Production Best Practices

### Security
- ✅ Run as non-root user (UID 1000)
- ✅ Use read-only filesystem where possible
- ✅ Drop unnecessary Linux capabilities
- ✅ Use Secrets for API keys (K8s)
- ✅ Enable network policies in K8s
- ✅ Use HTTPS with TLS certificates

### Performance
- ✅ Multi-stage Docker build (smaller image: ~1.2GB)
- ✅ Health checks configured
- ✅ Resource requests/limits set
- ✅ Horizontal Pod Autoscaling in K8s
- ✅ Persistent volume for ChromaDB

### Monitoring
- ✅ Structured logging (PYTHONUNBUFFERED)
- ✅ Health check endpoints
- ✅ Pod metrics available for Prometheus
- ✅ Configure alerts in production

### Deployment
- ✅ Use specific image tags (not :latest in production)
- ✅ Rolling updates configured (K8s)
- ✅ Graceful shutdown (preStop hook)
- ✅ Pod disruption budgets
- ✅ Resource quotas

---

## Support
For issues or questions:
1. Check troubleshooting section above
2. Review Docker/K8s logs
3. Consult [Streamlit docs](https://docs.streamlit.io/)
4. Check [Chromadb docs](https://docs.trychroma.com/)
