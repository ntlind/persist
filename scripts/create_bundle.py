# flake8: noqa: E501
#!/usr/bin/env python3
import os
import shutil
import subprocess
import stat


def create_directory_structure():
    """Create the basic app bundle directory structure.

    Creates a fresh Persist.app bundle with the required directory structure,
    removing any existing bundle first.

    Returns
    -------
    str
        The path to the created app bundle (dist/Persist.app)
    """
    app_path = "dist/Persist.app"
    dirs = [
        "Contents/MacOS",
        "Contents/Resources",
        "Contents/Frameworks",
        "Contents/Resources/backend",
    ]

    # Remove existing bundle if it exists
    if os.path.exists(app_path):
        shutil.rmtree(app_path)

    # Create directories
    for dir in dirs:
        os.makedirs(os.path.join(app_path, dir), exist_ok=True)

    return app_path


def build_frontend():
    """Build the frontend using xcodebuild.

    Builds the Swift frontend app using xcodebuild in Release configuration.
    Output is placed in the build/Build/Products/Release directory.

    Raises
    ------
    subprocess.CalledProcessError
        If the xcodebuild command fails
    """
    print("Building frontend...")
    subprocess.run(
        [
            "xcodebuild",
            "-project",
            "frontend/Persist.xcodeproj",
            "-scheme",
            "Persist",
            "-configuration",
            "Release",
            "-derivedDataPath",
            "build",
        ],
        check=True,
    )


def create_launcher_script(app_path):
    """Create the launcher script that starts both backend and frontend.

    Creates an executable bash script that:
    - Sets up logging
    - Starts the Python backend server
    - Waits for backend to be ready
    - Launches the Swift frontend
    - Handles cleanup on shutdown

    Parameters
    ----------
    app_path : str
        Path to the app bundle where the launcher script should be created
    """
    print("Creating launcher script...")
    launcher = """#!/bin/bash
set -e

# Get the absolute path to the app bundle
APP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RESOURCES_DIR="$APP_DIR/../Resources"
LOG_FILE="$RESOURCES_DIR/app.log"

# Start logging
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "----------------------------------------"
echo "Starting Persist..."
echo "$(date): Application started"
echo "App directory: $APP_DIR"
echo "Resources directory: $RESOURCES_DIR"

# Ensure data directory exists
DATA_DIR="$RESOURCES_DIR/data"
mkdir -p "$DATA_DIR"
echo "Data directory: $DATA_DIR"

# Set up Python environment
export PYTHONPATH="$RESOURCES_DIR/backend"
export PATH="$RESOURCES_DIR/backend/venv/bin:$PATH"

# Start backend server
echo "Starting backend server..."
cd "$RESOURCES_DIR"
./backend_server &
BACKEND_PID=$!

# Wait for backend to initialize
echo "Waiting for backend to start..."
for i in {1..30}; do
    if curl -s http://127.0.0.1:2789/health >/dev/null; then
        echo "Backend started successfully with PID $BACKEND_PID"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Error: Backend failed to start"
        exit 1
    fi
    sleep 1
done

# Start frontend
echo "Starting frontend..."
FRONTEND_APP="$RESOURCES_DIR/frontend.app"
FRONTEND_BINARY="$FRONTEND_APP/Contents/MacOS/$(ls "$FRONTEND_APP/Contents/MacOS")"
echo "Launching frontend binary: $FRONTEND_BINARY"
"$FRONTEND_BINARY" &
FRONTEND_PID=$!
echo "Frontend launched with PID $FRONTEND_PID"

# Handle shutdown
cleanup() {
    echo "$(date): Shutting down..."
    kill $BACKEND_PID 2>/dev/null || true
    pkill -f frontend || true
    echo "$(date): Application shutdown complete"
    exit 0
}
trap cleanup SIGTERM SIGINT

# Wait for processes
wait $BACKEND_PID
cleanup
"""

    launcher_path = os.path.join(app_path, "Contents/MacOS/Persist")
    with open(launcher_path, "w") as f:
        f.write(launcher)

    # Make launcher executable
    st = os.stat(launcher_path)
    os.chmod(launcher_path, st.st_mode | stat.S_IEXEC)


