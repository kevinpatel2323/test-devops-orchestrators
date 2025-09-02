#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Configuration
REPO_URL="https://github.com/veltrix-capital/test-devops-orchestrators.git"
REPO_DIR="test-devops-orchestrators"
LOG_DIR="logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
INSTALL_LOG="$LOG_DIR/install_${TIMESTAMP}.log"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Create logs directory
mkdir -p "$LOG_DIR"

# Redirect all output to log file while preserving terminal output
exec > >(tee -a "$INSTALL_LOG")
exec 2> >(tee -a "$INSTALL_LOG" >&2)

# Print installation header
log_info "=================================================="
log_info "Installation Script Started"
log_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
log_info "User: $(whoami)"
log_info "System: $(uname -s) $(uname -r)"
log_info "Log file: $INSTALL_LOG"
log_info "=================================================="

# Function to check command existence
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install git on macOS
install_git_macos() {
    log_info "Attempting to install Git on macOS..."
    
    if ! command_exists brew; then
        log_warning "Homebrew not found. Installing Homebrew first..."
        if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            log_info "Homebrew installed successfully"
            # Add Homebrew to PATH for current session
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -f "/usr/local/bin/brew" ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        else
            log_error "Failed to install Homebrew"
            return 1
        fi
    fi
    
    if brew install git; then
        log_info "Git installed successfully via Homebrew"
        return 0
    else
        log_error "Failed to install Git via Homebrew"
        return 1
    fi
}

# Pre-flight check: Verify Git is installed
log_info "Checking for Git installation..."
if ! command_exists git; then
    log_warning "Git is not installed"
    
    # Detect OS and attempt auto-installation
    OS="$(uname -s)"
    case "$OS" in
        Darwin*)
            if install_git_macos; then
                # Verify Git is now available
                if ! command_exists git; then
                    log_error "Git installation succeeded but git command not found. Please restart terminal."
                    exit 1
                fi
            else
                log_error "Failed to install Git. Please install manually."
                exit 1
            fi
            ;;
        Linux*)
            log_error "Git is not installed. Please install using your package manager:"
            log_error "  Ubuntu/Debian: sudo apt-get install git"
            log_error "  Fedora/RHEL: sudo dnf install git"
            log_error "  Arch: sudo pacman -S git"
            exit 1
            ;;
        *)
            log_error "Git is not installed. Please install Git manually for your OS: $OS"
            exit 1
            ;;
    esac
fi

GIT_VERSION=$(git --version | awk '{print $3}')
log_info "Git is installed (version: $GIT_VERSION)"

# Step 1: Clone or update the repository
log_info "Setting up repository..."
if [ -d "$REPO_DIR/.git" ]; then
    log_info "Repository already exists. Pulling latest changes..."
    if cd "$REPO_DIR"; then
        # Store current branch
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        log_info "Current branch: $CURRENT_BRANCH"
        
        # Check for uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            log_warning "Uncommitted changes detected. Stashing..."
            git stash push -m "Auto-stash by install script at $(date)"
        fi
        
        # Pull latest changes
        if git pull --rebase; then
            log_info "Successfully pulled latest changes"
        else
            log_error "Failed to pull latest changes. Attempting to recover..."
            git rebase --abort 2>/dev/null || true
            if ! git pull; then
                log_error "Failed to update repository"
                exit 1
            fi
        fi
    else
        log_error "Failed to enter directory: $REPO_DIR"
        exit 1
    fi
else
    log_info "Cloning repository from $REPO_URL..."
    if git clone "$REPO_URL" "$REPO_DIR"; then
        log_info "Repository cloned successfully"
        if ! cd "$REPO_DIR"; then
            log_error "Failed to enter cloned directory: $REPO_DIR"
            exit 1
        fi
    else
        log_error "Failed to clone repository"
        exit 1
    fi
fi

# Step 2: Make scripts executable
log_info "Setting executable permissions on scripts..."
SCRIPTS=("setup.sh" "start.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if chmod +x "$script"; then
            log_info "  ✓ $script is now executable"
        else
            log_error "Failed to set executable permission on $script"
            exit 1
        fi
    else
        log_error "Script not found: $script"
        exit 1
    fi
done

# Step 3: Run setup.sh
log_info "Running setup.sh..."
log_info "--------------------------------------------------"

if [ -f "./setup.sh" ]; then
    if ./setup.sh; then
        log_info "--------------------------------------------------"
        log_info "Setup completed successfully"
    else
        EXIT_CODE=$?
        log_error "--------------------------------------------------"
        log_error "setup.sh failed with exit code: $EXIT_CODE"
        exit $EXIT_CODE
    fi
else
    log_error "setup.sh not found in current directory"
    exit 1
fi

# Final summary
log_info "=================================================="
log_info "Installation completed successfully!"
log_info "Total execution time: $SECONDS seconds"
log_info "Log saved to: $INSTALL_LOG"
log_info "=================================================="

exit 0



