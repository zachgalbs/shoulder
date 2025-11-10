#!/bin/bash
# Shoulder Focus Tracker - Start Script

set -e  # Exit on error

echo "Starting Shoulder Focus Tracker..."
echo ""

# Check if virtual environment exists
if [ ! -d "llm_server/venv" ]; then
    echo "❌ Virtual environment not found."
    echo "Please run ./install.sh first"
    exit 1
fi

# Start the server
cd llm_server
source venv/bin/activate

echo "Server starting on http://127.0.0.1:8765"
echo "Press Ctrl+C to stop"
echo ""

python3 server.py
