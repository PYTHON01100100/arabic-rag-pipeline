#!/bin/bash
# Docker entrypoint script for Arabic RAG Pipeline

set -e

# Verify required environment variables
if [ -z "$GEMINI_API_KEY" ]; then
    echo "ERROR: GEMINI_API_KEY environment variable is not set"
    echo "Please set GEMINI_API_KEY before starting the container"
    exit 1
fi

# Create necessary directories
mkdir -p /app/streamlit_chroma_db
mkdir -p /app/data
mkdir -p /home/appuser/.streamlit

# Ensure proper permissions
chown -R appuser:appuser /app
chown -R appuser:appuser /home/appuser

# Wait for healthy state (for dependency containers if any)
if [ -n "$WAIT_HOST" ]; then
    echo "Waiting for $WAIT_HOST to be ready..."
    timeout 30 bash -c "until nc -z $WAIT_HOST $WAIT_PORT 2>/dev/null; do echo 'Waiting...'; sleep 1; done" || {
        echo "WARNING: $WAIT_HOST:$WAIT_PORT did not become ready"
    }
fi

# Log startup information
echo "==================================="
echo "Starting Arabic RAG Pipeline"
echo "Python version: $(python --version)"
echo "Streamlit version: $(streamlit --version)"
echo "Port: $STREAMLIT_SERVER_PORT"
echo "==================================="

# Execute the main command
exec "$@"
