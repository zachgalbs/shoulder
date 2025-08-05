#!/bin/bash
#
# Setup script for LLM Analysis Server
# Installs dependencies and configures environment

set -e

echo "================================================"
echo "LLM Analysis Server Setup"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Python version
echo -e "\n${YELLOW}Checking Python installation...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo -e "${GREEN}✓ Python $PYTHON_VERSION found${NC}"
    PYTHON_CMD="python3"
else
    echo -e "${RED}✗ Python 3 not found. Please install Python 3.8 or later${NC}"
    exit 1
fi

# Create virtual environment
echo -e "\n${YELLOW}Setting up virtual environment...${NC}"
VENV_DIR="venv"

if [ -d "$VENV_DIR" ]; then
    echo "Virtual environment already exists. Removing old one..."
    rm -rf "$VENV_DIR"
fi

$PYTHON_CMD -m venv "$VENV_DIR"
echo -e "${GREEN}✓ Virtual environment created${NC}"

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo -e "\n${YELLOW}Upgrading pip...${NC}"
pip install --upgrade pip wheel setuptools

# Install dependencies
echo -e "\n${YELLOW}Installing Python dependencies...${NC}"
pip install -r requirements.txt

# Install additional evaluation dependencies
echo -e "\n${YELLOW}Installing evaluation dependencies...${NC}"
pip install numpy pandas matplotlib seaborn

# Check if Ollama is installed
echo -e "\n${YELLOW}Checking Ollama installation...${NC}"
if command -v ollama &> /dev/null; then
    echo -e "${GREEN}✓ Ollama is installed${NC}"
    
    # Check if Ollama is running
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Ollama is running${NC}"
        
        # List available models
        echo -e "\n${YELLOW}Available Ollama models:${NC}"
        ollama list
        
        # Check for recommended model
        if ollama list | grep -q "dolphin-mistral"; then
            echo -e "${GREEN}✓ Recommended model 'dolphin-mistral' is available${NC}"
        else
            echo -e "\n${YELLOW}Pulling recommended model 'dolphin-mistral'...${NC}"
            echo "This may take a few minutes..."
            ollama pull dolphin-mistral:latest
            echo -e "${GREEN}✓ Model downloaded${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Ollama is installed but not running${NC}"
        echo "Start Ollama with: ollama serve"
    fi
else
    echo -e "${RED}✗ Ollama is not installed${NC}"
    echo "Please install Ollama from: https://ollama.ai"
    echo "After installation, run: ollama pull dolphin-mistral:latest"
fi

# Create necessary directories
echo -e "\n${YELLOW}Creating directories...${NC}"
mkdir -p ~/src/shoulder/screenshots
mkdir -p ~/src/shoulder/analyses
mkdir -p ~/src/shoulder/llm_server
echo -e "${GREEN}✓ Directories created${NC}"

# Copy server files to expected location
echo -e "\n${YELLOW}Setting up server files...${NC}"
cp server.py ~/src/shoulder/llm_server/
cp requirements.txt ~/src/shoulder/llm_server/
cp -r "$VENV_DIR" ~/src/shoulder/llm_server/
echo -e "${GREEN}✓ Server files copied to ~/src/shoulder/llm_server/${NC}"

# Create launcher script
echo -e "\n${YELLOW}Creating launcher script...${NC}"
cat > start_server.sh << 'EOF'
#!/bin/bash
# Start the LLM Analysis Server

cd "$(dirname "$0")"

# Activate virtual environment
source venv/bin/activate

# Check if Ollama is running
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "Starting Ollama..."
    ollama serve &
    sleep 3
fi

# Start the server
echo "Starting LLM Analysis Server on port 8765..."
python server.py
EOF

chmod +x start_server.sh
echo -e "${GREEN}✓ Launcher script created (start_server.sh)${NC}"

# Create test script
cat > test_server.sh << 'EOF'
#!/bin/bash
# Test the LLM Analysis Server

cd "$(dirname "$0")"
source venv/bin/activate

echo "Testing server endpoints..."

# Test health endpoint
echo -n "Testing /health endpoint... "
if curl -s http://localhost:8765/health | grep -q "status"; then
    echo "✓"
else
    echo "✗"
fi

# Test analysis endpoint with sample data
echo -n "Testing /analyze endpoint... "
RESPONSE=$(curl -s -X POST http://localhost:8765/analyze \
    -H "Content-Type: application/json" \
    -d '{
        "text": "func calculateSum(a: Int, b: Int) -> Int { return a + b }",
        "context": {
            "app_name": "Xcode",
            "window_title": "Calculator.swift",
            "duration_seconds": 120,
            "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
        }
    }')

if echo "$RESPONSE" | grep -q "productivity_score"; then
    echo "✓"
    echo "Response: $RESPONSE" | python -m json.tool
else
    echo "✗"
    echo "Response: $RESPONSE"
fi
EOF

chmod +x test_server.sh
echo -e "${GREEN}✓ Test script created (test_server.sh)${NC}"

echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo -e "\nTo start the server:"
echo -e "  ${YELLOW}./start_server.sh${NC}"
echo -e "\nTo run evaluation:"
echo -e "  ${YELLOW}source venv/bin/activate${NC}"
echo -e "  ${YELLOW}python evaluation.py${NC}"
echo -e "\nTo test the server:"
echo -e "  ${YELLOW}./test_server.sh${NC}"
echo -e "\n${YELLOW}Note:${NC} Make sure Ollama is running before starting the server"