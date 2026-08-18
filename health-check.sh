#!/bin/bash
# Health check script for Arabic RAG Pipeline
# Run this to diagnose issues

echo "╔════════════════════════════════════════════════════════╗"
echo "║           Arabic RAG Pipeline - Health Check          ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to check a command
check_command() {
    local cmd=$1
    local name=$2

    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name installed"
        return 0
    else
        echo -e "${RED}✗${NC} $name not found"
        return 1
    fi
}

# Function to check service
check_service() {
    local port=$1
    local name=$2

    if curl -s http://localhost:$port &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name running on port $port"
        return 0
    else
        echo -e "${RED}✗${NC} $name not responding on port $port"
        return 1
    fi
}

# 1. System Requirements
echo -e "${BLUE}1. System Requirements${NC}"
echo ""
check_command docker "Docker"
check_command docker-compose "Docker Compose"
check_command curl "curl"
echo ""

# 2. Docker Status
echo -e "${BLUE}2. Docker Status${NC}"
echo ""

if docker ps > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Docker daemon running"
else
    echo -e "${RED}✗${NC} Docker daemon not running"
    echo "  Start Docker and try again"
fi

# Count running containers
container_count=$(docker compose ps --quiet 2>/dev/null | wc -l)
echo "  Running containers: $container_count"
echo ""

# 3. Configuration
echo -e "${BLUE}3. Configuration Files${NC}"
echo ""

if [ -f .env ]; then
    echo -e "${GREEN}✓${NC} .env file found"

    # Check for required variables
    if grep -q "LLM_PROVIDER=" .env; then
        provider=$(grep "^LLM_PROVIDER=" .env | cut -d= -f2)
        echo "  LLM Provider: $provider"
    else
        echo -e "${YELLOW}⚠${NC}  LLM_PROVIDER not set"
    fi

    if grep -q "GEMINI_API_KEY=" .env; then
        key_length=$(grep "^GEMINI_API_KEY=" .env | cut -d= -f2 | wc -c)
        if [ $key_length -gt 10 ]; then
            echo -e "${GREEN}✓${NC}  GEMINI_API_KEY configured"
        else
            echo -e "${YELLOW}⚠${NC}  GEMINI_API_KEY empty"
        fi
    fi
else
    echo -e "${RED}✗${NC} .env file not found"
    echo "  Run: cp .env.example .env"
fi

if [ -f docker-compose.yml ]; then
    echo -e "${GREEN}✓${NC} docker-compose.yml found"
else
    echo -e "${RED}✗${NC} docker-compose.yml not found"
fi
echo ""

# 4. Services Status
echo -e "${BLUE}4. Services Status${NC}"
echo ""

# Main app
if check_service 8501 "Streamlit App"; then
    # Get more details
    curl -s http://localhost:8501/_stcore/health | python -m json.tool 2>/dev/null || true
else
    echo "  Run: docker compose up -d"
fi

# Ollama
if check_service 11434 "Ollama"; then
    models=$(curl -s http://localhost:11434/api/tags | python -m json.tool 2>/dev/null | grep '"name"' | wc -l || echo "?")
    echo "  Models available: $models"
else
    echo "  (Optional - not required unless LLM_PROVIDER=ollama)"
fi

# vLLM
if check_service 8000 "vLLM"; then
    echo "  (GPU LLM server running)"
else
    echo "  (Optional - not required unless LLM_PROVIDER=vllm)"
fi
echo ""

# 5. Resource Usage
echo -e "${BLUE}5. Resource Usage${NC}"
echo ""

if docker ps --format "table {{.Names}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | grep -q rag-pipeline; then
    echo "Docker resource usage:"
    docker stats --no-stream 2>/dev/null | grep -E "(rag-pipeline|CONTAINER)" || true
else
    echo "No containers running"
fi
echo ""

# 6. Storage
echo -e "${BLUE}6. Storage${NC}"
echo ""

if [ -d streamlit_chroma_db ]; then
    size=$(du -sh streamlit_chroma_db 2>/dev/null | cut -f1)
    echo -e "${GREEN}✓${NC} ChromaDB directory: $size"
else
    echo -e "${YELLOW}⚠${NC} ChromaDB directory not found"
fi

if [ -d data ]; then
    size=$(du -sh data 2>/dev/null | cut -f1)
    echo "  Data directory: $size"
fi

# Docker volumes
volume_count=$(docker volume ls 2>/dev/null | grep -i chroma | wc -l)
if [ $volume_count -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Docker volumes: $volume_count found"
else
    echo -e "${YELLOW}⚠${NC} Docker volumes: none found"
fi
echo ""

# 7. Logs Check
echo -e "${BLUE}7. Recent Logs (Last 10 lines)${NC}"
echo ""

if docker compose logs --tail 10 rag-pipeline 2>/dev/null | head -5; then
    echo "  (Run 'docker compose logs -f' for full logs)"
else
    echo "  No logs available"
fi
echo ""

# 8. Summary
echo -e "${BLUE}8. Summary${NC}"
echo ""

# Check if everything is OK
all_ok=true

if ! docker ps > /dev/null 2>&1; then
    all_ok=false
    echo -e "${RED}❌ Docker is not running${NC}"
fi

if ! curl -s http://localhost:8501 > /dev/null 2>&1; then
    all_ok=false
    echo -e "${YELLOW}⚠ Application not responding${NC}"
fi

if [ "$all_ok" = true ]; then
    echo -e "${GREEN}✅ Everything looks good!${NC}"
    echo ""
    echo "Access the application at: http://localhost:8501"
else
    echo -e "${YELLOW}⚠ Some issues detected${NC}"
    echo ""
    echo "Try these fixes:"
    echo "1. Start Docker daemon"
    echo "2. Run: docker compose up -d"
    echo "3. Wait 30 seconds for startup"
    echo "4. Run this script again"
fi

echo ""
echo "For more help, see:"
echo "  LLM_QUICK_START.md - Setup guides"
echo "  QUICK_REFERENCE.md - Common commands"
echo ""
