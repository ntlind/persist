run-dev:
	cd backend && PYTHONPATH=$(PWD)/backend uvicorn api.main:app --reload --port 2789

run-prod:
	cd backend && PYTHONPATH=$(PWD)/backend uvicorn api.main:app --host 0.0.0.0 --port 2789

generate-certs:
	cd backend && openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

install:
	cd backend && pip install -r requirements.txt

install-dev:
	cd backend && pip install -r requirements.txt
	pip install pre-commit
	pre-commit install

test:
	cd backend && PYTHONPATH=$(PWD)/backend python -m pytest -v --cov=api --cov=core --cov-report=term-missing --cov-report=html --cov-config=.coveragerc tests/ --cov-fail-under=80
	$(MAKE) clean

lint:
	pre-commit run --all-files

clean:
	find . -type d -name "__pycache__" -exec rm -r {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name "*.pyd" -delete
	find . -type f -name ".coverage" -delete
	find . -type f -name "coverage.xml" -delete
	find . -type d -name "*.egg-info" -exec rm -r {} +
	find . -type d -name "*.egg" -exec rm -r {} +
	find . -type d -name ".pytest_cache" -exec rm -r {} +
	find . -type d -name "venv" -exec rm -r {} +
	find . -type d -name "dist" -exec rm -r {} +
	find . -type d -name "build" -exec rm -r {} +

db-init:
	cd backend && PYTHONPATH=$(PWD)/backend python scripts/init_db.py

db-migrate:
	cd backend && PYTHONPATH=$(PWD)/backend alembic upgrade head

db-rollback:
	cd backend && PYTHONPATH=$(PWD)/backend alembic downgrade -1

xcode:
	open frontend/Persist.xcodeproj

build-frontend:
	xcodebuild -project frontend/Persist.xcodeproj -scheme Persist -configuration Release -derivedDataPath build

bundle:
	python3 scripts/create_bundle.py

debug-dist:
	@echo "Checking app bundle structure..."
	@ls -la dist/Persist.app/Contents/MacOS
	@echo "\nChecking processes..."
	@ps aux | grep backend_server
	@echo "\nTrying to run app..."
	@open dist/Persist.app
	@sleep 2
	@echo "\nChecking log..."
	@cat dist/Persist.app/Contents/Resources/app.log || echo "No log file yet"

copy-prod-db:
	@if [ ! -d "backend/data" ]; then mkdir -p backend/data; fi
	@cp dist/Persist.app/Contents/Resources/backend/data/cards.db backend/data/cards.db
	@echo "Database copied from production app to backend/data/cards.db"

.PHONY: run-dev run-prod install install-dev test lint clean generate-certs db-init db-migrate db-rollback xcode build-frontend bundle debug-dist copy-prod-db
