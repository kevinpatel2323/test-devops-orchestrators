# Docker Containerization Guide

## 🐳 Overview

The Swap Optimizer Orchestrator has been fully containerized with production-ready Docker configuration including:
- Multi-stage Dockerfile for optimized images
- Docker Compose for local orchestration
- Development and production configurations
- Optional monitoring stack (Prometheus, Grafana, Loki)
- Health checks and resource limits
- Security best practices

## 📦 Architecture

### Docker Images

1. **Production Image** (`swap-optimizer:production`)
   - Alpine-based for minimal size (~150MB)
   - Non-root user execution
   - Health checks configured
   - Signal handling with dumb-init
   - Optimized for production deployment

2. **Development Image** (`swap-optimizer:development`)
   - Includes development tools
   - Hot reload support
   - Volume mounts for live code changes
   - Debug mode enabled

### Services

- **orchestrator**: Main production service
- **orchestrator-dev**: Development service with hot reload
- **prometheus**: Metrics collection (optional)
- **grafana**: Metrics visualization (optional)
- **loki**: Log aggregation (optional)
- **promtail**: Log shipping (optional)

## 🚀 Quick Start

### Prerequisites

- Docker 20.10+ installed
- Docker Compose 1.29+ installed
- Make (optional, for convenience commands)

### First Time Setup

```bash
# Using Make (recommended)
make quick-start

# Or manually:
# 1. Create .env file
cp .env.example .env
# Edit .env and add your INFURA_URL

# 2. Build Docker image
docker-compose build

# 3. Start the container
docker-compose up -d

# 4. Check health
curl http://localhost:3000/healthz
```

## 📋 Common Commands

### Using Make (Recommended)

```bash
# Show all available commands
make help

# Build images
make build              # Build production image
make build-dev          # Build development image
make build-all          # Build all images

# Run containers
make up                 # Start production container
make dev                # Start development container
make down               # Stop containers

# Monitoring
make monitoring         # Start monitoring stack
make monitoring-down    # Stop monitoring stack

# Logs and debugging
make logs               # View container logs
make shell              # Open shell in container
make health             # Check health endpoint
make ready              # Check readiness endpoint

# Maintenance
make restart            # Restart containers
make clean              # Clean up Docker resources
make rebuild            # Complete rebuild
```

### Using Docker Compose Directly

```bash
# Build images
docker-compose build

# Start production
docker-compose up -d orchestrator

# Start development
docker-compose --profile dev up orchestrator-dev

# View logs
docker-compose logs -f orchestrator

# Stop containers
docker-compose down

# Stop and remove everything
docker-compose down -v
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file with:

```env
# Required
INFURA_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID

# Optional
PORT=3000
LOG_LEVEL=info
NODE_ENV=production

# Monitoring (optional)
GRAFANA_USER=admin
GRAFANA_PASSWORD=secure_password
```

### Docker Compose Profiles

- **Default**: Production orchestrator only
- **dev**: Development environment
- **monitoring**: Full monitoring stack

```bash
# Start with specific profile
docker-compose --profile monitoring up -d

# Start multiple profiles
docker-compose --profile dev --profile monitoring up -d
```

### Resource Limits

Production container has resource limits configured:
- CPU: 1 core limit, 0.5 core reservation
- Memory: 512MB limit, 256MB reservation

Adjust in `docker-compose.yml` if needed.

## 🛠️ Development Workflow

### Local Development with Docker

```bash
# Start development container
make dev

# Or with docker-compose
docker-compose --profile dev up orchestrator-dev

# The container will:
# - Mount source code for live changes
# - Enable hot reload
# - Show debug logs
# - Expose debugger port
```

### Making Code Changes

1. Edit files in `src/` directory
2. Changes auto-reload in development container
3. Check logs: `make logs-dev`
4. Test endpoints: `curl http://localhost:3001/healthz`

### Building for Production

```bash
# Build production image
make build

# Test production image locally
make up

# Verify health
make health
make ready
```

## 📊 Monitoring Stack

### Enable Monitoring

