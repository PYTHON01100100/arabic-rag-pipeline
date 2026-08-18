# Multi-stage Dockerfile for Arabic RAG Pipeline
# Optimized for development and production across EC2, ECS, and Kubernetes

# ============================================================================
# Stage 1: Builder - Install system dependencies and compile wheels
# ============================================================================
FROM python:3.12-slim as builder

WORKDIR /tmp/build

# Install build dependencies and OCR packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpoppler-cpp-dev \
    poppler-utils \
    tesseract-ocr \
    tesseract-ocr-ara \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and build wheels
COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /tmp/build/wheels -r requirements.txt

# ============================================================================
# Stage 2: Runtime - Minimal production image
# ============================================================================
FROM python:3.12-slim

# Set metadata
LABEL maintainer="Arabic RAG Pipeline"
LABEL description="Streamlit-based Arabic RAG pipeline with ChromaDB and Google Gemini"
LABEL version="1.0"

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    STREAMLIT_SERVER_PORT=8501 \
    STREAMLIT_SERVER_ADDRESS=0.0.0.0 \
    STREAMLIT_SERVER_HEADLESS=true \
    STREAMLIT_CLIENT_LOGGING_LEVEL=info

# Install runtime dependencies only (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpoppler-cpp0 \
    poppler-utils \
    tesseract-ocr \
    tesseract-ocr-ara \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -u 1000 appuser

WORKDIR /app

# Copy wheels from builder
COPY --from=builder /tmp/build/wheels /tmp/wheels
COPY --from=builder /tmp/build/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache /tmp/wheels/* \
    && rm -rf /tmp/wheels

# Copy application code
COPY --chown=appuser:appuser . .

# Copy entrypoint script
COPY --chown=appuser:appuser docker-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create directories for data persistence
RUN mkdir -p /app/data /app/streamlit_chroma_db && \
    chown -R appuser:appuser /app

# Create Streamlit config directory
RUN mkdir -p /home/appuser/.streamlit && \
    chown -R appuser:appuser /home/appuser/.streamlit

# Create Streamlit config file
RUN cat > /home/appuser/.streamlit/config.toml << 'EOF'
[server]
port = 8501
address = "0.0.0.0"
headless = true
runOnSave = true
maxUploadSize = 200

[client]
toolbarMode = "minimal"
showErrorDetails = true

[logger]
level = "info"

[theme]
primaryColor = "#FF6B6B"
backgroundColor = "#FFFFFF"
secondaryBackgroundColor = "#F0F2F6"
textColor = "#262730"
font = "sans serif"
EOF

# Switch to non-root user for security
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8501/_stcore/health')" || exit 1

# Expose Streamlit port
EXPOSE 8501

# Volume for persistent ChromaDB storage
VOLUME ["/app/streamlit_chroma_db", "/app/data"]

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command
CMD ["streamlit", "run", "rag_pipeline.py", "--logger.level=info"]
