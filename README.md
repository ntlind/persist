# Persist

A modern Anki flashcard application built with Swift and Python.

## Features

I used to be a frequent Quizlet user, but I grew tired of how cumbersome it was to add to and enhance my flashcards. This app offers several improvements that make it more suitable for everyday use:

- 📝 Easy editing and modification of flashcards
- 🏷️ Tag-based organization (where one card can appear in multiple sets)
- 📊 Streak and incorrect/correct ratio tracking and sorting
- 🔔 macOS notifications to nudge behavior
- 🖼️ Image support
- ⌨  Keyboard shortcuts

![Flashcard example](https://github.com/ntlind/persist/blob/main/assets/example.png?raw=true)

## Prerequisites

- macOS 12.0 or later
- Xcode 14.0 or later (for development)
- Python 3.8 or later

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/ntlind/persist.git
   cd persist
   ```

2. Install dependencies:
   ```bash
   # For production
   make install

   # For development (includes pre-commit hooks)
   make install-dev
   ```

    Running `make install-dev` will install pre-commit hooks that:
    - Format Python code with Black
    - Lint Python code with Flake8
    - Check for common issues (trailing whitespace, merge conflicts, etc.)


## Running the App

### Development

Run the backend server:
```bash
make run-dev
```

On your first run, you need to initialize the database:
```bash
make db-init
```

Open the frontend in Xcode:
```bash
make xcode
# or make build-frontend
```

Run tests:
```bash
make test
```

### Building and Debugging

Clean build artifacts:
```bash
make clean
```

Create application bundle:
```bash
make bundle
```

Once bundled, you can run the app from the Finder:
```bash
open dist/Persist.app
```

Debug distribution:
```bash
make debug-dist
```

### All Available Make Commands

| Command | Description |
|---------|-------------|
| `run-dev` | Run backend server in development mode with hot reload |
| `run-prod` | Run backend server in production mode |
| `install` | Install production dependencies |
| `install-dev` | Install development dependencies and pre-commit hooks |
| `test` | Run tests with coverage reporting |
| `lint` | Run pre-commit hooks on all files |
| `clean` | Remove build artifacts and cache files |
| `db-init` | Initialize the database |
| `db-migrate` | Run database migrations |
| `db-rollback` | Rollback last database migration |
| `xcode` | Open the project in Xcode |
| `build-frontend` | Build the frontend in Release configuration |
| `bundle` | Create the application bundle |
| `debug-dist` | Debug the distributed application bundle |
| `copy-prod-db` | Copy production database to development environment |
