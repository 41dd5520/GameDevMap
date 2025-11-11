#!/bin/bash
# GameDevMap Server Management Script
# Usage: ./start-server.sh [dev|prod|deploy|reload|status|stop]
# Author: GameDevMap Team
# Version: 1.0.0

set -e

# Configuration
PROJECT_NAME="gamedevmap"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLIC_DIR="$PROJECT_ROOT/public"
NGINX_AVAILABLE="/etc/nginx/sites-available/$PROJECT_NAME"
NGINX_ENABLED="/etc/nginx/sites-enabled/$PROJECT_NAME"
SERVER_PORT=8000
BACKEND_PORT=3000

# Colors for output (optional, can be disabled)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Check if script is run with sudo for production operations
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This operation requires sudo privileges"
        log_info "Please run: sudo $0 $1"
        exit 1
    fi
}

# Detect server environment
detect_environment() {
    if command -v nginx &> /dev/null; then
        echo "production"
    else
        echo "development"
    fi
}

# Generate Nginx configuration
generate_nginx_config() {
    local domain=${1:-"localhost"}
    local config_path="$2"
    
    log_info "Generating Nginx configuration for domain: $domain"
    
    cat > "$config_path" <<EOF
# GameDevMap Nginx Configuration
# Generated: $(date)
# Domain: $domain

server {
    listen 80;
    listen [::]:80;
    server_name $domain;
    
    # Document root
    root $PUBLIC_DIR;
    index index.html;
    
    # Logging
    access_log /var/log/nginx/${PROJECT_NAME}_access.log;
    error_log /var/log/nginx/${PROJECT_NAME}_error.log warn;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Main location
    location / {
        try_files \$uri \$uri/ /index.html;
        
        # No cache for HTML files
        location ~* \.html$ {
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }
    }
    
    # Static assets with cache
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|webp)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # JSON data files
    location ~* \.json$ {
        add_header Cache-Control "no-cache";
        access_log off;
    }
    
    # API proxy (if backend exists)
    location /api/ {
        proxy_pass http://localhost:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Error pages
    error_page 404 /index.html;
    error_page 500 502 503 504 /index.html;
    
    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF
    
    log_success "Nginx configuration generated at: $config_path"
}

# Deploy to production (Nginx)
deploy_production() {
    check_sudo
    
    log_info "Starting production deployment..."
    
    # Check if public directory exists
    if [ ! -d "$PUBLIC_DIR" ]; then
        log_error "Public directory not found: $PUBLIC_DIR"
        exit 1
    fi
    
    # Prompt for domain name
    read -p "Enter your domain name (or press Enter for default): " DOMAIN_NAME
    DOMAIN_NAME=${DOMAIN_NAME:-"_"}
    
    # Generate Nginx configuration
    generate_nginx_config "$DOMAIN_NAME" "$NGINX_AVAILABLE"
    
    # Enable site
    if [ ! -L "$NGINX_ENABLED" ]; then
        ln -sf "$NGINX_AVAILABLE" "$NGINX_ENABLED"
        log_success "Site enabled: $NGINX_ENABLED"
    else
        log_info "Site already enabled"
    fi
    
    # Test Nginx configuration
    log_info "Testing Nginx configuration..."
    if nginx -t 2>&1; then
        log_success "Nginx configuration test passed"
    else
        log_error "Nginx configuration test failed"
        exit 1
    fi
    
    # Reload Nginx
    log_info "Reloading Nginx..."
    systemctl reload nginx || service nginx reload
    
    # Enable Nginx to start on boot
    systemctl enable nginx 2>/dev/null || true
    
    log_success "Production deployment complete"
    log_info "Site is now live at: http://$DOMAIN_NAME"
    log_info "To enable HTTPS, run: sudo certbot --nginx -d $DOMAIN_NAME"
}

# Start development server
start_development() {
    log_info "Starting development server..."
    
    if [ ! -d "$PUBLIC_DIR" ]; then
        log_error "Public directory not found: $PUBLIC_DIR"
        exit 1
    fi
    
    # Check for Python
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        log_error "Python is not installed"
        log_info "Install Python: sudo apt install python3"
        exit 1
    fi
    
    log_info "Server address: http://localhost:$SERVER_PORT"
    log_info "Document root: $PUBLIC_DIR"
    log_info "Press Ctrl+C to stop the server"
    echo ""
    
    cd "$PUBLIC_DIR"
    $PYTHON_CMD -m http.server $SERVER_PORT
}

# Reload Nginx configuration
reload_nginx() {
    check_sudo
    
    log_info "Testing Nginx configuration..."
    if nginx -t 2>&1; then
        log_success "Configuration test passed"
        log_info "Reloading Nginx..."
        systemctl reload nginx || service nginx reload
        log_success "Nginx reloaded successfully"
    else
        log_error "Configuration test failed. Nginx not reloaded."
        exit 1
    fi
}

# Check server status
check_status() {
    local env=$(detect_environment)
    
    log_info "Environment: $env"
    log_info "Project root: $PROJECT_ROOT"
    log_info "Public directory: $PUBLIC_DIR"
    
    if [ "$env" = "production" ]; then
        log_info "Checking Nginx status..."
        systemctl status nginx --no-pager || service nginx status
        
        if [ -f "$NGINX_AVAILABLE" ]; then
            log_info "Configuration file: $NGINX_AVAILABLE (exists)"
        else
            log_warn "Configuration file not found: $NGINX_AVAILABLE"
        fi
        
        if [ -L "$NGINX_ENABLED" ]; then
            log_info "Site enabled: Yes"
        else
            log_warn "Site not enabled"
        fi
    else
        log_info "No Nginx detected. Run in development mode."
    fi
}

# Stop server
stop_server() {
    check_sudo
    
    log_info "Stopping Nginx..."
    systemctl stop nginx || service nginx stop
    log_success "Nginx stopped"
}

# Show usage
show_usage() {
    cat <<EOF
GameDevMap Server Management Script

Usage: $0 [COMMAND]

Commands:
    dev         Start development server (Python HTTP server)
    prod        Deploy to production (Nginx) - requires sudo
    deploy      Alias for 'prod'
    reload      Reload Nginx configuration - requires sudo
    status      Check server status
    stop        Stop Nginx server - requires sudo
    help        Show this help message

Examples:
    $0 dev              # Start development server
    sudo $0 prod        # Deploy to production
    sudo $0 reload      # Reload Nginx config
    $0 status           # Check status

EOF
}

# Main script logic
main() {
    local command=${1:-"auto"}
    
    case "$command" in
        dev|development)
            start_development
            ;;
        prod|production|deploy)
            deploy_production
            ;;
        reload)
            reload_nginx
            ;;
        status)
            check_status
            ;;
        stop)
            stop_server
            ;;
        help|--help|-h)
            show_usage
            ;;
        auto)
            # Auto-detect environment
            local env=$(detect_environment)
            if [ "$env" = "production" ]; then
                log_info "Production environment detected"
                if [ ! -f "$NGINX_AVAILABLE" ]; then
                    log_warn "Nginx configuration not found. Run: sudo $0 deploy"
                    exit 1
                fi
                reload_nginx
            else
                log_info "Development environment detected"
                start_development
            fi
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"