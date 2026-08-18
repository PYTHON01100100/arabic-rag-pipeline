# Production Deployment with LLM Providers

Production-ready deployment guides for each LLM provider option.

## Quick Start by Provider

### Option 1: Google Gemini (Recommended for Cloud)

```bash
# 1. Get API key from https://aistudio.google.com/apikey

# 2. Set environment
export GEMINI_API_KEY="sk-..."
export LLM_PROVIDER=gemini

# 3. Deploy
docker compose up -d

# 4. Access at http://localhost:8501
```

**Cost**: $0-15/month (depending on usage)
**Best For**: Cloud deployment, teams, no infrastructure costs

---

### Option 2: Ollama (Free & Private)

```bash
# 1. Start Ollama service
docker compose --profile ollama up -d

# 2. Wait for Ollama to start
sleep 30

# 3. Download model
docker compose exec ollama ollama pull mistral

# 4. Configure and start RAG
cat > .env << 'EOF'
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://ollama:11434
OLLAMA_MODEL=mistral
EOF

docker compose up -d rag-pipeline

# 5. Access at http://localhost:8501
```

**Cost**: One-time hardware (~$100-500 for server)
**Best For**: Privacy, offline operation, cost-sensitive

---

### Option 3: vLLM (Fastest)

```bash
# 1. Prerequisites: NVIDIA GPU with CUDA

# 2. Enable GPU in docker-compose
# Edit docker-compose.yml or use docker-compose.prod.yml

# 3. Start vLLM
docker compose --profile vllm up -d

# 4. Wait for model to load (2-5 minutes)
docker compose logs -f vllm

# 5. Configure and start
cat > .env << 'EOF'
LLM_PROVIDER=vllm
VLLM_BASE_URL=http://vllm:8000/v1
VLLM_MODEL=meta-llama/Llama-2-7b-chat-hf
EOF

docker compose up -d rag-pipeline

# 6. Access at http://localhost:8501
```

**Cost**: $400-1000/month (GPU EC2 instance)
**Best For**: Production workloads, high throughput, performance-critical

---

## Platform-Specific Deployments

### AWS EC2

#### Deployment A: Gemini (Simplest)

```bash
# 1. Launch EC2: t3.medium (2GB RAM, $0.05/hour)

# 2. Install Docker
curl https://get.docker.com | sh
sudo usermod -aG docker ec2-user

# 3. Clone and configure
git clone <repo>
cd arabic-rag-pipeline-main
cp .env.example .env

# 4. Add API key
echo "GEMINI_API_KEY=sk-..." >> .env
echo "LLM_PROVIDER=gemini" >> .env

# 5. Deploy
docker compose up -d

# 6. Get public IP
aws ec2 describe-instances --instance-ids i-xxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress'

# Access: http://<public-ip>:8501
```

**Monthly Cost**: ~$40 (EC2) + API usage

#### Deployment B: Ollama (Cost-Effective)

```bash
# 1. Launch EC2: t3.large (8GB RAM, $0.10/hour)

# 2. Install Docker & Git
sudo yum update -y
sudo yum install docker git -y
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# 3. Clone repo
git clone <repo>
cd arabic-rag-pipeline-main

# 4. Configure
cat > .env << 'EOF'
LLM_PROVIDER=ollama
OLLAMA_MODEL=mistral
EOF

# 5. Deploy with Ollama
docker compose --profile ollama up -d

# 6. Download model (wait 10 minutes)
docker compose exec ollama ollama pull mistral

# 7. Start RAG pipeline
docker compose up -d rag-pipeline

# 8. Monitor
docker compose logs -f
```

**Monthly Cost**: ~$70 (EC2) + minimal API

#### Deployment C: vLLM (High Performance)

```bash
# 1. Launch GPU EC2: g4dn.xlarge (NVIDIA T4, $0.526/hour)
# Ensure Ubuntu 22.04 or Amazon Linux 2

# 2. Install NVIDIA drivers
sudo yum install kernel-devel-$(uname -r) -y
sudo yum install gcc kernel-devel -y
sudo yum groupinstall "Development Tools" -y

# Install NVIDIA CUDA
wget https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-repo-rhel8-11.0.0-1.x86_64.rpm
sudo rpm -i cuda-repo-rhel8-11.0.0-1.x86_64.rpm
sudo yum install cuda -y

# 3. Install nvidia-docker
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo rpm --import -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | \
  sudo tee /etc/yum.repos.d/nvidia-docker.repo
sudo yum clean expire-cache
sudo yum install nvidia-docker2 -y
sudo systemctl restart docker

# 4. Clone repo and configure
git clone <repo>
cd arabic-rag-pipeline-main
cp .env.example .env

# 5. Use production config
cat > .env << 'EOF'
LLM_PROVIDER=vllm
VLLM_MODEL=meta-llama/Llama-2-7b-chat-hf
VLLM_BASE_URL=http://vllm:8000/v1
EOF

# 6. Deploy with GPU support
docker compose -f docker-compose.prod.yml --profile vllm up -d

# 7. Monitor startup (takes 3-5 minutes)
docker compose logs -f vllm

# 8. Verify GPU is working
docker exec vllm nvidia-smi
```

