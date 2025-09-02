#!/bin/bash

# Exit on error and undefined variables
set -eu

# Configuration
LOG_DIR="logs"
RUN_DIR="run"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_LOG="$LOG_DIR/run_${TIMESTAMP}.log"
PID_FILE="$RUN_DIR/app.pid"
LOCK_FILE="$RUN_DIR/app.lock"
APP_NAME="Swap Optimizer"
SIMULATE_CRASH=${SIMULATE_CRASH:-false}  # Set to true to enable crash simulation
CRASH_DELAY=${CRASH_DELAY:-300}  # Seconds before simulated crash (default 5 minutes)

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_status() {
    echo -e "${MAGENTA}[STATUS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_info "Application shutdown gracefully"
    else
        log_error "Application terminated with exit code: $exit_code"
    fi
    
    # Remove PID and lock files
    if [ -f "$PID_FILE" ]; then
        rm -f "$PID_FILE"
        log_info "Removed PID file"
    fi
    
    if [ -f "$LOCK_FILE" ]; then
        rm -f "$LOCK_FILE"
        log_info "Removed lock file"
    fi
    
    log_info "=================================================="
    log_info "Application stopped at $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log saved to: $RUN_LOG"
    log_info "=================================================="
    
    exit $exit_code
}

# Set up trap for cleanup on exit
trap cleanup EXIT INT TERM

# Create necessary directories
mkdir -p "$LOG_DIR" "$RUN_DIR"

# Redirect all output to log file while preserving terminal output
exec > >(tee -a "$RUN_LOG")
exec 2> >(tee -a "$RUN_LOG" >&2)

# Print startup header
log_info "=================================================="
log_info "$APP_NAME Starting"
log_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
log_info "User: $(whoami)"
log_info "System: $(uname -s) $(uname -r)"
log_info "Current Directory: $(pwd)"
log_info "Node.js Version: $(node -v 2>/dev/null || echo 'Not found')"
log_info "npm Version: $(npm -v 2>/dev/null || echo 'Not found')"
log_info "Log file: $RUN_LOG"
log_info "PID file: $PID_FILE"
log_info "=================================================="

# Function to check if process is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            log_warning "Stale PID file found (PID: $pid no longer exists)"
            rm -f "$PID_FILE" "$LOCK_FILE"
            return 1
        fi
    fi
    return 1
}

# Check for lock file (prevent double-starts)
if [ -f "$LOCK_FILE" ]; then
    log_error "Lock file exists at $LOCK_FILE"
    
    if is_running; then
        PID=$(cat "$PID_FILE")
        log_error "Application is already running (PID: $PID)"
        log_error "To stop it, run: kill $PID"
        log_error "To force restart, remove lock file: rm $LOCK_FILE $PID_FILE"
        exit 1
    else
        log_warning "Removing stale lock file"
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file
touch "$LOCK_FILE"
log_info "Lock file created"

# Pre-flight checks
log_info "Performing pre-flight checks..."

# Check Node.js
if ! command -v node >/dev/null 2>&1; then
    log_error "Node.js is not installed or not in PATH"
    exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//')
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 18 ]; then
    log_error "Node.js version $NODE_VERSION is too old (minimum required: 18)"
    exit 1
fi
log_success "Node.js version check passed (v$NODE_VERSION)"

# Check npm
if ! command -v npm >/dev/null 2>&1; then
    log_error "npm is not installed or not in PATH"
    exit 1
fi
log_success "npm is available (v$(npm -v))"

# Check .env file
if [ ! -f .env ]; then
    log_error "Missing .env file. Please run setup.sh first."
    exit 1
fi
log_success ".env file exists"

# Validate .env has required variables
if ! grep -q "^INFURA_URL=" .env; then
    log_error "INFURA_URL not found in .env file"
    exit 1
fi

