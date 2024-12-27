# Flashcard App

A modern flashcard application built with Swift and Python, featuring spaced repetition learning and rich text support.

## Features

- 📝 Rich text support with markdown
- 🏷️ Tag-based organization
- 📊 Learning progress tracking
- 🔄 Spaced repetition system
- 📱 Native macOS interface
- 🖼️ Image support
- ⌨️ Keyboard-first navigation

## Prerequisites

- macOS 12.0 or later
- Xcode 14.0 or later (for development)
- Python 3.8 or later

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/flashcard-app.git
   cd flashcard-app
   ```

2. Run the installation script:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

   This will:
   - Install Homebrew (if not present)
   - Install Python 3 (if not present)
   - Set up the SQLite database
   - Install Python dependencies
   - Install pre-commit hooks
   - Set up Swift dependencies

## Running the App

1. Start the backend server:
   ```bash
   cd backend
   uvicorn main:app --reload
   ```

2. Open the frontend project in Xcode:
   ```bash
   cd frontend
   open frontend.xcodeproj
   ```

3. Build and run the project in Xcode (⌘R)

## Development

### Pre-commit Setup

This project uses pre-commit hooks to maintain code quality. The hooks are automatically installed when you run `install.sh`, but you can also set them up manually:

```bash
# Install pre-commit
pip install pre-commit

# Install the git hooks
pre-commit install
```

The pre-commit hooks will:
- Format Python code with Black
- Lint Python code with Flake8
- Format Swift code with swift-format
- Check for common issues (trailing whitespace, merge conflicts, etc.)

You can run the hooks manually on all files:
```bash
pre-commit run --all-files
```

Or on staged files only:
```bash
pre-commit run
```

The hooks will also run automatically before each commit. If any hooks fail, the commit will be blocked until the issues are fixed.
