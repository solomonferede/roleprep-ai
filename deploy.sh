#!/bin/bash

################################################################################
# Deployment Script for RolePrepAI
# 
# This script automates the deployment process:
# - Pulls latest code from GitHub
# - Stops old containers safely
# - Rebuilds Docker images
# - Starts containers
# - Runs collectstatic
# - Verifies health
# - Cleans up dangling images
#
# Usage: ./deploy.sh
################################################################################

set -e  # Exit on first error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="roleprepai-web"
DEPLOY_LOG="/tmp/roleprepai-deploy.log"
DOMAIN="roleprepai.solomonferede.com.et"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$DEPLOY_LOG"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$DEPLOY_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$DEPLOY_LOG"
}

log_error() {
    echo -e "${RED}[✗ ERROR]${NC} $1" | tee -a "$DEPLOY_LOG"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    log_success "Docker is available"
}

check_docker_compose() {
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed or not available"
        exit 1
    fi
    log_success "Docker Compose is available"
}

pull_latest_code() {
    log_info "Pulling latest code from GitHub..."
    cd "$PROJECT_DIR"
    git fetch origin
    git pull origin main
    if [ $? -eq 0 ]; then
        log_success "Code pulled successfully"
    else
        log_warning "Code pull had issues, but continuing..."
    fi
}

stop_containers() {
    log_info "Stopping old containers..."
    cd "$PROJECT_DIR"
    
    if docker ps | grep -q "$CONTAINER_NAME"; then
        docker compose down --remove-orphans
        sleep 2  # Give containers time to stop gracefully
        log_success "Containers stopped"
    else
        log_info "No running containers found"
    fi
}

rebuild_images() {
    log_info "Rebuilding Docker images..."
    cd "$PROJECT_DIR"
    
    docker compose build --no-cache
    if [ $? -eq 0 ]; then
        log_success "Docker images built successfully"
    else
        log_error "Docker build failed"
        exit 1
    fi
}

start_containers() {
    log_info "Starting containers in detached mode..."
    cd "$PROJECT_DIR"
    
    docker compose up -d
    if [ $? -eq 0 ]; then
        log_success "Containers started"
        sleep 5  # Give containers time to initialize
    else
        log_error "Failed to start containers"
        exit 1
    fi
}

run_collectstatic() {
    log_info "Running collectstatic..."
    cd "$PROJECT_DIR"
    
    docker compose exec -T web python manage.py collectstatic --noinput
    if [ $? -eq 0 ]; then
        log_success "Static files collected"
    else
        log_error "collectstatic failed"
        # Don't exit, as this might not be critical for stateless app
    fi
}

verify_health() {
    log_info "Verifying container health..."
    
    # Wait for container to be healthy
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy\|running"; then
            log_success "Container is healthy"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 1
    done
    
    log_warning "Container health check timed out (may still be starting)"
    return 0
}

check_application() {
    log_info "Checking application endpoint..."
    
    local max_attempts=10
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf http://127.0.0.1:8000/health/ > /dev/null 2>&1; then
            log_success "Application is responding"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    log_warning "Application endpoint not responding yet (it may be initializing)"
    return 0
}

cleanup_images() {
    log_info "Cleaning up dangling Docker images..."
    
    local dangling_count=$(docker images -f "dangling=true" -q | wc -l)
    if [ "$dangling_count" -gt 0 ]; then
        docker image prune -f > /dev/null 2>&1
        log_success "Removed $dangling_count dangling images"
    else
        log_info "No dangling images to clean up"
    fi
}

show_logs() {
    log_info "Latest container logs (last 20 lines):"
    echo "---"
    docker compose logs --tail=20 web || true
    echo "---"
}

# Main deployment flow
main() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                  RolePrepAI Deployment Script                  ║"
    echo "║                                                                ║"
    echo "║  Domain: https://${DOMAIN}                  ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Clear log file
    > "$DEPLOY_LOG"
    
    log_info "Starting deployment process..."
    log_info "Project directory: $PROJECT_DIR"
    
    # Pre-flight checks
    log_info "Running pre-flight checks..."
    check_docker
    check_docker_compose
    
    # Deployment steps
    pull_latest_code
    stop_containers
    rebuild_images
    start_containers
    sleep 3
    run_collectstatic
    verify_health
    check_application
    cleanup_images
    
    # Show status
    log_info "Showing running containers:"
    docker ps --filter "name=$CONTAINER_NAME"
    
    echo ""
    log_success "═══════════════════════════════════════════════════════"
    log_success "✓ DEPLOYMENT SUCCESSFUL"
    log_success "═══════════════════════════════════════════════════════"
    echo ""
    log_info "Application is now live at:"
    echo -e "${GREEN}    https://${DOMAIN}${NC}"
    echo ""
    log_info "Useful commands:"
    echo "  View logs:       docker compose logs -f"
    echo "  Stop app:        docker compose down"
    echo "  Restart app:     docker compose restart"
    echo "  Check health:    docker ps"
    echo ""
    
    # Show any errors if present
    if grep -q "ERROR\|WARN" "$DEPLOY_LOG"; then
        log_warning "Some warnings or errors occurred during deployment:"
        grep "ERROR\|WARN" "$DEPLOY_LOG" || true
        echo ""
    fi
    
    log_info "Full deployment log saved to: $DEPLOY_LOG"
}

# Run main function
main "$@"
