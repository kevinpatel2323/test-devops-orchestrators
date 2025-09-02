#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Configuration
LOG_DIR="logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SETUP_LOG="$LOG_DIR/setup_${TIMESTAMP}.log"
REQUIRED_NODE_VERSION=18

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Create logs directory
mkdir -p "$LOG_DIR"

# Redirect all output to log file while preserving terminal output
exec > >(tee -a "$SETUP_LOG")
exec 2> >(tee -a "$SETUP_LOG" >&2)

# Print setup header
log_info "=================================================="
log_info "Swap Optimizer Setup Script Started"
log_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
log_info "User: $(whoami)"
log_info "System: $(uname -s) $(uname -r)"
log_info "Current Directory: $(pwd)"
log_info "Log file: $SETUP_LOG"
log_info "=================================================="

# Detect Operating System
OS="$(uname -s)"
log_info "Detected OS: $OS"

# Function to check command existence
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to compare version numbers
version_ge() {
    # Returns 0 if $1 >= $2
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# Function to check Node.js version
check_node_version() {
    if command_exists node; then
        NODE_VERSION=$(node -v | sed 's/v//')
        NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
        
        log_info "Node.js version detected: v$NODE_VERSION"
        
        if [ "$NODE_MAJOR" -ge "$REQUIRED_NODE_VERSION" ]; then
            log_success "Node.js version meets requirement (v$NODE_VERSION >= v$REQUIRED_NODE_VERSION)"
            return 0
        else
            log_error "Node.js version is too old (v$NODE_VERSION < v$REQUIRED_NODE_VERSION)"
            return 1
        fi
    else
        log_error "Node.js is not installed"
        return 1
    fi
}

# Function to install Node.js
install_node() {
    log_info "Attempting to install Node.js v$REQUIRED_NODE_VERSION+..."
    
    case "$OS" in
        Linux*)
            if [ -f /etc/debian_version ]; then
                log_info "Detected Debian/Ubuntu system"
                log_info "Installing Node.js via NodeSource repository..."
                if curl -fsSL https://deb.nodesource.com/setup_${REQUIRED_NODE_VERSION}.x | sudo -E bash -; then
                    if sudo apt-get install -y nodejs; then
                        log_success "Node.js installed successfully"
                        return 0
                    fi
                fi
            elif [ -f /etc/redhat-release ]; then
                log_info "Detected RHEL/CentOS/Fedora system"
                log_info "Installing Node.js via NodeSource repository..."
                if curl -fsSL https://rpm.nodesource.com/setup_${REQUIRED_NODE_VERSION}.x | sudo bash -; then
                    if sudo yum install -y nodejs || sudo dnf install -y nodejs; then
                        log_success "Node.js installed successfully"
                        return 0
                    fi
                fi
            elif [ -f /etc/arch-release ]; then
                log_info "Detected Arch Linux system"
                if sudo pacman -S --noconfirm nodejs npm; then
                    log_success "Node.js installed successfully"
                    return 0
                fi
            else
                log_error "Unsupported Linux distribution. Please install Node.js v$REQUIRED_NODE_VERSION+ manually."
                log_error "Visit: https://nodejs.org/en/download/"
                return 1
            fi
            ;;
        Darwin*)
            if command_exists brew; then
                log_info "Installing Node.js via Homebrew..."
                if brew install node@${REQUIRED_NODE_VERSION}; then
                    brew link --overwrite node@${REQUIRED_NODE_VERSION} 2>/dev/null || true
                    log_success "Node.js installed successfully"
                    return 0
                else
                    log_warning "Failed to install specific version, trying latest Node.js..."
                    if brew install node; then
                        log_success "Node.js installed successfully"
                        return 0
                    fi
                fi
            else
                log_error "Homebrew not found. Please install Node.js v$REQUIRED_NODE_VERSION+ manually."
                log_error "Visit: https://nodejs.org/en/download/"
                return 1
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            log_error "Windows detected. Please install Node.js v$REQUIRED_NODE_VERSION+ manually."
            log_error "Visit: https://nodejs.org/en/download/"
            return 1
            ;;
        *)
            log_error "Unknown operating system: $OS"
            log_error "Please install Node.js v$REQUIRED_NODE_VERSION+ manually."
            log_error "Visit: https://nodejs.org/en/download/"
            return 1
            ;;
    esac
    
    log_error "Failed to install Node.js"
    return 1
}