INFURA_VALUE=$(grep "^INFURA_URL=" .env | cut -d'=' -f2-)
if [ -z "$INFURA_VALUE" ] || [ "$INFURA_VALUE" = "YOUR_INFURA_URL" ]; then
    log_error "INFURA_URL is not properly configured in .env"
    log_error "Please update your INFURA_URL with a valid value"
    exit 1
fi
log_success "Environment configuration validated"

# Check if dist directory exists (TypeScript build)
if [ ! -d "dist" ]; then
    log_warning "Build directory 'dist' not found. Building application..."
    if npm run build; then
        log_success "Application built successfully"
    else
        log_error "Failed to build application"
        exit 1
    fi
else
    log_info "Build directory exists. Rebuilding to ensure latest changes..."
    if npm run build; then
        log_success "Application rebuilt successfully"
    else
        log_error "Failed to rebuild application"
        exit 1
    fi
fi

# Function to monitor application
monitor_app() {
    local app_pid=$1
    local start_time=$(date +%s)
    
    while kill -0 "$app_pid" 2>/dev/null; do
        sleep 5
        
        # Check if health endpoint is responding
        if command -v curl >/dev/null 2>&1; then
            if curl -sf "http://localhost:3000/healthz" >/dev/null 2>&1; then
                log_status "Health check passed"
            else
                log_warning "Health check failed or not available yet"
            fi
        fi
        
        # Log uptime
        local current_time=$(date +%s)
        local uptime=$((current_time - start_time))
        local hours=$((uptime / 3600))
        local minutes=$(((uptime % 3600) / 60))
        local seconds=$((uptime % 60))
        log_status "Application uptime: ${hours}h ${minutes}m ${seconds}s"
    done
    
    log_error "Application process terminated unexpectedly"
    return 1
}

# Start the application
log_info "Starting $APP_NAME..."
log_info "--------------------------------------------------"

# Start the Node.js application in background
npm start &
APP_PID=$!

# Save PID to file
echo $APP_PID > "$PID_FILE"
log_success "Application started with PID: $APP_PID"

# Optional: Simulate crash for testing
if [ "$SIMULATE_CRASH" = "true" ]; then
    log_warning "CRASH SIMULATION ENABLED - Application will be terminated after $CRASH_DELAY seconds"
    (
        sleep "$CRASH_DELAY"
        log_error "[CRASH SIMULATION] Terminating application for testing..."
        kill -TERM "$APP_PID" 2>/dev/null || true
    ) &
    CRASH_SIM_PID=$!
fi

# Wait for application to be ready
log_info "Waiting for application to be ready..."
sleep 3

# Check if application is still running
if ! kill -0 "$APP_PID" 2>/dev/null; then
    log_error "Application failed to start or crashed immediately"
    wait $APP_PID
    EXIT_CODE=$?
    log_error "Application exit code: $EXIT_CODE"
    exit $EXIT_CODE
fi

log_success "Application is running"
log_info "--------------------------------------------------"
log_info "Server should be accessible at: http://localhost:3000"
log_info "Health check endpoint: http://localhost:3000/healthz"
log_info "Readiness check endpoint: http://localhost:3000/readyz"
log_info "--------------------------------------------------"
log_info "Press Ctrl+C to stop the application"
log_info "--------------------------------------------------"

# Monitor the application
if [ "$SIMULATE_CRASH" = "true" ]; then
    # Wait for either the app or the crash simulator
    wait $APP_PID
    APP_EXIT_CODE=$?
    
    # Kill crash simulator if still running
    kill $CRASH_SIM_PID 2>/dev/null || true
else
    # Normal monitoring
    monitor_app $APP_PID &
    MONITOR_PID=$!
    
    # Wait for the application
    wait $APP_PID
    APP_EXIT_CODE=$?
    
    # Kill monitor if still running
    kill $MONITOR_PID 2>/dev/null || true
fi

# Check exit code
if [ $APP_EXIT_CODE -ne 0 ]; then
    log_error "Application terminated abnormally with exit code: $APP_EXIT_CODE"
    exit $APP_EXIT_CODE
fi

log_success "Application terminated normally"
exit 0
