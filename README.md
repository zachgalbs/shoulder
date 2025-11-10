# Shoulder

A macOS focus tracking and productivity monitoring application that uses AI to help you stay on task.

## Overview

Shoulder monitors your computer activity and uses local AI (via Ollama) to analyze whether your current activities align with your stated focus. It helps you maintain productivity by intelligently detecting when you're getting distracted.

## Features

- Real-time activity monitoring
- AI-powered focus validation using local LLMs
- Screenshot analysis with OCR
- Activity logging and analysis
- Privacy-focused: all AI processing happens locally on your machine

## Requirements

- macOS (tested on latest versions)
- Python 3.13 or higher
- [Ollama](https://ollama.ai) installed for local LLM inference

## Quick Installation

The easiest way to install Shoulder is using the automated installation script:

```bash
# Clone the repository
git clone https://github.com/zachgalbs/shoulder.git
cd shoulder

# Run the installation script
./install.sh

# Start the server
./start.sh
```

The server will start on `http://127.0.0.1:8765`

## Manual Installation

If you prefer to install manually:

### 1. Install Ollama

First, install Ollama from [ollama.ai](https://ollama.ai) and pull a supported model:

```bash
# Install Ollama, then pull a model
ollama pull llama3.2:3b
```

### 2. Set Up the Backend Server

Clone this repository and set up the Python backend:

```bash
git clone https://github.com/zachgalbs/shoulder.git
cd shoulder/llm_server

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Run the Server

Start the backend server:

```bash
cd llm_server
source venv/bin/activate
python3 server.py
```

The server will start on `http://127.0.0.1:8765`

## Usage

1. Start the server with `./start.sh` (or manually activate venv and run `python3 server.py`)
2. The API will be available at `http://127.0.0.1:8765`
3. You can test the health endpoint: `curl http://127.0.0.1:8765/health`
4. Use the `/analyze` endpoint to check if your current activity matches your focus

## Data Storage

Shoulder stores analysis data locally in the following directories:

- `analyses/` - AI analysis results by date
- `screenshots/` - OCR text from screenshots
- `blocking_logs/` - Activity blocking logs

## API Endpoints

The backend server provides the following endpoints:

- `GET /health` - Health check
- `POST /analyze` - Analyze current activity
- `GET /models` - List available LLM models
- `POST /pull_model` - Download a new LLM model

## Privacy

All AI processing happens locally on your machine using Ollama. No data is sent to external servers.

## License

[Add your license here]

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
