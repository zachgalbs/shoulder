# Distributing Shoulder Without Apple Developer Program

Since you don't have an Apple Developer account, here are alternative ways to distribute your macOS application.

## Option 1: Distribute as Source Code Only (Easiest)

Users clone the repo and run the Python backend directly. No macOS app bundle needed.

### Update README.md to reflect this:

```markdown
## Installation

### Install Ollama
ollama pull llama3.2:3b

### Clone and Run
git clone https://github.com/YOUR_USERNAME/shoulder.git
cd shoulder/llm_server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 server.py
```

**Pros**: Simple, no code signing needed
**Cons**: Less user-friendly, requires technical knowledge

## Option 2: Distribute Unsigned macOS App

If you have a macOS .app bundle, you can distribute it unsigned.

### Build and Package:
1. Build your .app in Xcode
2. Zip it: `zip -r Shoulder.app.zip Shoulder.app`
3. Upload to GitHub Releases

### Users will need to:
1. Download `Shoulder.app.zip`
2. Unzip it
3. Right-click the app and select "Open" (first time only)
4. Click "Open" in the security dialog

**Warning to include in README**:
```markdown
⚠️ **Security Note**: This app is not notarized. On first launch:
1. Right-click `Shoulder.app` and select "Open"
2. Click "Open" in the security dialog
3. If blocked, go to System Settings > Privacy & Security and click "Open Anyway"
```

## Option 3: Distribute as Python Script with GUI

Convert the whole app to a Python application using a GUI framework.

### Options:
- **PyQt5/PyQt6**: Full-featured GUI
- **Tkinter**: Built into Python
- **rumps**: macOS menu bar apps in Python

### Example with rumps:
```python
# Install: pip install rumps
import rumps

class ShoulderApp(rumps.App):
    def __init__(self):
        super(ShoulderApp, self).__init__("Shoulder")
        self.menu = ["Set Focus", "View Stats"]

    @rumps.clicked("Set Focus")
    def set_focus(self, _):
        # Your focus setting logic
        pass

if __name__ == "__main__":
    ShoulderApp().run()
```

**Pros**: No code signing, fully open source
**Cons**: Need to rewrite the macOS app portion

## Option 4: Use PyInstaller for Standalone Executable

Create a standalone executable without Xcode.

### Steps:
```bash
pip install pyinstaller

# Create executable
pyinstaller --onefile --windowed --name Shoulder server.py

# This creates dist/Shoulder executable
cd dist
zip Shoulder.zip Shoulder
```

Users still need to right-click > Open for unsigned apps.

## Option 5: Web-Based Interface (Recommended Alternative)

Turn the backend into a web app users access via browser.

### Modify server.py to include a web UI:
```python
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles

# Add a simple web interface
@app.get("/", response_class=HTMLResponse)
async def web_interface():
    return """
    <html>
        <head><title>Shoulder Focus Tracker</title></head>
        <body>
            <h1>Shoulder Focus Tracker</h1>
            <input type="text" id="focus" placeholder="What should you focus on?">
            <button onclick="setFocus()">Set Focus</button>
            <script>
                async function setFocus() {
                    const focus = document.getElementById('focus').value;
                    // Call your analyze endpoint
                }
            </script>
        </body>
    </html>
    """
```

**Pros**:
- No app installation needed
- Works on any OS with a browser
- No code signing issues

**Cons**:
- Less native feel
- May need different approach for screen monitoring

## Recommended Approach for Your Case

Given no Apple Developer account, I recommend **Option 1** (source code distribution) combined with a simple setup script:

### Create an installation script:

```bash
#!/bin/bash
# install.sh

echo "Installing Shoulder Focus Tracker..."

# Check for Ollama
if ! command -v ollama &> /dev/null; then
    echo "Please install Ollama first: https://ollama.ai"
    exit 1
fi

# Pull LLM model
echo "Pulling LLM model..."
ollama pull llama3.2:3b

# Set up Python environment
cd llm_server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

echo "Installation complete! Run './start.sh' to start Shoulder"
```

### Create a start script:

```bash
#!/bin/bash
# start.sh

cd llm_server
source venv/bin/activate
python3 server.py
```

Make them executable:
```bash
chmod +x install.sh start.sh
```

## Summary

Without Apple Developer Program, your best options are:
1. **Distribute as source code** with install scripts (easiest, recommended)
2. **Distribute unsigned app** (requires users to bypass security warnings)
3. **Create web-based interface** (most accessible, platform-independent)

All of these can be distributed via GitHub Releases.