**Monthly Cost**: ~$380 (EC2) + bandwidth

### AWS ECS (Recommended for Enterprise)

#### Gemini (Managed Container)

```bash
# 1. Create ECS Cluster
aws ecs create-cluster --cluster-name rag-pipeline

# 2. Update task definition with Gemini config
# Edit ecs-task-definition.json
# Add GEMINI_API_KEY as secret in AWS Secrets Manager

aws secretsmanager create-secret \
  --name gemini-api-key \
  --secret-string "sk-..."

# 3. Register task definition
aws ecs register-task-definition \
  --cli-input-json file://ecs-task-definition.json

# 4. Create service
aws ecs create-service \
  --cluster rag-pipeline \
  --service-name rag-pipeline \
  --task-definition rag-pipeline:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration awsvpcConfiguration=...

# 5. Scale as needed
aws ecs update-service \
  --cluster rag-pipeline \
  --service rag-pipeline \
  --desired-count 5
```

**Cost**: Pay per task

#### vLLM (ECS with GPU)

```bash
# Similar to Gemini, but requires GPU-capable instances
# Use EC2 launch type with GPU instances (g4dn.xlarge)
# Configure vLLM service in task definition
```

### Kubernetes (Most Scalable)

#### Gemini + K8s

```bash
# 1. Add API key to secret
kubectl create secret generic llm-secrets \
  --from-literal=gemini-key="sk-..."

# 2. Deploy
kubectl apply -f k8s-deployment.yaml

# 3. Expose service
kubectl port-forward svc/rag-pipeline-service 8501:80

# 4. Monitor
kubectl logs -f deployment/rag-pipeline

# 5. Scale
kubectl scale deployment rag-pipeline --replicas=5
```

#### Ollama + K8s (StatefulSet)

```yaml
# ollama-statefulset.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-pvc
spec:
  accessModes: [ "ReadWriteOnce" ]
  resources:
    requests:
      storage: 50Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ollama
spec:
  serviceName: ollama
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
        volumeMounts:
        - name: ollama-data
          mountPath: /root/.ollama
        resources:
          requests:
            memory: "8Gi"
            cpu: "2"
          limits:
            memory: "16Gi"
            cpu: "4"
      volumes:
      - name: ollama-data
        persistentVolumeClaim:
          claimName: ollama-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: ollama
spec:
  clusterIP: None
  ports:
  - port: 11434
    targetPort: 11434
  selector:
    app: ollama
```

#### vLLM + K8s (GPU DaemonSet)

```yaml
# vllm-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: vllm
spec:
  selector:
    matchLabels:
      app: vllm
  template:
    metadata:
      labels:
        app: vllm
    spec:
      nodeSelector:
        gpu: "true"  # Only GPU nodes
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        ports:
        - containerPort: 8000
        env:
        - name: MODEL_NAME
          value: "meta-llama/Llama-2-7b-chat-hf"
        - name: CUDA_VISIBLE_DEVICES
          value: "0"
        resources:
          requests:
            nvidia.com/gpu: 1
            memory: "8Gi"
          limits:
            nvidia.com/gpu: 1
            memory: "16Gi"
```

---

## Configuration Management

### Environment Variables by Provider

#### Gemini
```env
LLM_PROVIDER=gemini
GEMINI_API_KEY=sk-...
GEMINI_MODEL=gemini-2.0-flash
```

#### Ollama
```env
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://ollama:11434
OLLAMA_MODEL=mistral
OLLAMA_TEMPERATURE=0.7
```

#### vLLM
```env
LLM_PROVIDER=vllm
VLLM_BASE_URL=http://vllm:8000/v1
VLLM_MODEL=meta-llama/Llama-2-7b-chat-hf
VLLM_MAX_TOKENS=2048
VLLM_TEMPERATURE=0.7
```

### Using AWS Secrets Manager