```bash
# Start monitoring services
make monitoring

# Access services:
# - Prometheus: http://localhost:9090
# - Grafana: http://localhost:3002 (admin/admin)
# - Loki: http://localhost:3100
```

### Available Metrics

The `/metrics` endpoint exposes:
- Heartbeat count
- Last heartbeat timestamp
- Memory usage (RSS, heap)
- CPU usage
- Custom application metrics

### Grafana Dashboards

Pre-configured dashboards for:
- Application health
- Resource usage
- Log analysis
- Ethereum connection status

## 🔒 Security Best Practices

1. **Non-root User**: Application runs as `nodejs` user (UID 1001)
2. **Minimal Base Image**: Alpine Linux for smaller attack surface
3. **Multi-stage Build**: Only production dependencies in final image
4. **Health Checks**: Automatic container restart on failure
5. **Signal Handling**: Proper shutdown with dumb-init
6. **Read-only Mounts**: Configuration files mounted as read-only

## 🧪 Testing

### Run Tests in Container

```bash
# Using Make
make test

# Using docker-compose
docker-compose exec orchestrator npm test

# Build and test
docker-compose run --rm orchestrator npm test
```

### Health Check Testing

```bash
# Liveness probe (should always return 200)
curl http://localhost:3000/healthz

# Readiness probe (returns 503 until ready)
curl http://localhost:3000/readyz

# Pretty print with jq
curl -s http://localhost:3000/healthz | jq '.'
```

## 📝 Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs orchestrator

# Validate configuration
docker-compose config

# Check .env file
cat .env

# Rebuild without cache
make build-no-cache
```

### Permission Issues

```bash
# Open root shell
make shell-root

# Fix permissions
docker-compose exec -u root orchestrator chown -R nodejs:nodejs /app
```

### High Memory Usage

```bash
# Check resource usage
make stats

# Adjust limits in docker-compose.yml
# Under deploy.resources.limits
```

### Network Issues

```bash
# List networks
docker network ls

# Inspect network
docker network inspect test-devops-orchestrators_orchestrator-network

# Recreate network
docker-compose down
docker-compose up -d
```

## 🚢 Production Deployment

### Building for Production

```bash
# Build production image
docker build --target production -t swap-optimizer:prod .

# Tag for registry
docker tag swap-optimizer:prod your-registry/swap-optimizer:v1.0.0

# Push to registry
docker push your-registry/swap-optimizer:v1.0.0
```

### Docker Compose in Production

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  orchestrator:
    image: your-registry/swap-optimizer:v1.0.0
    restart: always
    env_file:
      - .env.production
    volumes:
      - ./logs:/app/logs
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: swap-optimizer
spec:
  replicas: 3
  selector:
    matchLabels:
      app: swap-optimizer
  template:
    metadata:
      labels:
        app: swap-optimizer
    spec:
      containers:
      - name: orchestrator
        image: your-registry/swap-optimizer:v1.0.0
        ports:
        - containerPort: 3000
        livenessProbe:
          httpGet:
            path: /healthz
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /readyz
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          limits:
            memory: "512Mi"
            cpu: "1000m"
          requests:
            memory: "256Mi"
            cpu: "500m"
```

## 📊 Image Size Optimization

Current image sizes:
- Production: ~150MB (Alpine + Node.js + App)
- Development: ~250MB (includes dev tools)

Optimization techniques used:
- Multi-stage builds
- Alpine Linux base
- Production dependencies only
- No build tools in final image
- .dockerignore for build context

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: Docker Build and Push

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v1
      
      - name: Login to Registry
        uses: docker/login-action@v1
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Build and push
        uses: docker/build-push-action@v2
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Alpine Linux](https://alpinelinux.org/)
- [Node.js Docker Best Practices](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md)

## ✅ Checklist

- [x] Multi-stage Dockerfile
- [x] Docker Compose configuration
- [x] Development environment support
- [x] Production optimizations
- [x] Health checks implemented
- [x] Resource limits configured
- [x] Security best practices
- [x] Monitoring stack (optional)
- [x] Documentation complete
- [x] Make commands for convenience

The orchestrator is now fully containerized and ready for deployment! 🚀
