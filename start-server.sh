#!/bin/bash

# GameDevMap Server Management Script
# Supports development and production deployment modes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
PUBLIC_DIR="$PROJECT_ROOT/public"
DATA_DIR="$PROJECT_ROOT/data"
DOMAIN="${DOMAIN:-localhost}"
PORT="${PORT:-8000}"
LOG_DIR="/var/log/gamedevmap"
CONFIG_DIR="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"
SERVICE_NAME="gamedevmap"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Linux/Unix
check_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
        return 0
    else
        log_error "This script only supports Linux and macOS"
        exit 1
    fi
}

# Check if directory exists
check_directories() {
    if [ ! -d "$PUBLIC_DIR" ]; then
        log_error "Public directory not found: $PUBLIC_DIR"
        exit 1
    fi
    
    if [ ! -f "$PUBLIC_DIR/index.html" ]; then
        log_error "index.html not found in $PUBLIC_DIR"
        exit 1
    fi
    
    log_success "Directory structure verified"
}

# Development mode: Run local HTTP server
run_dev() {
    log_info "Starting development server..."
    log_info "Project root: $PROJECT_ROOT"
    log_info "Public directory: $PUBLIC_DIR"
    
    cd "$PUBLIC_DIR"
    
    if command -v python3 &> /dev/null; then
        log_info "Using Python 3 HTTP server"
        log_success "Server running at http://localhost:$PORT"
        python3 -m http.server $PORT
    elif command -v python &> /dev/null; then
        log_info "Using Python 2 HTTP server"
        log_success "Server running at http://localhost:$PORT"
        python -m SimpleHTTPServer $PORT
    elif command -v node &> /dev/null; then
        log_info "Using Node.js http-server"
        if ! command -v http-server &> /dev/null; then
            log_warning "http-server not installed. Installing..."
            npm install -g http-server
        fi
        log_success "Server running at http://localhost:$PORT"
        http-server -p $PORT
    else
        log_error "No suitable HTTP server found (Python or Node.js required)"
        exit 1
    fi
}

# Generate Nginx configuration
generate_nginx_config() {
    cat > /tmp/gamedevmap.nginx.conf << 'EOF'
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;
    
    # Redirect HTTP to HTTPS (optional - remove if SSL not configured)
    # return 301 https://$server_name$request_uri;
    
    root ROOT_PATH_PLACEHOLDER;
    index index.html index.htm;
    
    # Access and error logs
    access_log /var/log/gamedevmap/access.log;
    error_log /var/log/gamedevmap/error.log warn;
    
    # Static file caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Main application routing
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }
    
    # API routing (if backend exists)
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF
}

# Deploy to production (Nginx)
deploy() {
    log_info "Starting production deployment..."
    
    # Check if nginx is installed
    if ! command -v nginx &> /dev/null; then
        log_error "Nginx is not installed. Please install nginx first:"
        echo "    Ubuntu/Debian: sudo apt-get install nginx"
        echo "    CentOS/RHEL: sudo yum install nginx"
        echo "    macOS: brew install nginx"
        exit 1
    fi
    
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        log_error "Deployment requires root privileges. Please run:"
        echo "    sudo ./start-server.sh deploy"
        exit 1
    fi
    
    log_info "Verifying directory structure..."
    check_directories
    
    # Create log directory
    log_info "Setting up log directory..."
    mkdir -p "$LOG_DIR"
    touch "$LOG_DIR/access.log"
    touch "$LOG_DIR/error.log"
    
    # Generate Nginx configuration
    log_info "Generating Nginx configuration..."
    generate_nginx_config
    
    # Replace placeholders in configuration
    sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" /tmp/gamedevmap.nginx.conf
    sed -i "s|ROOT_PATH_PLACEHOLDER|$PUBLIC_DIR|g" /tmp/gamedevmap.nginx.conf
    
    # Copy configuration to Nginx sites-available
    log_info "Installing Nginx configuration..."
    cp /tmp/gamedevmap.nginx.conf "$CONFIG_DIR/$SERVICE_NAME"
    chmod 644 "$CONFIG_DIR/$SERVICE_NAME"
    
    # Remove old symlink if exists
    if [ -L "$SITES_ENABLED/$SERVICE_NAME" ]; then
        rm "$SITES_ENABLED/$SERVICE_NAME"
    fi
    
    # Create symlink to enable site
    log_info "Enabling site configuration..."
    ln -s "$CONFIG_DIR/$SERVICE_NAME" "$SITES_ENABLED/$SERVICE_NAME"
    
    # Disable default site if it exists
    if [ -L "$SITES_ENABLED/default" ]; then
        log_warning "Disabling default Nginx site..."
        rm "$SITES_ENABLED/default"
    fi
    
    # Test Nginx configuration
    log_info "Testing Nginx configuration..."
    if ! nginx -t 2>&1 | grep -q "successful"; then
        log_error "Nginx configuration test failed"
        nginx -t
        exit 1
    fi
    
    log_success "Nginx configuration is valid"
    
    # Restart Nginx
    log_info "Restarting Nginx service..."
    if command -v systemctl &> /dev/null; then
        systemctl restart nginx
    else
        service nginx restart
    fi
    
    log_success "Production deployment completed"
    log_info "Access your application at http://$DOMAIN"
}

