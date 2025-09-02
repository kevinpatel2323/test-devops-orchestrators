# LoyaltyX Orchestrator - DevOps Implementation

This project is a fully implemented and optimized token swap orchestrator for the LoyaltyX ecosystem. It connects to Ethereum via Infura, fetches token prices from Chainlink, calculates optimal swap paths, and provides a robust API layer.

---

## Project Overview

This orchestrator continuously:
- Connects to Ethereum via Infura
- Fetches token prices from Chainlink
- Calculates optimal token swap paths
- Logs all swap paths to `logs/swap_routes.json`
- Emits uptime and heartbeat logs to `logs/output.log`

A REST API (`api.js`) exposes:
- `/api/routes`: Latest swap paths
- `/api/routes/:from/:to`: Single pair lookup
- `/healthz`: System heartbeat check (liveness probe)
- `/readyz`: Dependency readiness check (readiness probe)
- `/metrics`: Prometheus-style metrics (uptime, memory, CPU)

---

## Completed Tasks

### 1. Improved Shell Scripts

The installation and setup scripts have been enhanced with:
- Pre-flight requirement checks (git installation, Node.js version verification)
- Comprehensive logging with timestamps
- Error handling and environment validation
- PID lock mechanism to prevent double-starts
- Proper exit codes for abnormal termination

### 2. Containerization

- Created a production-ready `Dockerfile` with multi-stage builds
- Added `docker-compose.yml` for local orchestration
- Implemented volume mounting for persistent logs
- Configured environment variable injection

### 3. CI/CD Automation

Implemented GitHub Actions workflow that:
- Triggers on every push to main branch
- Builds a Docker image of the project
- Tags the image with the commit SHA
- Pushes the image to GitHub Container Registry
- Performs security scanning with Trivy

### 4. Enhanced Monitoring

- Added `/healthz` (liveness probe) endpoint
- Implemented `/readyz` (readiness probe) endpoint
- Fixed the silent failure issue in heartbeat logging

---

## Usage

### Local Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Build and run in production mode
npm run build
npm start
```

### Docker Deployment

```bash
# Build and run with Docker Compose
docker-compose up -d

# Or use the Docker image directly
docker pull ghcr.io/kevinpatel2323/veltrix-capital:latest
docker run -p 4000:4000 -v ./logs:/app/logs -e INFURA_URL=your_infura_url ghcr.io/kevinpatel2323/veltrix-capital:latest
```

### One-Click Installation

```bash
curl -sSL https://raw.githubusercontent.com/kevinpatel2323/veltrix-capital/main/install.sh | bash
```
    
---

## Functional Endpoints

| Endpoint                  | Description                                 |
|---------------------------|---------------------------------------------|
| `/api/routes`             | All recent swap paths                       |
| `/api/routes/:from/:to`   | One specific token pair                     |
| `/healthz`                | Uptime check (based on heartbeat log)       |
| `/metrics`                | Prometheus metrics (uptime, memory, CPU)    |

---

## Project Structure

```
eth-swap-devops-challenge/
├── setup.sh           # Setup script
├── start.sh           # Starts app.js and api.js
├── install.sh         # Installation script to set up and run on the client node
├── .env_example       # Set your INFURA_URL here
├── package.json
├── logs/
│   ├── output.log         # Heartbeat logs (every 5s)
│   └── swap_routes.json   # Swap route logs (every 1m)
│── dist/               # Build
└── src/
    ├── app.ts          # Orchestrator – fetches and logs paths
    |── api.ts          # REST API
    |── constant.ts     # Constant
    |── graph.ts        # Graph handler
    |── routes.ts       # health endpoints
    └── utis.ts         # Utils
```

---

## Requirements

- Node.js 18+
- Bash (for script execution)
- TypeScript
- Infura project ID for Ethereum Mainnet (free to register at https://infura.io)

---

## 🔍 Evaluation Criteria

| Category        | Expectations                                  |
|----------------|-----------------------------------------------|
| **Reliability** | Can you make the service stable?             |
| **Observability** | Do you improve logs, health, metrics?       |
| **Shell Scripting** | Are scripts clean, safe, readable?        |
| **Containerization** | Do you build a usable Docker setup?      |
| **Problem Solving** | Can you debug a hidden runtime issue?     |

---

Good luck! Feel free to make suggestions beyond the requirements — we value initiative and clear thinking.
