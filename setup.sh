#!/bin/bash

################################################################################
# Initial VPS Setup Script for RolePrepAI
#
# This script sets up a VPS for the first time:
# - Installs Docker if not present
# - Installs Docker Compose plugin if not present
# - Creates required directories
# - Sets correct permissions
# - Enables and tests Nginx configuration
# - Reloads Nginx
#
# Usage: ./setup.sh
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
NGINX_CONFIG_FILE="$PROJECT_DIR/nginx/roleprepai.conf"
NGINX_AVAILABLE_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
NGINX_CONFIG_NAME="roleprepai.conf"
NGINX_CONFIG_DEST="$NGINX_AVAILABLE_DIR/$NGINX_CONFIG_NAME"
DOMAIN="roleprepai.solomonferede.com.et"
SETUP_LOG="$PROJECT_DIR/logs/setup.log"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$SETUP_LOG"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$SETUP_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$SETUP_LOG"
}

log_error() {
    echo -e "${RED}[✗ ERROR]${NC} $1" | tee -a "$SETUP_LOG"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root. Use: sudo ./setup.sh"
        exit 1
    fi
    log_success "Running as root"
}

# Check Ubuntu version
check_ubuntu() {
    if ! grep -qi "ubuntu" /etc/os-release; then
        log_warning "This system doesn't appear to be Ubuntu. Some commands may not work."
    else
        log_success "Running on Ubuntu"
    fi
}

# Install Docker if not present
install_docker() {
    if command -v docker &> /dev/null; then
        log_success "Docker is already installed"
        docker --version
        return 0
    fi
    
    log_info "Installing Docker..."
    
    # Update package manager
    apt-get update
    
    # Install dependencies
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start Docker service
    systemctl start docker
    systemctl enable docker
    
    log_success "Docker installed successfully"
    docker --version
}

# Install Docker Compose if not present
install_docker_compose() {
    if docker compose version &> /dev/null; then
        log_success "Docker Compose is already installed"
        docker compose version
        return 0
    fi
    
    log_info "Installing Docker Compose plugin..."
    apt-get update
    apt-get install -y docker-compose-plugin
    
    log_success "Docker Compose installed successfully"
    docker compose version
}

# Install Nginx if not present
install_nginx() {
    if command -v nginx &> /dev/null; then
        log_success "Nginx is already installed"
        nginx -v
        return 0
    fi
    
    log_info "Installing Nginx..."
    apt-get update
    apt-get install -y nginx
    
    # Enable and start Nginx
    systemctl start nginx
    systemctl enable nginx
    
    log_success "Nginx installed and started"
    nginx -v
}

# Install Certbot for SSL
install_certbot() {
    if command -v certbot &> /dev/null; then
        log_success "Certbot is already installed"
        certbot --version
        return 0
    fi
    
    log_info "Installing Certbot for Let's Encrypt SSL..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
    
    log_success "Certbot installed successfully"
    certbot --version
}

# Create required directories
create_directories() {
    log_info "Creating required directories..."
    
    # Create logs directory
    mkdir -p "$PROJECT_DIR/logs"
    log_success "Created logs directory"
    
    # Create staticfiles directory
    mkdir -p "$PROJECT_DIR/staticfiles"
    log_success "Created staticfiles directory"
    
    # Create nginx directory if doesn't exist
    mkdir -p "$PROJECT_DIR/nginx"
    log_success "Ensured nginx directory exists"
}

# Set permissions
set_permissions() {
    log_info "Setting correct permissions..."
    
    # Allow all users to read/write logs and staticfiles
    chmod 755 "$PROJECT_DIR/logs"
    chmod 755 "$PROJECT_DIR/staticfiles"
    
    log_success "Permissions set correctly"
}

# Copy Nginx configuration
copy_nginx_config() {
    log_info "Setting up Nginx configuration..."
    
    if [ ! -f "$NGINX_CONFIG_FILE" ]; then
        log_error "Nginx config file not found at: $NGINX_CONFIG_FILE"
        log_info "Please ensure nginx/roleprepai.conf exists in your project"
        return 1
    fi
    
    # Check if config already exists
    if [ -f "$NGINX_CONFIG_DEST" ]; then
        log_warning "Nginx config already exists at $NGINX_CONFIG_DEST"
        log_info "Backing up existing config to ${NGINX_CONFIG_DEST}.backup"
        cp "$NGINX_CONFIG_DEST" "${NGINX_CONFIG_DEST}.backup"
    fi
    
    # Copy config
    cp "$NGINX_CONFIG_FILE" "$NGINX_CONFIG_DEST"
    chmod 644 "$NGINX_CONFIG_DEST"
    log_success "Nginx config copied to $NGINX_CONFIG_DEST"
}

