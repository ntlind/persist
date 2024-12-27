run-dev:
	cd backend && uvicorn main:app --reload

run-prod:
	cd backend && uvicorn main:app --host 0.0.0.0 --port 8000

generate-certs:
	cd backend && openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

install:
	cd backend && pip install -r requirements.txt

install-dev:
	cd backend && pip install -r requirements.txt
	pip install pre-commit
	pre-commit install

test:
	cd backend && PYTHONPATH=. python -m pytest --cov=. --cov-report=term-missing --cov-report=html --cov-config=.coveragerc tests/ --cov-fail-under=100; \
	-$(MAKE) clean

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

db-init:
	cd backend && python scripts/init_db.py

db-migrate:
	cd backend && alembic upgrade head

db-rollback:
	cd backend && alembic downgrade -1

xcode:
	open frontend/frontend.xcodeproj

build-frontend:
	xcodebuild -project frontend/frontend.xcodeproj -scheme frontend -configuration Debug build

help:
	@echo "Available commands:"
	@echo "Backend commands:"
	@echo "  run-dev      : Start development server with auto-reload"
	@echo "  run-prod     : Start production server"
	@echo "  install      : Install Python dependencies"
	@echo "  install-dev  : Install development dependencies including pre-commit"
	@echo "  test         : Run tests"
	@echo "  lint         : Run pre-commit hooks on all files"
	@echo "  clean        : Remove Python cache files"
	@echo "  generate-certs: Generate SSL certificates"
	@echo "  db-init      : Initialize database"
	@echo "  db-migrate   : Run database migrations"
	@echo "  db-rollback  : Rollback last database migration"
	@echo ""
	@echo "Frontend commands:"
	@echo "  xcode        : Open project in Xcode"
	@echo "  build-frontend: Build frontend using xcodebuild"

.PHONY: run-dev run-prod install install-dev test lint clean generate-certs db-init db-migrate db-rollback xcode build-frontend help