# Pre-flight requirement: Check Node.js version
log_info "Checking Node.js installation..."

if ! check_node_version; then
    log_warning "Node.js requirement not met. Attempting installation..."
    
    if install_node; then
        # Re-check after installation
        if ! check_node_version; then
            log_error "Node.js installation succeeded but version check still fails"
            log_error "You may need to restart your terminal or add Node.js to PATH"
            exit 1
        fi
    else
        log_error "Failed to install Node.js. Please install manually and re-run this script."
        exit 1
    fi
fi

# Check npm
log_info "Checking npm installation..."
if command_exists npm; then
    NPM_VERSION=$(npm -v)
    log_info "npm version: $NPM_VERSION"
else
    log_error "npm is not installed or not in PATH"
    exit 1
fi

# Check if package.json exists
if [ ! -f package.json ]; then
    log_error "package.json not found in current directory"
    log_error "Please run this script from the project root directory"
    exit 1
fi

# Install dependencies
log_info "Installing Node.js dependencies..."
log_info "Running: npm install"

if npm install; then
    log_success "Dependencies installed successfully"
else
    EXIT_CODE=$?
    log_error "Failed to install dependencies (exit code: $EXIT_CODE)"
    log_error "Please check the error messages above and fix any issues"
    exit $EXIT_CODE
fi

# Check and prepare .env file
log_info "Checking environment configuration..."

if [ ! -f .env ]; then
    if [ -f .env_example ]; then
        log_warning ".env file not found. Creating from .env_example..."
        if cp .env_example .env; then
            log_success "Created .env file from .env_example"
            log_warning "IMPORTANT: Please update your INFURA_URL in .env before starting the application"
            log_warning "Edit .env and replace the placeholder with your actual Infura project URL"
        else
            log_error "Failed to create .env file"
            exit 1
        fi
    else
        log_error "Neither .env nor .env_example found"
        log_error "Please create a .env file with the required configuration"
        log_error "Required environment variables:"
        log_error "  - INFURA_URL: Your Infura project URL"
        log_error "  - port: Server port (optional, defaults to 3000)"
        exit 1
    fi
else
    log_success ".env file exists"
    
    # Check if INFURA_URL is set
    if grep -q "^INFURA_URL=" .env; then
        INFURA_VALUE=$(grep "^INFURA_URL=" .env | cut -d'=' -f2-)
        if [ -z "$INFURA_VALUE" ] || [ "$INFURA_VALUE" = "YOUR_INFURA_URL" ]; then
            log_warning "INFURA_URL appears to be unset or using placeholder value"
            log_warning "Please update your INFURA_URL in .env before starting the application"
        else
            log_success "INFURA_URL is configured"
        fi
    else
        log_warning "INFURA_URL not found in .env file"
        log_warning "Please add INFURA_URL to your .env file"
    fi
fi

# Build TypeScript if needed
if [ -f tsconfig.json ]; then
    log_info "TypeScript configuration detected. Building project..."
    if npm run build; then
        log_success "Project built successfully"
    else
        log_warning "Build failed, but continuing setup"
    fi
fi

# Final summary
log_info "=================================================="
log_success "Setup completed successfully!"
log_info "Node.js version: $(node -v)"
log_info "npm version: $(npm -v)"
log_info "Total execution time: $SECONDS seconds"
log_info "Log saved to: $SETUP_LOG"
log_info "--------------------------------------------------"
log_info "Next steps:"
log_info "  1. Ensure your .env file is properly configured"
log_info "  2. Run './start.sh' to start the application"
log_info "  3. Or run 'npm run dev' for development mode"
log_info "=================================================="

exit 0