# Test Nginx configuration
test_nginx_config() {
    log_info "Testing Nginx configuration..."
    
    if nginx -t 2>&1; then
        log_success "Nginx configuration is valid"
        return 0
    else
        log_error "Nginx configuration has errors"
        return 1
    fi
}

# Enable Nginx site
enable_nginx_site() {
    log_info "Enabling Nginx site..."
    
    # Create symlink if not exists
    if [ ! -L "$NGINX_ENABLED_DIR/$NGINX_CONFIG_NAME" ]; then
        ln -s "$NGINX_CONFIG_DEST" "$NGINX_ENABLED_DIR/$NGINX_CONFIG_NAME"
        log_success "Nginx site symlinked to sites-enabled"
    else
        log_info "Nginx site already symlinked"
    fi
}

# Reload Nginx
reload_nginx() {
    log_info "Reloading Nginx..."
    
    nginx -t || {
        log_error "Nginx configuration test failed before reload"
        return 1
    }
    
    systemctl reload nginx
    log_success "Nginx reloaded successfully"
}

# Verify Nginx status
verify_nginx() {
    log_info "Verifying Nginx status..."
    
    if systemctl is-active --quiet nginx; then
        log_success "Nginx is running"
        systemctl status nginx | grep -E "(Active|Loaded)" | sed 's/^/    /'
        return 0
    else
        log_error "Nginx is not running"
        return 1
    fi
}

# Show next steps
show_next_steps() {
    echo ""
    log_success "═══════════════════════════════════════════════════════"
    log_success "✓ INITIAL VPS SETUP COMPLETED"
    log_success "═══════════════════════════════════════════════════════"
    echo ""
    
    log_info "Next steps to complete deployment:"
    echo ""
    echo "  1. Update .env file with actual values:"
    echo "     cd $PROJECT_DIR"
    echo "     cp .env.example .env"
    echo "     nano .env  # Edit with your values"
    echo ""
    echo "  2. Set up SSL certificate with Certbot:"
    echo "     sudo certbot --nginx -d roleprepai.solomonferede.com.et"
    echo "     Email: ezezsolomonferede@gmail.com"
    echo ""
    echo "  3. Make deploy script executable and run it:"
    echo "     chmod +x $PROJECT_DIR/deploy.sh"
    echo "     cd $PROJECT_DIR && ./deploy.sh"
    echo ""
    echo "  4. Verify the application is running:"
    echo "     docker compose ps"
    echo "     docker compose logs -f"
    echo ""
    log_info "Full setup log saved to: $SETUP_LOG"
}

# Main setup flow
main() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              RolePrepAI Initial VPS Setup Script               ║"
    echo "║                    (First-time setup only)                     ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Create logs directory if it doesn't exist (BEFORE writing to log)
    mkdir -p "$PROJECT_DIR/logs"
    
    # Clear log file
    > "$SETUP_LOG"
    
    log_info "Starting VPS setup process..."
    log_info "Project directory: $PROJECT_DIR"
    
    # Pre-flight checks
    check_root
    check_ubuntu
    
    # Install dependencies
    install_docker
    install_docker_compose
    install_nginx
    install_certbot
    
    # Create directories and set permissions
    create_directories
    set_permissions
    
    # Setup Nginx
    copy_nginx_config
    if ! test_nginx_config; then
        log_error "Nginx configuration has errors. Please fix them before proceeding."
        exit 1
    fi
    enable_nginx_site

    # If Let's Encrypt certificates are present for the domain, test and reload Nginx.
    CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
    if [ -f "$CERT_DIR/fullchain.pem" ] && [ -f "$CERT_DIR/privkey.pem" ]; then
        log_info "SSL certificates found in $CERT_DIR — testing and reloading Nginx."
        if ! reload_nginx; then
            log_warning "Nginx reload failed even though certs exist — please inspect /var/log/nginx/"
        else
            verify_nginx
        fi
    else
        log_warning "No SSL certificates found at $CERT_DIR — skipping Nginx reload to avoid failures."
        log_info "Run: sudo certbot --nginx -d ${DOMAIN} (email: ezezsolomonferede@gmail.com) to obtain certificates, then: sudo systemctl reload nginx"
    fi
    
    # Show next steps
    show_next_steps
}

# Run main function
main "$@"