```bash
# Store API key
aws secretsmanager create-secret \
  --name rag/gemini-api-key \
  --secret-string "sk-..."

# Reference in docker-compose
environment:
  - GEMINI_API_KEY=${GEMINI_API_KEY}  # Set via CI/CD

# Or in ECS task definition
secrets:
  - name: GEMINI_API_KEY
    valueFrom: "arn:aws:secretsmanager:region:account:secret:rag/gemini-api-key"
```

### Using Kubernetes Secrets

```bash
# Create secret
kubectl create secret generic llm-secrets \
  --from-literal=gemini-key="sk-..."

# Reference in deployment
env:
  - name: GEMINI_API_KEY
    valueFrom:
      secretKeyRef:
        name: llm-secrets
        key: gemini-key
```

---

## Performance Tuning

### Gemini

```env
# No tuning needed - managed service
GEMINI_MODEL=gemini-2.0-flash  # Faster and cheaper
```

### Ollama

```env
# Increase performance (at cost of memory)
OLLAMA_MODEL=mistral  # Faster than llama2
OLLAMA_TEMPERATURE=0.7  # Lower = more deterministic

# Parallel requests
OLLAMA_NUM_PARALLEL=4  # Process 4 requests simultaneously
```

### vLLM

```env
# GPU optimization
VLLM_GPU_MEMORY_UTILIZATION=0.9  # Use 90% of GPU memory
VLLM_BLOCK_SIZE=16  # Optimize block size
VLLM_NUM_GPUS=1  # Use 1 GPU

# Batching
VLLM_MAX_BATCH_SIZE=32  # Maximum batch size
VLLM_ENABLE_CHUNKED_PREFILL=True  # For longer contexts
```

---

## Monitoring & Logging

### CloudWatch (AWS)

```bash
# Send logs to CloudWatch
docker compose logs | awslogs  # Use CloudWatch Logs driver

# Create custom metrics
aws cloudwatch put-metric-data \
  --metric-name RAGLatency \
  --value 250  # milliseconds
```

### Prometheus + Grafana

```bash
# Deploy with monitoring profile
docker compose -f docker-compose.prod.yml \
  --profile monitoring up -d

# Access Prometheus: http://localhost:9090
# Access Grafana: http://localhost:3000
```

### ECS CloudWatch

```bash
# Monitor from AWS Console
# Services → rag-pipeline
# Monitoring tab shows:
# - CPU, Memory usage
# - Running/stopped tasks
# - Service deployment history
```

---

## Troubleshooting

### Provider Connection Issues

```bash
# Check Gemini
curl https://generativelanguage.googleapis.com/v1beta/models \
  -H "x-goog-api-key: $GEMINI_API_KEY"

# Check Ollama
curl http://localhost:11434/api/tags

# Check vLLM
curl http://localhost:8000/v1/models
```

### Model Loading Issues

```bash
# vLLM - Check GPU memory
nvidia-smi

# Ollama - Check downloaded models
docker compose exec ollama ollama ls

# Pull model if missing
docker compose exec ollama ollama pull mistral
```

### Performance Issues

```bash
# Check resource usage
docker stats

# Increase resource limits in docker-compose
deploy:
  resources:
    limits:
      memory: 8G
      cpus: 4

# Restart with new limits
docker compose up -d
```

---

## Cost Optimization

### Gemini
- Use free tier for testing
- Monitor quota: ~60 req/min
- Pay only for production usage

### Ollama
- One-time hardware investment
- No ongoing API costs
- Electricity: ~$10/month

### vLLM
- Use smaller models (7B vs 70B)
- Spot instances on AWS
- Share GPU with multiple containers

---

## Backup & Recovery

### Data Backup

```bash
# Backup ChromaDB
docker volume create chroma_backup
docker run --rm -v chroma_db_data:/data -v chroma_backup:/backup \
  alpine tar czf /backup/chroma.tar.gz -C /data .

# Restore
docker run --rm -v chroma_db_data:/data -v chroma_backup:/backup \
  alpine tar xzf /backup/chroma.tar.gz -C /data
```

### Model Backup (vLLM)

```bash
# Backup model cache
tar -czf vllm_models.tar.gz vllm_cache/

# Restore to new server
tar -xzf vllm_models.tar.gz -C /path/to/vllm_cache
```

---

## Next Steps

1. Choose your provider based on needs
2. Follow platform-specific deployment guide
3. Configure monitoring and logging
4. Set up backup strategy
5. Test failover procedures
6. Document your setup
