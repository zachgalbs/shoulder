# Release Guide for Shoulder

This guide explains how to prepare and publish releases so users can download your application from GitHub.

## Step 1: Prepare Your Repository

1. **Update README.md** with your actual GitHub username:
   - Replace `YOUR_USERNAME` with your GitHub username in README.md

2. **Add a LICENSE file** (recommended):
   ```bash
   # Example for MIT License
   # Visit https://choosealicense.com/ to pick a license
   ```

3. **Commit your code**:
   ```bash
   git add .
   git commit -m "Initial commit: Shoulder focus tracking app"
   ```

## Step 2: Push to GitHub

1. **Create a new repository on GitHub**:
   - Go to https://github.com/new
   - Name it "shoulder"
   - Don't initialize with README (we already have one)
   - Click "Create repository"

2. **Push your code**:
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/shoulder.git
   git branch -M main
   git push -u origin main
   ```

## Step 3: Build Your macOS App

Before creating a release, you need to build the macOS companion app:

1. **Build the .app bundle** using Xcode (if you have a Swift/SwiftUI project)
2. **Archive the app**:
   ```bash
   # Navigate to where your .app bundle is built
   # Typically: ~/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/

   # Create a zip file
   cd /path/to/your/app
   zip -r Shoulder.app.zip Shoulder.app
   ```

3. **Optional: Notarize your app** (recommended for easy installation):
   - Follow Apple's notarization process
   - This prevents Gatekeeper warnings on user's machines

## Step 4: Create a GitHub Release

1. **Go to your repository on GitHub**:
   ```
   https://github.com/YOUR_USERNAME/shoulder
   ```

2. **Click "Releases"** in the right sidebar (or go to `/releases`)

3. **Click "Create a new release"** or "Draft a new release"

4. **Fill in the release details**:
   - **Tag version**: `v1.0.0` (or your version number)
   - **Release title**: `Shoulder v1.0.0 - Initial Release`
   - **Description**: Describe what's included, e.g.:
     ```markdown
     ## What's New
     - Initial release of Shoulder focus tracking app
     - AI-powered activity monitoring
     - Local LLM integration via Ollama

     ## Installation
     See the [README](https://github.com/YOUR_USERNAME/shoulder#installation) for installation instructions.

     ## Requirements
     - macOS (latest versions)
     - Python 3.13+
     - Ollama installed locally
     ```

5. **Upload release assets**:
   - Click "Attach binaries by dropping them here or selecting them"
   - Upload `Shoulder.app.zip` (your macOS app)
   - Optionally upload a source code zip if you want to provide it separately

6. **Click "Publish release"**

## Step 5: Set Up GitHub Pages (Optional)

If you want a nice project website:

1. **Create a `docs` folder** or use `gh-pages` branch

2. **Create a simple index.html** in the docs folder or:
   - Go to Settings > Pages
   - Select "Deploy from a branch"
   - Choose "main" branch and "/root" or "/docs" folder
   - Click Save

3. **Your site will be live at**:
   ```
   https://YOUR_USERNAME.github.io/shoulder/
   ```

## Step 6: Update README

After creating your first release, update README.md:
- Replace `YOUR_USERNAME` with your actual GitHub username
- Update the download link to point to your releases page
- Add badges (optional):
  ```markdown
  ![GitHub release](https://img.shields.io/github/v/release/YOUR_USERNAME/shoulder)
  ![GitHub downloads](https://img.shields.io/github/downloads/YOUR_USERNAME/shoulder/total)
  ```

## For Future Releases

When you want to release a new version:

1. Make your changes and commit them
2. Push to GitHub
3. Build a new version of the macOS app
4. Create a new release with a new tag (e.g., `v1.1.0`)
5. Upload the new .app.zip file

## Download URLs

After creating a release, users can download your app from:
- Release page: `https://github.com/YOUR_USERNAME/shoulder/releases`
- Direct link to latest: `https://github.com/YOUR_USERNAME/shoulder/releases/latest`
- Direct download: `https://github.com/YOUR_USERNAME/shoulder/releases/download/v1.0.0/Shoulder.app.zip`

## Notes

- **Keep sensitive data out**: The .gitignore file excludes user data (analyses, screenshots, logs)
- **Virtual environment excluded**: The venv folder is not included in the repository
- **Users will need to**: Install dependencies themselves using requirements.txt
- **Consider**: Creating an installation script to automate the setup process
