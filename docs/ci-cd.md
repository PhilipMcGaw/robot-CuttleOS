# CI/CD Pipeline Documentation

This document describes the continuous integration and continuous deployment (CI/CD) pipeline for robot-CuttleOS.

## Overview

The CI/CD pipeline enforces code quality, test coverage, and documentation standards across all three services (Cockpit, Control, Datalogger) in the monorepo.

**Pipeline stages:**
1. **Lint & Format** — Python (ruff, mypy), TypeScript (ESLint, Prettier), YAML
2. **Tests** — Unit tests for each service
3. **Documentation** — Validate documentation changes and required status terminology
4. **Build** — Frontend TypeScript compilation, Python package building

## Local Development Workflow

### Run Tests Locally

```bash
# Install dev dependencies
pip install robot-cuttleos[all]

# Run all tests
pytest tests/

# Run tests for specific service
pytest tests/ -k cockpit
pytest tests/ -k control
pytest tests/ -k datalogger

# Run with coverage
pytest tests/ --cov=cockpit/src/rov_cockpit --cov=control/src/rov_control --cov=datalogger/src/rov_datalogger
```

### Format & Lint

```bash
# Format Python (black)
black cockpit/src control/src datalogger/src tests/

# Check formatting (ruff)
ruff check cockpit/src control/src datalogger/src tests/

# Fix linting issues
ruff check --fix cockpit/src control/src datalogger/src tests/

# Type check (mypy)
mypy cockpit/src control/src datalogger/src
```

### Frontend

The TypeScript source is under `frontend/src/`. The npm package and its
`package.json` are under `frontend/cockpit/`; the shared build scripts compile
the source into `cockpit/src/rov_cockpit/static/dist/`.

```bash
# Build frontend
./scripts/build_frontend.sh

# Lint TypeScript
cd frontend/cockpit && npm run typecheck

# Format TypeScript
No formatting script is currently defined in `frontend/cockpit/package.json`.
```

## GitHub Actions Workflows

The standalone service archives contained CI workflow examples, but they refer to repository layouts that are not the current monorepo. Any future workflow should be designed around the monorepo test and deployment paths.

The following workflows should be configured in `.github/workflows/`:

### 1. Tests & Lint (`test-and-lint.yml`)

**Trigger:** Push to main, pull requests

**Steps:**
- Checkout code
- Set up Python 3.14+ (all platforms: Linux, macOS, Windows)
- Install dependencies: `pip install robot-cuttleos[all]`
- Lint:
  - `ruff check --fix cockpit/src control/src datalogger/src tests/`
  - `mypy cockpit/src control/src datalogger/src --ignore-missing-imports`
  - Python syntax validation
- Test:
  - `pytest tests/ --cov --cov-report=term --cov-report=xml`
  - Upload coverage to Codecov/Coveralls
- Fail if:
  - Tests fail (exit code != 0)
  - Coverage drops below configured threshold (e.g., 70%)
  - Linting issues found (with --fix, should be auto-correctable)

**Python versions tested:** 3.14.x

### 2. Documentation Validation (`validate-docs.yml`)

**Trigger:** Push to main, pull requests affecting docs

**Steps:**
- Checkout code
- Run documentation policy check:
  ```bash
  python tests/test_control_documentation.py
  ```
- Check for required documentation updates:
  - Any change to `src/**`, `configs/**`, `scripts/**`, `requirements.txt` must update:
    - `MASTER_CONTEXT.md` (architecture/design decisions)
    - `docs/` (user-facing documentation)
    - Relevant `README.md` in service folder
- Validate YAML frontmatter in markdown files
- Check for broken internal links in documentation
- Verify status terminology:
  - Designed, simulated, software-tested, bench-tested, wet-tested, production-proven
  - All claims must be backed by evidence (code comment, test, status doc)

### 3. Frontend Build (`frontend-build.yml`)

**Trigger:** Push to main, pull requests affecting `frontend/`

**Steps:**
- Checkout code
- Set up Node.js (20.x or latest LTS)
- Install dependencies: `npm install` in `frontend/cockpit/`
- TypeScript compilation:
  - `npm run build`
  - `npm run typecheck`
- Fail if build or linting fails
- (Optional) Upload compiled artifacts for deployment staging

### 4. Security Scan (`security.yml`)

**Trigger:** Push to main, pull requests

**Steps:**
- Checkout code
- Dependency vulnerability scan:
  - `pip audit` (Python dependencies)
  - `npm audit` (Node dependencies)
