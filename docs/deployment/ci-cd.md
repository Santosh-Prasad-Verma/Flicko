# CI/CD Pipeline

> **Reading time:** ~5 minutes · **Audience:** DevOps · **Last Updated:** 2026-04-11

Flicko mandates automated Continuous Integration and Continuous Deployment (CI/CD) to prevent broken code from ever reaching the production VPS or mobile App Stores. We orchestrate this exclusively via GitHub Actions.

---

## 1. Backend CI (Testing & Linting)

The backend workflow triggers on every Pull Request to `main`. It prevents merging if tests fail or code style is violated.

**File:** `.github/workflows/backend-ci.yml`

```yaml
name: Backend CI

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.22'

    - name: Verify Dependencies
      run: go mod verify

    - name: Go Vet & Lint
      run: |
        go vet ./...
        go install honnef.co/go/tools/cmd/staticcheck@latest
        staticcheck ./...

    - name: Run Tests
      # Ensures all unit tests pass. Does not run DB-heavy integration tests unless mocked.
      run: go test -v ./... -coverprofile=coverage.txt
```

---

## 2. Backend CD (VPS Auto-Deploy)

When a developer merges a feature into `main`, GitHub Actions automatically connects to the production VPS and triggers a rolling Docker-Compose rebuild.

**File:** `.github/workflows/backend-cd.yml`

*Requires GitHub Repository Secrets:* `VPS_IP`, `VPS_SSH_KEY`, `VPS_USER`

```yaml
name: Deploy Backend

on:
  push:
    branches: [ "main" ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Deploy to VPS via SSH
      uses: appleboy/ssh-action@v1.0.3
      with:
        host: ${{ secrets.VPS_IP }}
        username: ${{ secrets.VPS_USER }}
        key: ${{ secrets.VPS_SSH_KEY }}
        script: |
          cd /opt/flicko
          git pull origin main
          docker compose -f docker-compose.prod.yml up -d --build
```
This ensures zero drift between the `main` GitHub branch and actual production servers.

---

## 3. Frontend CI/CD (EAS/Flutter Build)

Flutter apps require complex Xcode/Android Studio setups to compile. Rather than managing this, Flicko utilizes **EAS (Flutter Application Services)** via GitHub Actions.

When code is merged to `main`, EAS spins up a cloud macOS worker, compiles the `.ipa` (iOS) and `.aab` (Android), and automatically submits them to the Apple TestFlight and Google Play Internal testing tracks.

**File:** `.github/workflows/mobile-cd.yml`

```yaml
name: Mobile EAS Build

on:
  push:
    branches: [ "main" ]
    paths:
      - 'mobile/**' # Only trigger if mobile code changed

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Setup EAS
        uses: expo/expo-github-action@v8
        with:
          eas-version: latest
          token: ${{ secrets.EXPO_TOKEN }}

      - name: Install dependencies
        working-directory: ./mobile
        run: npm ci

      - name: Build & Submit (Android)
        working-directory: ./mobile
        run: eas build --platform android --profile production --auto-submit

      - name: Build & Submit (iOS)
        working-directory: ./mobile
        run: eas build --platform ios --profile production --auto-submit
```