# Reload Nginx configuration
reload() {
    log_info "Reloading Nginx configuration..."
    
    if [ "$EUID" -ne 0 ]; then
        log_error "Reload requires root privileges. Please run:"
        echo "    sudo ./start-server.sh reload"
        exit 1
    fi
    
    if ! command -v nginx &> /dev/null; then
        log_error "Nginx is not installed"
        exit 1
    fi
    
    # Test configuration first
    log_info "Testing Nginx configuration..."
    if ! nginx -t 2>&1 | grep -q "successful"; then
        log_error "Nginx configuration test failed"
        nginx -t
        exit 1
    fi
    
    # Reload service
    if command -v systemctl &> /dev/null; then
        systemctl reload nginx
    else
        service nginx reload
    fi
    
    log_success "Nginx configuration reloaded successfully"
}

# Check service status
status() {
    log_info "Checking service status..."
    
    if command -v systemctl &> /dev/null; then
        systemctl status nginx
    elif command -v service &> /dev/null; then
        service nginx status
    else
        log_warning "Unable to determine service manager"
        if pgrep nginx > /dev/null; then
            log_success "Nginx is running"
        else
            log_warning "Nginx is not running"
        fi
    fi
}

# Stop service
stop() {
    log_info "Stopping services..."
    
    if [ "$EUID" -ne 0 ]; then
        log_error "Stop requires root privileges. Please run:"
        echo "    sudo ./start-server.sh stop"
        exit 1
    fi
    
    if command -v systemctl &> /dev/null; then
        systemctl stop nginx
    elif command -v service &> /dev/null; then
        service nginx stop
    else
        log_error "Unable to stop service"
        exit 1
    fi
    
    log_success "Service stopped"
}

# Display help
show_help() {
    cat << EOF
GameDevMap Server Management Script

Usage: ./start-server.sh [COMMAND] [OPTIONS]

Commands:
    dev                 Start local development server (default)
    deploy              Deploy to production with Nginx (requires sudo)
    reload              Reload Nginx configuration (requires sudo)
    status              Check Nginx service status
    stop                Stop Nginx service (requires sudo)
    help                Display this help message

Environment Variables:
    DOMAIN              Domain name for Nginx (default: localhost)
    PORT                Port for development server (default: 8000)

Examples:
    # Start development server on default port 8000
    ./start-server.sh dev
    
    # Deploy to production
    sudo ./start-server.sh deploy
    
    # Deploy with custom domain
    sudo DOMAIN=example.com ./start-server.sh deploy
    
    # Reload configuration after changes
    sudo ./start-server.sh reload
    
    # Check service status
    ./start-server.sh status

For more information, see README.md

EOF
}

# Main script logic
main() {
    check_os
    check_directories
    
    # Get command (default to dev)
    COMMAND="${1:-dev}"
    
    case "$COMMAND" in
        dev)
            run_dev
            ;;
        deploy)
            deploy
            ;;
        reload)
            reload
            ;;
        status)
            status
            ;;
        stop)
            stop
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"