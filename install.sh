#!/bin/bash

# Exit on error
set -e

echo "Installing dependencies..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Python 3 if not present
if ! command -v python3 &> /dev/null; then
    echo "Installing Python 3..."
    brew install python3
fi

# Create backend data directory if it doesn't exist
echo "Setting up backend data directory..."
mkdir -p backend/data

# Initialize SQLite database if it doesn't exist
if [ ! -f "backend/data/cards.db" ]; then
    echo "Initializing SQLite database..."
    sqlite3 backend/data/cards.db <<EOF
CREATE TABLE IF NOT EXISTS answers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    correct INTEGER DEFAULT 0,
    partial INTEGER DEFAULT 0,
    incorrect INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS cards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    front TEXT NOT NULL,
    back TEXT NOT NULL,
    last_asked TEXT,
    next_review TEXT,
    retired BOOLEAN DEFAULT FALSE,
    streak INTEGER DEFAULT 0,
    images TEXT DEFAULT '[]',
    answers_id INTEGER,
    FOREIGN KEY (answers_id) REFERENCES answers(id)
);

CREATE TABLE IF NOT EXISTS tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS card_tags (
    card_id INTEGER,
    tag_id INTEGER,
    PRIMARY KEY (card_id, tag_id),
    FOREIGN KEY (card_id) REFERENCES cards(id),
    FOREIGN KEY (tag_id) REFERENCES tags(id)
);
EOF
fi

# Install Python dependencies
echo "Installing Python dependencies..."
if [ -f "backend/requirements.txt" ]; then
    python3 -m pip install -r backend/requirements.txt
else
    echo "Error: backend/requirements.txt not found"
    exit 1
fi

# Install pre-commit
echo "Installing pre-commit..."
python3 -m pip install pre-commit
pre-commit install

# Install Swift dependencies (if using SPM)
echo "Installing Swift dependencies..."
cd frontend
if [ -f "Package.swift" ]; then
    swift package resolve
else
    echo "Warning: Package.swift not found"
fi

# After the Homebrew check, add:
if ! command -v swift-format &> /dev/null; then
    echo "Installing swift-format..."
    brew install swift-format
fi

echo "Installation complete!"