def copy_backend(app_path):
    """Copy backend files and create virtualenv.

    Sets up the Python backend by:
    - Copying backend source files
    - Creating a virtual environment
    - Installing dependencies
    - Creating a backend launcher script

    Parameters
    ----------
    app_path : str
        Path to the app bundle where backend should be set up

    Raises
    ------
    subprocess.CalledProcessError
        If virtual environment creation or pip install fails
    """
    print("Setting up backend...")
    resources_path = os.path.join(app_path, "Contents/Resources")
    backend_path = os.path.join(resources_path, "backend")

    # Copy backend files
    backend_files = [
        "api",
        "core",
        "requirements.txt",
    ]

    for item in backend_files:
        src = os.path.join("backend", item)
        dst = os.path.join(backend_path, item)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Copy cards.db if it exists
    src_db = os.path.join("backend", "data", "cards.db")
    dst_db = os.path.join(backend_path, "data", "cards.db")
    if os.path.exists(src_db):
        os.makedirs(os.path.dirname(dst_db), exist_ok=True)
        shutil.copy2(src_db, dst_db)

    # Create virtualenv and install requirements
    print("Creating Python virtual environment...")
    subprocess.run(
        ["python3", "-m", "venv", os.path.join(backend_path, "venv")],
        check=True,
    )

    print("Installing Python requirements...")
    subprocess.run(
        [
            os.path.join(backend_path, "venv/bin/pip"),
            "install",
            "-r",
            os.path.join(backend_path, "requirements.txt"),
        ],
        check=True,
    )

    # Create backend launcher
    backend_launcher = """#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VENV_DIR="$DIR/backend/venv"

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Set working directory
cd "$DIR"

# Start backend server
exec python -m uvicorn api.main:app --host 127.0.0.1 --port 2789 --log-level info
"""

    backend_launcher_path = os.path.join(resources_path, "backend_server")
    with open(backend_launcher_path, "w") as f:
        f.write(backend_launcher)

    st = os.stat(backend_launcher_path)
    os.chmod(backend_launcher_path, st.st_mode | stat.S_IEXEC)


def copy_frontend(app_path):
    """Copy built frontend binary and resources.

    Copies the built frontend.app bundle into the main app bundle and
    creates necessary symlinks.

    Parameters
    ----------
    app_path : str
        Path to the app bundle where frontend should be copied
    """
    print("Copying frontend...")
    frontend_app_path = "build/Build/Products/Release/Persist.app"

    # Copy the entire frontend.app bundle into the Persist.app bundle
    frontend_dest = os.path.join(app_path, "Contents/Resources/frontend.app")
    shutil.copytree(frontend_app_path, frontend_dest)
    print(f"Frontend app bundle copied to: {frontend_dest}")

    # Create a symlink to the frontend binary
    macos_dir = os.path.join(frontend_dest, "Contents/MacOS")
    binary_name = os.listdir(macos_dir)[0]  # Get the actual binary name
    frontend_binary = os.path.join(macos_dir, binary_name)
    frontend_link = os.path.join(app_path, "Contents/MacOS/frontend")
    os.symlink(
        os.path.relpath(frontend_binary, os.path.dirname(frontend_link)),
        frontend_link,
    )
    print(f"Created symlink: {frontend_link} -> {frontend_binary}")


def main():
    """Create the complete app bundle.

    Main entry point that:
    1. Creates the app bundle structure
    2. Builds the frontend
    3. Creates required files and scripts
    4. Copies backend and frontend components
    5. Copies the database

    Raises
    ------
    Exception
        If any step of the bundle creation process fails
    """
    try:
        # Create app bundle structure
        app_path = create_directory_structure()

        # Build frontend
        build_frontend()

        # Create launcher script
        create_launcher_script(app_path)

        # Copy backend
        copy_backend(app_path)

        # Copy frontend
        copy_frontend(app_path)

        print(f"\nApp bundle created successfully at {app_path}")
        print("\nTo test the app bundle, run: make debug-dist")

    except Exception as e:
        print(f"Error creating app bundle: {str(e)}")
        raise


if __name__ == "__main__":
    main()
