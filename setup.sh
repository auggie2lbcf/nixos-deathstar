#!/bin/bash
# NixOS Deathstar Lab Easy Setup Script v3.0
# Run this AFTER completing the standard NixOS graphical installation
# This script sets up AI services, Nextcloud, and Cloudflare tunnels

set -e

echo "=========================================="
echo "  NixOS Deathstar Lab Easy Setup v3.0"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_VERSION="3.0"
CONFIG_REPO="https://github.com/auggie2lbcf/nixos-deathstar.git"
TEMP_DIR="/tmp/nixos-deathstar"

# Helper functions
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
prompt() { echo -e "${CYAN}[PROMPT]${NC} $1"; }

# Validation functions
check_nixos() {
    if [ ! -f /etc/nixos/configuration.nix ]; then
        error "This doesn't appear to be a NixOS system or NixOS isn't properly installed"
    fi
    success "NixOS installation detected"
}

check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log "This script requires sudo access. You may be prompted for your password."
    fi
}

check_internet() {
    log "Checking internet connectivity..."
    if ! ping -c 1 google.com &> /dev/null; then
        error "No internet connection. Please check your network settings."
    fi
    success "Internet connectivity confirmed"
}

# Storage setup functions
setup_storage_directories() {
    log "Setting up storage directories..."
    
    # Create mount points for additional storage
    sudo mkdir -p /mnt/ai-models
    sudo mkdir -p /mnt/nextcloud
    
    # Create data directories with proper permissions
    sudo mkdir -p /var/lib/ai-models
    sudo mkdir -p /var/lib/nextcloud
    
    # Set ownership (will be adjusted by services)
    sudo chown $USER:users /var/lib/ai-models
    
    success "Storage directories created"
}

detect_storage() {
    log "Detecting available storage devices..."
    
    # List available storage devices
    echo "Available storage devices:"
    lsblk -d -o NAME,SIZE,TYPE | grep -E "(disk|nvme)"
    echo
    
    prompt "Storage setup options:"
    echo "1. Use existing filesystem (recommended for post-install)"
    echo "2. Setup additional drives for AI models and Nextcloud"
    echo "3. Skip storage setup (use system drive for everything)"
    
    read -p "Choose option (1-3) [1]: " storage_choice
    storage_choice=${storage_choice:-1}
    
    case $storage_choice in
        1)
            log "Using existing filesystem with subdirectories"
            setup_storage_directories
            ;;
        2)
            setup_additional_drives
            ;;
        3)
            log "Skipping additional storage setup"
            setup_storage_directories
            ;;
        *)
            warn "Invalid choice, using default option 1"
            setup_storage_directories
            ;;
    esac
}

setup_additional_drives() {
    log "Setting up additional drives..."
    echo "Available unmounted drives:"
    lsblk -f | grep -v "/$\|/boot"
    echo
    
    read -p "Enter device for AI models (e.g., /dev/sdb) [skip]: " ai_device
    read -p "Enter device for Nextcloud (e.g., /dev/sdc) [skip]: " nc_device
    
    if [ -n "$ai_device" ] && [ -b "$ai_device" ]; then
        log "Setting up AI models drive: $ai_device"
        sudo mkfs.ext4 -L ai-storage "$ai_device"
        sudo mount "$ai_device" /mnt/ai-models
        echo "LABEL=ai-storage /mnt/ai-models ext4 defaults 0 2" | sudo tee -a /etc/fstab
    fi
    
    if [ -n "$nc_device" ] && [ -b "$nc_device" ]; then
        log "Setting up Nextcloud drive: $nc_device"
        sudo mkfs.ext4 -L nextcloud-storage "$nc_device"
        sudo mount "$nc_device" /mnt/nextcloud
        echo "LABEL=nextcloud-storage /mnt/nextcloud ext4 defaults 0 2" | sudo tee -a /etc/fstab
    fi
    
    success "Additional drives configured"
}

# Configuration download and setup
download_configs() {
    log "Downloading NixOS configuration files..."
    
    # Clean and create temp directory
    rm -rf "$TEMP_DIR"
    git clone "$CONFIG_REPO" "$TEMP_DIR" || error "Failed to download configuration"
    
    success "Configuration files downloaded"
}

backup_existing_config() {
    log "Backing up existing NixOS configuration..."
    
    sudo cp /etc/nixos/configuration.nix "/etc/nixos/configuration.nix.backup.$(date +%s)"
    if [ -f /etc/nixos/hardware-configuration.nix ]; then
        sudo cp /etc/nixos/hardware-configuration.nix "/etc/nixos/hardware-configuration.nix.backup.$(date +%s)"
    fi
    
    success "Existing configuration backed up"
}

