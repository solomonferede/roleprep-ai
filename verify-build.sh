#!/bin/bash

################################################################################
# Docker Build and Deployment Verification Script
#
# Tests the Docker build locally before deploying to production.
# Useful for catching configuration issues early.
#
# Usage: ./verify-build.sh
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║           RolePrepAI Docker Build Verification                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Check prerequisites
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    log_success "Docker found"
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    log_success "Docker Compose found"
    
    # Check required files
    log_info "Checking required files..."
    
    required_files=(
        "Dockerfile"
        "docker-compose.yml"
        ".env.example"
        "requirements.txt"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$PROJECT_DIR/$file" ]; then
            log_error "Missing file: $file"
            exit 1
        fi
        log_success "Found: $file"
    done
    
    # Check .env file
    log_info "Checking environment configuration..."
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log_warning ".env file not found"
        log_info "Creating .env from .env.example..."
        cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
        log_warning "Please edit .env and add actual values"
    else
        log_success ".env file exists"
    fi
    
    # Build Docker image
    log_info "Building Docker image (this may take a minute)..."
    cd "$PROJECT_DIR"
    
    if docker compose build; then
        log_success "Docker image built successfully"
    else
        log_error "Docker build failed"
        exit 1
    fi
    
    # Get image info
    log_info "Image details:"
    docker image inspect roleprepai-web 2>/dev/null | grep -E '"Id"|"Size"' | head -2
    
    # Start containers for testing
    log_info "Starting containers for verification..."
    if docker compose up -d; then
        log_success "Containers started"
        sleep 5
    else
        log_error "Failed to start containers"
        exit 1
    fi
    
    # Check container status
    log_info "Checking container status..."
    if docker ps | grep -q "roleprepai-web"; then
        log_success "Container is running"
    else
        log_error "Container is not running"
        docker compose logs web
        exit 1
    fi
    
    # Test health endpoint
    log_info "Testing health endpoint..."
    if curl -sf http://127.0.0.1:8000/health/ > /dev/null 2>&1; then
        log_success "Health endpoint is responding"
        curl -s http://127.0.0.1:8000/health/ | python3 -m json.tool
    else
        log_warning "Health endpoint not responding yet (container may still be starting)"
        log_info "Waiting 10 more seconds..."
        sleep 10
        
        if curl -sf http://127.0.0.1:8000/health/ > /dev/null 2>&1; then
            log_success "Health endpoint is responding"
        else
            log_warning "Health endpoint still not responding"
            log_info "Container logs:"
            docker compose logs --tail=20 web
        fi
    fi
    
    # Check static files
    log_info "Checking static files..."
    if [ -d "$PROJECT_DIR/staticfiles" ] && [ "$(ls -A $PROJECT_DIR/staticfiles)" ]; then
        log_success "Static files collected"
        file_count=$(find "$PROJECT_DIR/staticfiles" -type f | wc -l)
        log_info "Total static files: $file_count"
    else
        log_warning "Static files directory is empty"
    fi
    
    # Show running containers
    log_info "Running containers:"
    docker compose ps
    
    # Show logs
    log_info "Recent container logs:"
    docker compose logs --tail=10 web | head -20
    
    # Cleanup
    log_info "Cleaning up test containers..."
    docker compose down
    log_success "Test containers stopped"
    
    echo ""
    log_success "═══════════════════════════════════════════════════════"
    log_success "✓ BUILD VERIFICATION SUCCESSFUL"
    log_success "═══════════════════════════════════════════════════════"
    echo ""
    log_info "Your Docker image is ready for deployment!"
    echo ""
    echo "Next steps:"
    echo "  1. Configure .env with your actual values"
    echo "  2. Push code to GitHub"
    echo "  3. Deploy to VPS: ./deploy.sh"
    echo ""
}

main "$@"
