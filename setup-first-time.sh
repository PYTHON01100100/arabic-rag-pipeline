#!/bin/bash
# First-time setup script for Arabic RAG Pipeline
# Run this on a fresh machine to get everything ready

set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║  Arabic RAG Pipeline - First Time Setup               ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}1. Checking prerequisites...${NC}"
echo ""

if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚠ Docker not found!${NC}"
    echo "Install from: https://docs.docker.com/get-docker/"
    exit 1
fi
echo -e "${GREEN}✓ Docker installed${NC}"

if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}⚠ Docker Compose not found!${NC}"
    echo "Usually comes with Docker Desktop"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose installed${NC}"

# Check git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}⚠ Git not found (optional)${NC}"
else
    echo -e "${GREEN}✓ Git installed${NC}"
fi

echo ""

# LLM Provider Selection
echo -e "${BLUE}2. Selecting LLM Provider...${NC}"
echo ""
echo "Choose your LLM provider:"
echo "1) Google Gemini (easiest, API-based)"
echo "2) Ollama (free, local, private)"
echo "3) vLLM (fastest, requires GPU)"
echo ""
read -p "Select provider (1-3): " provider_choice

case $provider_choice in
    1)
        provider="gemini"
        provider_name="Google Gemini"
        setup_info="You'll need a Gemini API key from https://aistudio.google.com/apikey"
        ;;
    2)
        provider="ollama"
        provider_name="Ollama"
        setup_info="Ollama will be installed in a Docker container. No GPU needed."
        ;;
    3)
        provider="vllm"
        provider_name="vLLM"
        setup_info="Requires NVIDIA GPU with CUDA support"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Selected: $provider_name${NC}"
echo "$setup_info"
echo ""

# Create .env file
echo -e "${BLUE}3. Creating .env configuration...${NC}"
echo ""

if [ -f .env ]; then
    echo -e "${YELLOW}⚠ .env file already exists${NC}"
    read -p "Overwrite? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing .env file"
    else
        rm .env
    fi
else
    cp .env.example .env
    echo -e "${GREEN}✓ Created .env from template${NC}"
fi

# Configure for selected provider
echo ""
echo -e "${BLUE}4. Configuring for $provider_name...${NC}"
echo ""

case $provider in
    gemini)
        echo "Enter your Gemini API key (from https://aistudio.google.com/apikey):"
        read -s api_key
        # Update .env
        sed -i.bak "s/LLM_PROVIDER=auto/LLM_PROVIDER=gemini/" .env
        sed -i.bak "s|GEMINI_API_KEY=your-gemini-api-key-here|GEMINI_API_KEY=$api_key|" .env
        echo -e "${GREEN}✓ Gemini API key configured${NC}"
        ;;

    ollama)
        # Update .env
        sed -i.bak "s/LLM_PROVIDER=auto/LLM_PROVIDER=ollama/" .env
        echo -e "${GREEN}✓ Ollama provider configured${NC}"
        echo "Note: You'll need to download a model after startup"
        ;;

    vllm)
        # Update .env
        sed -i.bak "s/LLM_PROVIDER=auto/LLM_PROVIDER=vllm/" .env
        echo -e "${GREEN}✓ vLLM provider configured${NC}"
        echo "Note: Requires NVIDIA GPU with CUDA"
        ;;
esac

echo ""

# Create project directories
echo -e "${BLUE}5. Creating project directories...${NC}"
mkdir -p streamlit_chroma_db
mkdir -p data
echo -e "${GREEN}✓ Directories created${NC}"

echo ""

# Check Docker daemon
echo -e "${BLUE}6. Checking Docker daemon...${NC}"
if ! docker ps > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Docker daemon not running${NC}"
    echo "Start Docker Desktop or run: sudo systemctl start docker"
    echo ""
    echo "After starting Docker, run this script again"
    exit 1
fi
echo -e "${GREEN}✓ Docker daemon running${NC}"

echo ""

# Start services
echo -e "${BLUE}7. Starting services...${NC}"
echo ""

if [ "$provider" = "ollama" ]; then
    echo "Starting with Ollama..."
    docker compose --profile ollama up -d
    echo ""
    echo -e "${YELLOW}Waiting 30 seconds for Ollama to start...${NC}"
    sleep 30

    echo ""
    echo -e "${BLUE}8. Downloading Ollama model...${NC}"
    read -p "Download model now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose exec ollama ollama pull mistral
        echo -e "${GREEN}✓ Model downloaded${NC}"
    else
        echo "You can download later with: docker compose exec ollama ollama pull mistral"
    fi
elif [ "$provider" = "vllm" ]; then
    echo "Starting with vLLM (this may take 3-5 minutes)..."
    docker compose --profile vllm up -d
    echo ""
    echo -e "${YELLOW}Waiting for vLLM to load model...${NC}"
    docker compose logs -f vllm &
else
    echo "Starting with Gemini..."
    docker compose up -d
fi

echo ""
echo -e "${GREEN}✓ Services starting${NC}"

# Wait for app to be ready
echo ""
echo -e "${BLUE}9. Waiting for application to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:8501/_stcore/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Application ready!${NC}"
        break
    fi
    echo -n "."
    sleep 1
done

echo ""
echo ""

# Final summary
echo "╔════════════════════════════════════════════════════════╗"
echo "║              Setup Complete! 🎉                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}✓ Configured for: $provider_name${NC}"
echo -e "${GREEN}✓ Project directory: $(pwd)${NC}"
echo -e "${GREEN}✓ Application: http://localhost:8501${NC}"
echo ""
echo "Next steps:"
echo "1. Open: http://localhost:8501"
echo "2. Upload a PDF using the sidebar"
echo "3. Ask questions about your documents"
echo ""
echo "Useful commands:"
echo "  docker compose logs -f           # View logs"
echo "  docker compose ps                # Show running services"
echo "  docker compose down              # Stop services"
echo "  docker stats                     # Monitor resources"
echo ""
echo "Need help? Read:"
echo "  START_HERE.md - Overview"
echo "  LLM_QUICK_START.md - Quick guides"
echo "  QUICK_REFERENCE.md - Common commands"
echo ""