create_modular_config() {
    log "Creating modular NixOS configuration..."
    
    # Create services directory
    sudo mkdir -p /etc/nixos/services
    
    # Copy service configurations
    sudo cp "$TEMP_DIR/ai_models_service.nix" /etc/nixos/services/ai-models.nix
    sudo cp "$TEMP_DIR/nextcloud_service.nix" /etc/nixos/services/nextcloud.nix
    sudo cp "$TEMP_DIR/cloudflare_tunnel_service.nix" /etc/nixos/services/cloudflare-tunnel.nix
    
    # Create enhanced configuration.nix that imports existing hardware config
    sudo tee /etc/nixos/configuration.nix > /dev/null << 'EOF'
# Enhanced NixOS Configuration for Deathstar Lab
# This configuration adds AI services, Nextcloud, and Cloudflare tunnels
# to your existing NixOS installation

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./services/ai-models.nix
    ./services/nextcloud.nix
    ./services/cloudflare-tunnel.nix
  ];

  # Boot configuration
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # Networking
  networking.hostName = lib.mkDefault "deathstar";
  networking.networkmanager.enable = lib.mkDefault true;

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Time zone
  time.timeZone = lib.mkDefault "America/New_York";

  # Locale
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # Enable the X11 windowing system and KDE desktop
  services.xserver = {
    enable = lib.mkDefault true;
    displayManager.sddm.enable = lib.mkDefault true;
    desktopManager.plasma5.enable = lib.mkDefault true;
    
    # AMD GPU support
    videoDrivers = lib.mkDefault [ "amdgpu" ];
  };

  # Hardware support
  hardware = {
    # GPU support for AI workloads
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        amdvlk
        rocm-opencl-icd
        rocm-opencl-runtime
      ];
    };
    
    # Audio
    pulseaudio.enable = false;
    bluetooth.enable = lib.mkDefault true;
  };

  # PipeWire audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Virtualization for containers
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    libvirtd.enable = lib.mkDefault false;
  };

  # Gaming support
  programs = {
    steam = {
      enable = lib.mkDefault true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
    gamemode.enable = lib.mkDefault true;
  };

  # User configuration - create a lab user if it doesn't exist
  users.users.vader = {
    isNormalUser = true;
    description = "Lab User";
    extraGroups = [ 
      "networkmanager" 
      "wheel" 
      "audio" 
      "video" 
      "storage" 
      "podman"
    ];
    shell = pkgs.bash;
  };

  # Essential packages
  environment.systemPackages = with pkgs; [
    # System utilities
    vim
    wget
    curl
    git
    htop
    btop
    tree
    unzip
    
    # Networking tools
    nmap
    
    # Container tools
    podman-compose
    
    # AI/ML tools
    python3
    python3Packages.pip
    
    # Cloudflare
    cloudflared
    
    # Gaming (optional)
    lutris
    mangohud
  ];

  # SSH (enable if needed)
  services.openssh = {
    enable = lib.mkDefault false;
    settings = {
      PasswordAuthentication = lib.mkDefault true;
      PermitRootLogin = lib.mkDefault "no";
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
  };

  # Create necessary directories
  systemd.tmpfiles.rules = [
    "d /var/lib/ai-models 0755 vader users"
    "d /var/lib/nextcloud 0755 nextcloud nextcloud"
    "d /run/secrets 0755 root root"
    "d /mnt/ai-models 0755 vader users"
    "d /mnt/nextcloud 0755 nextcloud nextcloud"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = lib.mkDefault "23.11";
}
EOF

    success "Modular configuration created"
}

setup_secrets() {
    log "Setting up secrets and credentials..."
    
    sudo mkdir -p /run/secrets
    
    prompt "Please provide the required credentials:"
    echo
    
    # Domain configuration
    read -p "Enter your domain name [thebennett.net]: " domain
    domain=${domain:-thebennett.net}
    
    # Update domain in service files
    sudo sed -i "s/thebennett\.net/$domain/g" /etc/nixos/services/*.nix
    
    # Cloudflare API Token
    while true; do
        read -s -p "Cloudflare API Token: " cf_token
        echo
        if [ -n "$cf_token" ]; then
            echo "$cf_token" | sudo tee /run/secrets/cloudflare-token > /dev/null
            break
        else
            warn "Token cannot be empty. Please try again."
        fi
    done
    
    # Nextcloud Admin Password
    while true; do
        read -s -p "Nextcloud Admin Password: " nc_pass
        echo
        read -s -p "Confirm Nextcloud Admin Password: " nc_pass_confirm
        echo
        if [ "$nc_pass" = "$nc_pass_confirm" ] && [ -n "$nc_pass" ]; then
            echo "$nc_pass" | sudo tee /run/secrets/nextcloud-admin-pass > /dev/null
            break
        else
            warn "Passwords don't match or are empty. Please try again."
        fi
    done
    
    # Nextcloud Database Password
    while true; do
        read -s -p "Nextcloud Database Password: " nc_db_pass
        echo
        read -s -p "Confirm Nextcloud Database Password: " nc_db_pass_confirm
        echo
        if [ "$nc_db_pass" = "$nc_db_pass_confirm" ] && [ -n "$nc_db_pass" ]; then
            echo "$nc_db_pass" | sudo tee /run/secrets/nextcloud-db-pass > /dev/null
            break
        else
            warn "Passwords don't match or are empty. Please try again."
        fi
    done
    
    # Set secure permissions
    sudo chmod 600 /run/secrets/*
    
    # Store domain for later use
    echo "$domain" | sudo tee /run/secrets/domain > /dev/null
    
    success "Secrets configured securely"
}

apply_configuration() {
    log "Applying NixOS configuration..."
    log "This may take several minutes to download and build packages..."
    
    # Test the configuration first
    if sudo nixos-rebuild dry-build; then
        log "Configuration test passed, applying changes..."
        sudo nixos-rebuild switch
        success "NixOS configuration applied successfully"
    else
        error "Configuration failed to build. Please check the error messages above."
    fi
}

setup_cloudflare_tunnels() {
    log "Setting up Cloudflare tunnels..."
    
    domain=$(cat /run/secrets/domain)
    
    # Login to Cloudflare
    prompt "Cloudflare tunnel setup requires browser authentication"
    echo "A browser window will open for Cloudflare login..."
    read -p "Press Enter to continue..."
    
    sudo -u $USER cloudflared tunnel login
    
    # Create tunnels
    log "Creating Cloudflare tunnels..."
    AI_TUNNEL_ID=$(sudo -u $USER cloudflared tunnel create ai-tunnel 2>&1 | grep -o '[a-f0-9-]\{36\}' | head -1)
    NC_TUNNEL_ID=$(sudo -u $USER cloudflared tunnel create nextcloud-tunnel 2>&1 | grep -o '[a-f0-9-]\{36\}' | head -1)
    
    if [ -z "$AI_TUNNEL_ID" ] || [ -z "$NC_TUNNEL_ID" ]; then
        error "Failed to create tunnels. Please check your Cloudflare authentication."
    fi
    
    log "AI Tunnel ID: $AI_TUNNEL_ID"
    log "Nextcloud Tunnel ID: $NC_TUNNEL_ID"
    
    # Copy credentials
    sudo cp "/home/$USER/.cloudflared/$AI_TUNNEL_ID.json" /run/secrets/cloudflare-ai-tunnel.json
    sudo cp "/home/$USER/.cloudflared/$NC_TUNNEL_ID.json" /run/secrets/cloudflare-nextcloud-tunnel.json
    sudo chmod 600 /run/secrets/cloudflare-*-tunnel.json
    
    # Update tunnel IDs in configuration
    sudo sed -i "s/\$CLOUDFLARE_AI_TUNNEL_ID/$AI_TUNNEL_ID/g" /etc/nixos/services/cloudflare-tunnel.nix
    sudo sed -i "s/\$CLOUDFLARE_NEXTCLOUD_TUNNEL_ID/$NC_TUNNEL_ID/g" /etc/nixos/services/cloudflare-tunnel.nix
    
    # Create DNS records
    log "Creating DNS records..."
    sudo -u $USER cloudflared tunnel route dns ai-tunnel "c3p0.$domain"
    sudo -u $USER cloudflared tunnel route dns nextcloud-tunnel "scarif.$domain"
    
    # Rebuild to apply tunnel configuration
    log "Applying tunnel configuration..."
    sudo nixos-rebuild switch
    
    success "Cloudflare tunnels configured"
}

start_services() {
    log "Starting services..."
    
    # Enable and start Cloudflare tunnels
    sudo systemctl enable --now cloudflared-ai
    sudo systemctl enable --now cloudflared-nextcloud
    
    # Start container services
    sudo systemctl restart podman
    
    # Wait for services to initialize
    log "Waiting for services to start..."
    sleep 30
    
    success "Services started"
}

install_ai_models() {
    log "Installing default AI models..."
    
    # Wait for Ollama to be ready
    timeout=60
    while ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1 && [ $timeout -gt 0 ]; do
        echo "Waiting for Ollama to start... ($timeout seconds remaining)"
        sleep 5
        ((timeout-=5))
    done
    
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        log "Installing lightweight models (this may take a while)..."
        
        # Install models in background
        (
            curl -X POST http://localhost:11434/api/pull -d '{"name":"llama2:7b"}' &
            curl -X POST http://localhost:11434/api/pull -d '{"name":"codellama:7b"}' &
            wait
        )
        
        success "AI models installation started in background"
    else
        warn "Ollama not responding. You can install models later with: ai-pull-model <model-name>"
    fi
}

check_services() {
    log "Checking service status..."
    
    domain=$(cat /run/secrets/domain)
    
    echo
    echo "Service Status:"
    echo "==============="
    
    # Check containers
    if sudo podman ps | grep -q ollama; then
        echo "✅ Ollama: Running"
    else
        echo "❌ Ollama: Not running"
    fi
    
    if sudo podman ps | grep -q open-webui; then
        echo "✅ Open WebUI: Running"
    else
        echo "❌ Open WebUI: Not running"
    fi
    
    # Check tunnels
    if sudo systemctl is-active --quiet cloudflared-ai; then
        echo "✅ AI Tunnel: Active"
    else
        echo "❌ AI Tunnel: Inactive"
    fi
    
    if sudo systemctl is-active --quiet cloudflared-nextcloud; then
        echo "✅ Nextcloud Tunnel: Active"
    else
        echo "❌ Nextcloud Tunnel: Inactive"
    fi
    
    echo
    echo "Your services should be available at:"
    echo "🤖 AI Services: https://c3p0.$domain"
    echo "☁️  Nextcloud:  https://scarif.$domain"
}

create_helper_scripts() {
    log "Creating helper scripts..."
    
    # Create management script
    sudo tee /usr/local/bin/deathstar-manage > /dev/null << 'EOF'
#!/bin/bash
# Deathstar Lab Management Script

case "$1" in
    status)
        echo "=== Deathstar Lab Status ==="
        echo "Containers:"
        sudo podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo
        echo "Tunnels:"
        sudo systemctl status cloudflared-ai --no-pager -l | head -3
        sudo systemctl status cloudflared-nextcloud --no-pager -l | head -3
        ;;
    restart)
        echo "Restarting all services..."
        sudo systemctl restart cloudflared-ai cloudflared-nextcloud
        sudo systemctl restart podman
        echo "Services restarted"
        ;;
    logs)
        echo "=== Recent Logs ==="
        sudo journalctl -u cloudflared-ai -n 10 --no-pager
        sudo journalctl -u cloudflared-nextcloud -n 10 --no-pager
        ;;
    update)
        echo "Updating system configuration..."
        sudo nixos-rebuild switch
        ;;
    *)
        echo "Deathstar Lab Management"
        echo "Usage: $0 {status|restart|logs|update}"
        echo "  status  - Show service status"
        echo "  restart - Restart all services"
        echo "  logs    - Show recent logs"
        echo "  update  - Update system configuration"
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/deathstar-manage
    
    success "Helper scripts created"
}

show_completion() {
    domain=$(cat /run/secrets/domain)
    
    echo
    echo "=========================================="
    echo "  🚀 Installation Complete! 🚀"
    echo "=========================================="
    echo
    success "Your NixOS Deathstar Lab is ready!"
    echo
    echo "📱 Access your services:"
    echo "   🤖 AI Chat:    https://c3p0.$domain"
    echo "   ☁️  Nextcloud:  https://scarif.$domain"
    echo
    echo "🔧 Management commands:"
    echo "   deathstar-manage status   # Check all services"
    echo "   deathstar-manage restart  # Restart services"
    echo "   deathstar-manage logs     # View logs"
    echo "   deathstar-manage update   # Update system"
    echo
    echo "🤖 AI commands:"
    echo "   ai-status                 # Check AI services"
    echo "   ai-pull-model llama2      # Download models"
    echo
    echo "🔗 Cloudflare commands:"
    echo "   cf-tunnel-status          # Check tunnels"
    echo "   cf-test-endpoints         # Test connectivity"
    echo
    warn "⚠️  First-time setup notes:"
    echo "   • AI models are downloading in the background"
    echo "   • Nextcloud may take a few minutes to fully initialize"
    echo "   • Check service status with: deathstar-manage status"
    echo
    echo "📚 Troubleshooting:"
    echo "   • If services don't start: sudo nixos-rebuild switch"
    echo "   • For detailed logs: journalctl -u <service-name>"
    echo "   • Configuration files: /etc/nixos/"
    echo
    echo "🎉 May the Force be with your deployments!"
    echo "=========================================="
}

# Main execution
main() {
    log "Starting NixOS Deathstar Lab Easy Setup v$SCRIPT_VERSION"
    
    # Pre-flight checks
    check_nixos
    check_sudo
    check_internet
    
    # Setup process
    detect_storage
    download_configs
    backup_existing_config
    create_modular_config
    setup_secrets
    apply_configuration
    setup_cloudflare_tunnels
    start_services
    install_ai_models
    create_helper_scripts
    check_services
    show_completion
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    log "Setup completed successfully!"
}

# Run main function
main "$@"