- SAST (static application security testing):
  - `bandit -r cockpit/src control/src datalogger/src`
  - Optional: SonarQube or similar for deeper analysis
- Check for hardcoded secrets (gitleaks)

### 5. Build & Release (`build-release.yml`)

**Trigger:** Tag push (e.g., `v0.1.0`)

**Steps:**
- Build Python package:
  ```bash
  python -m build
  ```
- Build frontend distribution
- Create GitHub Release with assets
- (Future) Push to PyPI or artifact repository
- (Future) Trigger deployment to staging environment

## Configuration Files

### `.github/workflows/test-and-lint.yml`

```yaml
name: Test & Lint

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.14"]

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ matrix.python-version }}

      - name: Install dependencies
        run: pip install robot-cuttleos[all]

      - name: Lint with ruff
        run: ruff check cockpit/src control/src datalogger/src tests/

      - name: Type check with mypy
        run: mypy cockpit/src control/src datalogger/src --ignore-missing-imports

      - name: Run tests
        run: pytest tests/ --cov=cockpit/src/rov_cockpit --cov=control/src/rov_control --cov=datalogger/src/rov_datalogger --cov-report=xml

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml
```

### `.github/workflows/validate-docs.yml`

```yaml
name: Validate Documentation

on:
  push:
    branches: [main, develop]
    paths:
      - 'docs/**'
      - 'MASTER_CONTEXT.md'
      - '**/README.md'
  pull_request:
    branches: [main, develop]

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.14"

      - name: Run documentation policy check
        run: python tests/test_control_documentation.py
```

### `.github/workflows/frontend-build.yml`

```yaml
name: Frontend Build

on:
  push:
    branches: [main, develop]
    paths:
      - 'frontend/**'
  pull_request:
    branches: [main, develop]
    paths:
      - 'frontend/**'

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install dependencies
        working-directory: ./frontend/cockpit
        run: npm install

      - name: Build
        working-directory: ./frontend/cockpit
        run: npm run build

      - name: Lint
        working-directory: ./frontend/cockpit
      - name: Type check
        working-directory: ./frontend/cockpit
        run: npm run typecheck
```

## Testing Strategy

### Unit Tests
- Located in `tests/` at monorepo root
- Organized by service (e.g., `test_*cockpit*.py`, `test_*control*.py`)
- All tests must pass before merge

### Integration Tests
- Full-stack tests in `tests/integration/`
- Test NATS communication, WebSocket relay, database operations
- Run on every push (can be gated to main/develop only)

### System Tests
- Located in `tests/system/`
- Require hardware or simulator mode
- Run on-demand or scheduled (nightly builds)

## Coverage Requirements

**Minimum coverage thresholds:**
- Overall: 70%
- Critical paths (safety, authentication): 90%
- New code: must not decrease coverage

## Documentation Requirements

All changes affecting user-visible behavior must include documentation updates:

**Required updates:**
- `MASTER_CONTEXT.md` — architecture/design decisions
- `docs/` — user-facing documentation
- Service `README.md` — high-level service overview
- Inline code comments — explain "why", not "what"

**Status terminology must be used consistently:**
- `Designed` — planned, not yet implemented
- `Simulated` — software-tested in mock/simulator mode
- `Software-tested` — unit/integration test coverage
- `Bench-tested` — hardware tested without vehicle
- `Wet-tested` — tested with vehicle in water
- `Production-proven` — deployed and verified in operation

## Deployment

### Staging Deployment

After successful tests on `develop`:
1. Create release branch: `release/v0.x.y`
2. Run full test suite
3. Merge to `main` after approval
4. Tag: `git tag v0.x.y && git push origin v0.x.y`
5. Build & release workflow triggers

### Production Deployment

1. Tag creates GitHub Release with artifacts
2. (Future) Deploy to PyPI
3. (Future) Auto-deploy to staging environment
4. Manual approval for production deployment to live robots

## Monitoring & Alerts

**Automated alerts on:**
- Test failures (email to maintainers)
- Coverage drops
- Dependency vulnerabilities
- Broken documentation links

## Future Improvements

- [ ] Multi-platform testing (Linux, macOS, Windows)
- [ ] Performance benchmarking (regression detection)
- [ ] Docker image building & registry push
- [ ] Automated changelog generation
- [ ] Semantic versioning automation
- [ ] Deployment to staging/production Raspberry Pi
- [ ] Hardware simulation test suite
- [ ] E2E browser testing (Playwright/Puppeteer)
