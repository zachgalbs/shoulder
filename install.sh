#!/bin/bash
# Shoulder Focus Tracker - Installation Script

set -e  # Exit on error

echo "========================================="
echo "  Shoulder Focus Tracker - Installation"
echo "========================================="
echo ""

# Check for Ollama
echo "Checking for Ollama..."
if ! command -v ollama &> /dev/null; then
    echo "❌ Ollama is not installed."
    echo ""
    echo "Please install Ollama first:"
    echo "  1. Visit https://ollama.ai"
    echo "  2. Download and install Ollama for macOS"
    echo "  3. Run this script again"
    exit 1
fi
echo "✓ Ollama found"
echo ""

# Check for Python
echo "Checking for Python 3..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed."
    echo "Please install Python 3.9 or higher and try again."
    exit 1
fi
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo "✓ Python $PYTHON_VERSION found"
echo ""

# Pull LLM model
echo "Pulling LLM model (llama3.2:3b)..."
echo "This may take a few minutes depending on your internet connection..."
ollama pull llama3.2:3b
echo "✓ Model downloaded"
echo ""

# Set up Python virtual environment
echo "Setting up Python virtual environment..."
cd llm_server
python3 -m venv venv
echo "✓ Virtual environment created"
echo ""

# Activate and install dependencies
echo "Installing Python dependencies..."
source venv/bin/activate
pip install --upgrade pip > /dev/null
pip install -r requirements.txt
echo "✓ Dependencies installed"
echo ""

echo "========================================="
echo "  Installation Complete!"
echo "========================================="
echo ""
echo "To start Shoulder, run:"
echo "  ./start.sh"
echo ""
echo "The server will be available at http://127.0.0.1:8765"
echo ""
