#!/bin/bash

# Container-friendly startup script for Swap Optimizer
# Exit on error and undefined variables
set -eu

# Configuration
LOG_DIR="/app/logs"
RUN_DIR="/app/run"
APP_NAME="Swap Optimizer"

# Create necessary directories
mkdir -p "$LOG_DIR" "$RUN_DIR"

# Simple logging function
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Print startup header
log_info "=================================================="
log_info "$APP_NAME Starting in Container"
log_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
log_info "User: $(whoami)"
log_info "Current Directory: $(pwd)"
log_info "Node.js Version: $(node -v 2>/dev/null || echo 'Not found')"
log_info "=================================================="

# Check if .env file exists
if [ ! -f .env ]; then
    log_error "Missing .env file"
    exit 1
fi

# Check if dist directory exists
if [ ! -d "dist" ]; then
    log_error "Build directory 'dist' not found"
    exit 1
fi

# Check if app.js exists
if [ ! -f "dist/app.js" ]; then
    log_error "dist/app.js not found"
    exit 1
fi

log_success "All prerequisites checked"

# Start the application
log_info "Starting $APP_NAME..."
log_info "Server will be accessible at: http://localhost:3000"
log_info "Health check endpoint: http://localhost:3000/healthz"

# Start the Node.js application
exec node dist/app.js
