#!/bin/bash

# Docker Quick Start Script for Swap Optimizer Orchestrator

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}   Swap Optimizer Orchestrator - Docker Setup  ${NC}"
    echo -e "${BLUE}================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    echo -e "\n${GREEN}Checking prerequisites...${NC}"
    
    # Check Docker
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        print_success "Docker installed (version: $DOCKER_VERSION)"
    else
        print_error "Docker is not installed"
        echo "Please install Docker from: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check Docker Compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        print_success "Docker Compose installed (version: $COMPOSE_VERSION)"
    else
        print_error "Docker Compose is not installed"
        echo "Please install Docker Compose from: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        print_success "Docker daemon is running"
    else
        print_error "Docker daemon is not running"
        echo "Please start Docker Desktop or Docker daemon"
        exit 1
    fi
}

# Setup environment
setup_environment() {
    echo -e "\n${GREEN}Setting up environment...${NC}"
    
    # Check for .env file
    if [ ! -f .env ]; then
        if [ -f .env_example ]; then
            cp .env_example .env
            print_success "Created .env file from .env_example"
            print_warning "Please update INFURA_URL in .env file with your actual Infura project URL"
            echo -e "${YELLOW}Edit .env file now? (y/n):${NC} "
            read -r response
            if [[ "$response" == "y" ]]; then
                ${EDITOR:-nano} .env
            fi
        else
            print_error "No .env_example file found"
            exit 1
        fi
    else
        print_success ".env file already exists"
    fi
    
    # Create necessary directories
    mkdir -p logs run monitoring/grafana/dashboards monitoring/grafana/datasources
    print_success "Created necessary directories"
}

# Build Docker images
build_images() {
    echo -e "\n${GREEN}Building Docker images...${NC}"
    
    echo "Select build option:"
    echo "1) Production only"
    echo "2) Development only"
    echo "3) Both (Production + Development)"
    echo "4) Skip build"
    read -p "Enter choice (1-4): " choice
    
    case $choice in
        1)
            print_info "Building production image..."
            docker-compose build orchestrator
            print_success "Production image built successfully"
            ;;
        2)
            print_info "Building development image..."
            docker-compose build orchestrator-dev
            print_success "Development image built successfully"
            ;;
        3)
            print_info "Building all images..."
            docker-compose build
            print_success "All images built successfully"
            ;;
        4)
            print_info "Skipping build"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Start containers
start_containers() {
    echo -e "\n${GREEN}Starting containers...${NC}"
    
    echo "Select run mode:"
    echo "1) Production"
    echo "2) Development"
    echo "3) Production with Monitoring"
    echo "4) Development with Monitoring"
    read -p "Enter choice (1-4): " choice
    
    case $choice in
        1)
            print_info "Starting production container..."
            docker-compose up -d orchestrator
            print_success "Production container started"
            PORTS="3000"
            ;;
        2)
            print_info "Starting development container..."
            docker-compose --profile dev up -d orchestrator-dev
            print_success "Development container started"
            PORTS="3001"
            ;;
        3)
            print_info "Starting production with monitoring..."
            docker-compose --profile monitoring up -d
            print_success "Production and monitoring containers started"
            PORTS="3000 9090 3002"
            ;;
        4)
            print_info "Starting development with monitoring..."
            docker-compose --profile dev --profile monitoring up -d
            print_success "Development and monitoring containers started"
            PORTS="3001 9090 3002"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Verify deployment
verify_deployment() {
    echo -e "\n${GREEN}Verifying deployment...${NC}"
    
    # Wait for container to be ready
    print_info "Waiting for application to be ready..."
    sleep 5
    
    # Check main application port
    if [[ $PORTS == *"3000"* ]]; then
        if curl -sf http://localhost:3000/healthz > /dev/null; then
            print_success "Production application is healthy"
        else
            print_warning "Production application health check failed"
        fi
    fi
    
    if [[ $PORTS == *"3001"* ]]; then
        if curl -sf http://localhost:3001/healthz > /dev/null; then
            print_success "Development application is healthy"
        else
            print_warning "Development application health check failed"
        fi
    fi
    
    # Show running containers
    echo -e "\n${GREEN}Running containers:${NC}"
    docker-compose ps
}

# Show access information
show_access_info() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${GREEN}Setup Complete!${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    echo -e "\n${GREEN}Access URLs:${NC}"
    
    if [[ $PORTS == *"3000"* ]]; then
        echo -e "  ${YELLOW}Application (Production):${NC} http://localhost:3000"
        echo -e "  ${YELLOW}Health Check:${NC} http://localhost:3000/healthz"
        echo -e "  ${YELLOW}Readiness Check:${NC} http://localhost:3000/readyz"
        echo -e "  ${YELLOW}Metrics:${NC} http://localhost:3000/metrics"
    fi
    
    if [[ $PORTS == *"3001"* ]]; then
        echo -e "  ${YELLOW}Application (Development):${NC} http://localhost:3001"
        echo -e "  ${YELLOW}Health Check:${NC} http://localhost:3001/healthz"
        echo -e "  ${YELLOW}Readiness Check:${NC} http://localhost:3001/readyz"
    fi
    
    if [[ $PORTS == *"9090"* ]]; then
        echo -e "  ${YELLOW}Prometheus:${NC} http://localhost:9090"
    fi
    
    if [[ $PORTS == *"3002"* ]]; then
        echo -e "  ${YELLOW}Grafana:${NC} http://localhost:3002 (admin/admin)"
    fi
    
    echo -e "\n${GREEN}Useful commands:${NC}"
    echo "  View logs:        docker-compose logs -f orchestrator"
    echo "  Stop containers:  docker-compose down"
    echo "  Open shell:       docker-compose exec orchestrator /bin/sh"
    echo "  View help:        make help"
    
    echo -e "\n${BLUE}Documentation:${NC}"
    echo "  See DOCKER_README.md for detailed documentation"
}

# Main execution
main() {
    print_header
    check_prerequisites
    setup_environment
    build_images
    start_containers
    verify_deployment
    show_access_info
}

# Run main function
main
