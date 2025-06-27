#!/bin/bash
# NixOS Deathstar Lab Setup Script v2.0
# Improved version with better error handling, validation, and flexibility
# Run this script after booting from NixOS installer

set -e

echo "=========================================="
echo "  NixOS Deathstar Lab Setup Script v2.0"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
SCRIPT_VERSION="2.0"
CONFIG_REPO="${CONFIG_REPO:-https://github.com/auggie2lbcf/nixos-deathstar.git}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_PARTITIONING="${SKIP_PARTITIONING:-false}"
FORCE_FORMAT="${FORCE_FORMAT:-false}"

# Device configuration (can be overridden via environment)
SSD_DEVICE="${SSD_DEVICE:-/dev/sdb}"
HDD_DEVICE="${HDD_DEVICE:-/dev/sda}"
NVME_DEVICE="${NVME_DEVICE:-/dev/nvme0n1}"

# Filesystem labels (shortened to avoid truncation)
BOOT_LABEL="boot"
ROOT_LABEL="nixos-root"
AI_LABEL="ai-storage"
NEXTCLOUD_LABEL="nextcloud"  # Shortened from nextcloud-storage

# Helper functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

prompt() {
    echo -e "${CYAN}[PROMPT]${NC} $1"
}

# Validation functions
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run this script as root (use sudo)"
    fi
}

check_nixos_installer() {
    if ! command -v nixos-generate-config &> /dev/null; then
        error "This script must be run from a NixOS installer environment"
    fi
}

check_internet() {
    log "Checking internet connectivity..."
    if ! ping -c 1 google.com &> /dev/null; then
        error "No internet connection. Please configure networking first."
    fi
    success "Internet connectivity confirmed"
}

check_devices() {
    log "Validating storage devices..."
    
    local missing_devices=()
    
    if [ ! -b "$SSD_DEVICE" ]; then
        missing_devices+=("SSD: $SSD_DEVICE")
    fi
    
    if [ ! -b "$HDD_DEVICE" ]; then
        missing_devices+=("HDD: $HDD_DEVICE")
    fi
    
    if [ ! -b "$NVME_DEVICE" ]; then
        missing_devices+=("NVME: $NVME_DEVICE")
    fi
    
    if [ ${#missing_devices[@]} -gt 0 ]; then
        error "Missing storage devices: ${missing_devices[*]}"
    fi
    
    success "All storage devices found"
}

show_device_info() {
    log "Storage device information:"
    echo "  SSD (OS):         $SSD_DEVICE"
    echo "  HDD (AI Models):  $HDD_DEVICE"
    echo "  NVME (Nextcloud): $NVME_DEVICE"
    echo
    
    log "Device details:"
    lsblk "$SSD_DEVICE" "$HDD_DEVICE" "$NVME_DEVICE" 2>/dev/null || true
    echo
}

confirm_destructive_operation() {
    if [ "$FORCE_FORMAT" = "true" ]; then
        warn "FORCE_FORMAT=true - Skipping confirmation"
        return 0
    fi
    
    echo -e "${RED}WARNING: This will DESTROY ALL DATA on the following devices:${NC}"
    echo "  $SSD_DEVICE (SSD)"
    echo "  $HDD_DEVICE (HDD)"
    echo "  $NVME_DEVICE (NVME)"
    echo
    read -p "Are you absolutely sure you want to continue? (type 'YES' to confirm): " confirmation
    
    if [ "$confirmation" != "YES" ]; then
        log "Operation cancelled by user"
        exit 0
    fi
}

# Utility functions
unmount_all() {
    log "Unmounting any existing filesystems..."
    
    # Unmount in reverse order (deepest first)
    umount -R /mnt 2>/dev/null || true
    
    # Force unmount specific devices if they're still mounted
    for device in "${SSD_DEVICE}1" "${SSD_DEVICE}2" "${HDD_DEVICE}1" "${NVME_DEVICE}p1"; do
        if mountpoint -q "/mnt" 2>/dev/null; then
            umount "$device" 2>/dev/null || true
        fi
    done
    
    # Wait for unmounts to complete
    sleep 2
    success "Filesystems unmounted"
}

wait_for_device() {
    local device="$1"
    local timeout=10
    local count=0
    
    while [ ! -e "$device" ] && [ $count -lt $timeout ]; do
        sleep 1
        ((count++))
    done
    
    if [ ! -e "$device" ]; then
        error "Device $device did not appear after $timeout seconds"
    fi
}

# Partitioning functions
partition_ssd() {
    log "Partitioning SSD ($SSD_DEVICE) for boot and main OS..."
    
    # Create GPT partition table
    parted "$SSD_DEVICE" --script mklabel gpt
    
    # Create EFI boot partition (512MB)
    parted "$SSD_DEVICE" --script mkpart ESP fat32 1MiB 513MiB
    parted "$SSD_DEVICE" --script set 1 esp on
    
    # Create root partition (remaining space)
    parted "$SSD_DEVICE" --script mkpart primary ext4 513MiB 100%
    
    # Wait for partitions to appear
    wait_for_device "${SSD_DEVICE}1"
    wait_for_device "${SSD_DEVICE}2"
    
    success "SSD partitioned successfully"
}

partition_hdd() {
    log "Partitioning HDD ($HDD_DEVICE) for AI model storage..."
    
    # Create GPT partition table
    parted "$HDD_DEVICE" --script mklabel gpt
    
    # Create single partition for AI storage
    parted "$HDD_DEVICE" --script mkpart primary ext4 1MiB 100%
    
    # Wait for partition to appear
    wait_for_device "${HDD_DEVICE}1"
    
    success "HDD partitioned successfully"
}

partition_nvme() {
    log "Partitioning NVME ($NVME_DEVICE) for Nextcloud storage..."
    
    # Create GPT partition table
    parted "$NVME_DEVICE" --script mklabel gpt
    
    # Create single partition for Nextcloud storage
    parted "$NVME_DEVICE" --script mkpart primary ext4 1MiB 100%
    
    # Wait for partition to appear
    wait_for_device "${NVME_DEVICE}p1"
    
    success "NVME partitioned successfully"
}

# Formatting functions
format_filesystems() {
    log "Formatting filesystems with appropriate labels..."
    
    # Format boot partition (FAT32)
    log "Formatting boot partition..."
    mkfs.fat -F 32 -n "$BOOT_LABEL" "${SSD_DEVICE}1"
    
    # Format root partition (ext4)
    log "Formatting root partition..."
    mkfs.ext4 -F -L "$ROOT_LABEL" "${SSD_DEVICE}2"
    
    # Format AI storage (ext4)
    log "Formatting AI storage partition..."
    mkfs.ext4 -F -L "$AI_LABEL" "${HDD_DEVICE}1"
    
    # Format Nextcloud storage (ext4)
    log "Formatting Nextcloud storage partition..."
    mkfs.ext4 -F -L "$NEXTCLOUD_LABEL" "${NVME_DEVICE}p1"
    
    # Trigger udev to update /dev/disk/by-label/
    udevadm trigger
    sleep 3
    
    success "All filesystems formatted successfully"
}

verify_labels() {
    log "Verifying filesystem labels..."
    
    local expected_labels=("$BOOT_LABEL" "$ROOT_LABEL" "$AI_LABEL" "$NEXTCLOUD_LABEL")
    local missing_labels=()
    
    for label in "${expected_labels[@]}"; do
        if [ ! -e "/dev/disk/by-label/$label" ]; then
            missing_labels+=("$label")
        fi
    done
    
    if [ ${#missing_labels[@]} -gt 0 ]; then
        error "Missing filesystem labels: ${missing_labels[*]}"
    fi
    
    success "All filesystem labels verified"
}

# Mounting functions
mount_filesystems() {
    log "Creating mount points and mounting filesystems..."
    
    # Mount root filesystem
    mount "/dev/disk/by-label/$ROOT_LABEL" /mnt
    success "Root filesystem mounted"
    
    # Create and mount boot
    mkdir -p /mnt/boot
    mount "/dev/disk/by-label/$BOOT_LABEL" /mnt/boot
    success "Boot filesystem mounted"
    
    # Create and mount AI storage
    mkdir -p /mnt/mnt/ai-models
    mount "/dev/disk/by-label/$AI_LABEL" /mnt/mnt/ai-models
    success "AI storage mounted"
    
    # Create and mount Nextcloud storage
    mkdir -p /mnt/mnt/nextcloud
    mount "/dev/disk/by-label/$NEXTCLOUD_LABEL" /mnt/mnt/nextcloud
    success "Nextcloud storage mounted"
    
    # Verify all mounts
    log "Mount verification:"
    df -h | grep -E "(Filesystem|/mnt)"
}

# Configuration functions
download_configuration() {
    log "Setting up NixOS configuration files..."
    
    # Create configuration directory structure
    mkdir -p /mnt/etc/nixos/services
    
    if [ -n "$CONFIG_REPO" ]; then
        log "Cloning configuration from $CONFIG_REPO..."
        
        # Clone to temporary location
        if git clone "$CONFIG_REPO" /tmp/nixos-config; then
            # Copy configuration files
            cp -r /tmp/nixos-config/*.nix /mnt/etc/nixos/ 2>/dev/null || true
            cp -r /tmp/nixos-config/services/*.nix /mnt/etc/nixos/services/ 2>/dev/null || true
            
            # Copy any additional files
            cp -r /tmp/nixos-config/.gitignore /mnt/etc/nixos/ 2>/dev/null || true
            cp -r /tmp/nixos-config/README.md /mnt/etc/nixos/ 2>/dev/null || true
            
            success "Configuration files downloaded"
        else
            warn "Failed to clone configuration repository"
            prompt "Please manually copy configuration files to /mnt/etc/nixos/"
            read -p "Press Enter when configuration files are in place..."
        fi
    else
        warn "No CONFIG_REPO specified"
        prompt "Please manually copy the following files to /mnt/etc/nixos/:"
        echo "  - configuration.nix"
        echo "  - services/nextcloud.nix"
        echo "  - services/ai-models.nix"
        echo "  - services/cloudflare-tunnel.nix"
        read -p "Press Enter when configuration files are in place..."
    fi
}

setup_secrets() {
    log "Setting up secrets directory..."
    mkdir -p /mnt/run/secrets
    
    prompt "Please provide the required secrets (passwords will be hidden):"
    echo
    
    # Cloudflare API Token
    while true; do
        read -s -p "Cloudflare API Token: " cf_token
        echo
        if [ -n "$cf_token" ]; then
            echo "$cf_token" > /mnt/run/secrets/cloudflare-token
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
            echo "$nc_pass" > /mnt/run/secrets/nextcloud-admin-pass
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
            echo "$nc_db_pass" > /mnt/run/secrets/nextcloud-db-pass
            break
        else
            warn "Passwords don't match or are empty. Please try again."
        fi
    done
    
    # Set secure permissions
    chmod 600 /mnt/run/secrets/*
    
    success "Secrets configured securely"
}

create_swap() {
    log "Creating swap file (16GB)..."
    
    # Create 16GB swap file
    dd if=/dev/zero of=/mnt/swapfile bs=1M count=16384 status=progress
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    
    success "Swap file created"
}

generate_hardware_config() {
    log "Generating hardware configuration..."
    nixos-generate-config --root /mnt
    success "Hardware configuration generated"
}

install_nixos() {
    log "Installing NixOS (this may take a while)..."
    nixos-install --root /mnt
    success "NixOS installation completed"
}

setup_user() {
    log "Setting up user account..."
    
    # Check if user exists in the new system
    if nixos-enter --root /mnt -c "id vader" &>/dev/null; then
        prompt "Please set password for user 'vader':"
        nixos-enter --root /mnt -c "passwd vader"
        success "User account configured"
    else
        warn "User 'vader' not found in installed system"
        log "This will be handled in the post-install script"
        
        # Create a script to set password on first boot
        cat > /mnt/etc/nixos/setup-user-password.sh << 'EOF'
#!/bin/bash
# Set password for vader user on first boot
if id vader &>/dev/null; then
    echo "Setting password for user 'vader':"
    passwd vader
    # Remove this script after running
    rm -f /etc/nixos/setup-user-password.sh
else
    echo "User 'vader' still not found"
    exit 1
fi
EOF
        chmod +x /mnt/etc/nixos/setup-user-password.sh
        
        warn "You'll need to set the user password after reboot"
        warn "Run: sudo /etc/nixos/setup-user-password.sh"
    fi
}

create_post_install_script() {
    log "Creating post-install setup script..."
    
    cat > /mnt/home/vader/post-install-setup.sh << 'EOF'
#!/bin/bash
# Post-install setup script for Deathstar lab v2.0

set -e

echo "=========================================="
echo "  Post-Install Setup v2.0"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if we need to set user password
if [ -f "/etc/nixos/setup-user-password.sh" ]; then
    log "Setting up user password (this was deferred from installation)..."
    sudo /etc/nixos/setup-user-password.sh
fi

# Update system
log "Updating NixOS configuration..."
sudo nixos-rebuild switch

# Check if cloudflared is available
if ! command -v cloudflared &> /dev/null; then
    error "cloudflared not found. Please ensure it's installed in your NixOS configuration."
    exit 1
fi

# Setup Cloudflare tunnels
log "Setting up Cloudflare tunnels..."
echo "Follow these steps:"
echo
echo "1. Login to Cloudflare (this will open a browser):"
echo "   cloudflared tunnel login"
echo
read -p "Press Enter after completing the login process..."

echo "2. Creating tunnels..."
AI_TUNNEL_ID=$(cloudflared tunnel create ai-tunnel 2>&1 | grep -o '[a-f0-9-]\{36\}' | head -1)
NC_TUNNEL_ID=$(cloudflared tunnel create nextcloud-tunnel 2>&1 | grep -o '[a-f0-9-]\{36\}' | head -1)

if [ -z "$AI_TUNNEL_ID" ] || [ -z "$NC_TUNNEL_ID" ]; then
    error "Failed to create tunnels. Please check your Cloudflare login and try again."
    exit 1
fi

echo "AI Tunnel ID: $AI_TUNNEL_ID"
echo "Nextcloud Tunnel ID: $NC_TUNNEL_ID"

# Copy credentials with error checking
log "Setting up tunnel credentials..."
if [ -f "$HOME/.cloudflared/$AI_TUNNEL_ID.json" ]; then
    sudo cp "$HOME/.cloudflared/$AI_TUNNEL_ID.json" /run/secrets/cloudflare-ai-tunnel.json
else
    error "AI tunnel credentials not found at $HOME/.cloudflared/$AI_TUNNEL_ID.json"
    exit 1
fi

if [ -f "$HOME/.cloudflared/$NC_TUNNEL_ID.json" ]; then
    sudo cp "$HOME/.cloudflared/$NC_TUNNEL_ID.json" /run/secrets/cloudflare-nextcloud-tunnel.json
else
    error "Nextcloud tunnel credentials not found at $HOME/.cloudflared/$NC_TUNNEL_ID.json"
    exit 1
fi

sudo chmod 600 /run/secrets/cloudflare-*-tunnel.json

# Set environment variables
log "Setting up environment variables..."
{
    echo "export CLOUDFLARE_AI_TUNNEL_ID=$AI_TUNNEL_ID"
    echo "export CLOUDFLARE_NEXTCLOUD_TUNNEL_ID=$NC_TUNNEL_ID"
} >> ~/.bashrc

# Also set for current session
export CLOUDFLARE_AI_TUNNEL_ID=$AI_TUNNEL_ID
export CLOUDFLARE_NEXTCLOUD_TUNNEL_ID=$NC_TUNNEL_ID

# Create DNS records
log "Creating DNS records..."
cloudflared tunnel route dns ai-tunnel c3p0.thebennett.net
cloudflared tunnel route dns nextcloud-tunnel scarif.thebennett.net

# Start services
log "Starting Cloudflare tunnel services..."
sudo systemctl enable --now cloudflared-ai
sudo systemctl enable --now cloudflared-nextcloud

# Wait for services to start
log "Waiting for services to initialize..."
sleep 15

# Pull default AI models (if Ollama is running)
log "Setting up default AI models..."
if systemctl is-active --quiet podman; then
    # Wait for Ollama to be ready
    timeout=30
    while ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1 && [ $timeout -gt 0 ]; do
        echo "Waiting for Ollama to start... ($timeout seconds remaining)"
        sleep 5
        ((timeout-=5))
    done
    
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        log "Pulling default AI models..."
        ai-pull-model llama2 &
        ai-pull-model codellama &
        wait
        log "Default models installed"
    else
        warn "Ollama not responding. You can manually pull models later with 'ai-pull-model'"
    fi
else
    warn "Podman not running. AI services may need manual startup."
fi

# Final status check
log "Checking service status..."
echo
echo "Service Status:"
echo "==============="
if command -v ai-status &> /dev/null; then
    ai-status
else
    echo "AI services: $(systemctl is-active podman || echo 'inactive')"
fi

echo
if command -v cf-tunnel-status &> /dev/null; then
    cf-tunnel-status
else
    echo "Cloudflare tunnels:"
    echo "  AI tunnel: $(systemctl is-active cloudflared-ai || echo 'inactive')"
    echo "  Nextcloud tunnel: $(systemctl is-active cloudflared-nextcloud || echo 'inactive')"
fi

echo
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo
echo "Your services should be available at:"
echo "  🤖 AI Services: https://c3p0.thebennett.net"
echo "  ☁️  Nextcloud:   https://scarif.thebennett.net"
echo
echo "Useful commands:"
echo "  ai-status              # Check AI services"
echo "  cf-tunnel-status       # Check tunnel status"
echo "  cf-test-endpoints      # Test connectivity"
echo "  ai-pull-model <name>   # Download AI models"
echo "  sudo nixos-rebuild switch  # Update system"
echo
echo "Troubleshooting:"
echo "  journalctl -u cloudflared-ai       # AI tunnel logs"
echo "  journalctl -u cloudflared-nextcloud # Nextcloud tunnel logs"
echo "  podman ps -a                       # Container status"
echo
echo "May the Force be with your deployments! ⭐"
EOF

    chmod +x /mnt/home/vader/post-install-setup.sh
    chown 1000:1000 /mnt/home/vader/post-install-setup.sh
    
    success "Post-install script created"
}

show_completion_message() {
    echo
    echo "=========================================="
    echo "  Installation Complete!"
    echo "=========================================="
    echo
    success "NixOS Deathstar Lab has been installed successfully!"
    echo
    log "Next steps:"
    echo "1. Reboot the system: sudo reboot"
    echo "2. Login as 'vader'"
    echo "3. Run the post-install setup: ./post-install-setup.sh"
    echo
    warn "Important reminders:"
    echo "  • Configure your Cloudflare account before running post-install"
    echo "  • Ensure your domain (thebennett.net) is managed by Cloudflare"
    echo "  • Test all services after setup completion"
    echo
    echo "Configuration summary:"
    echo "  SSD ($SSD_DEVICE): Boot + NixOS root"
    echo "  HDD ($HDD_DEVICE): AI model storage"
    echo "  NVME ($NVME_DEVICE): Nextcloud storage"
    echo
    echo "Service URLs (after post-install):"
    echo "  🤖 AI Services: https://c3p0.thebennett.net"
    echo "  ☁️  Nextcloud:   https://scarif.thebennett.net"
    echo
}

# Main execution flow
main() {
    # Pre-flight checks
    check_root
    check_nixos_installer
    check_internet
    check_devices
    
    # Show configuration
    log "NixOS Deathstar Lab Setup v$SCRIPT_VERSION"
    echo "Configuration repository: $CONFIG_REPO"
    echo "Dry run mode: $DRY_RUN"
    echo "Skip partitioning: $SKIP_PARTITIONING"
    echo "Force format: $FORCE_FORMAT"
    echo
    
    show_device_info
    
    # Confirm destructive operation
    if [ "$SKIP_PARTITIONING" != "true" ]; then
        confirm_destructive_operation
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log "DRY RUN MODE - No changes will be made"
        exit 0
    fi
    
    # Disk preparation
    unmount_all
    
    if [ "$SKIP_PARTITIONING" != "true" ]; then
        partition_ssd
        partition_hdd
        partition_nvme
        format_filesystems
    fi
    
    verify_labels
    mount_filesystems
    
    # NixOS setup
    generate_hardware_config
    download_configuration
    setup_secrets
    create_swap
    
    # Installation
    install_nixos
    setup_user
    create_post_install_script
    
    # Completion
    show_completion_message
    
    # Optional reboot
    echo
    read -p "Would you like to reboot now? (y/N): " reboot_choice
    if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
        log "Rebooting..."
        reboot
    else
        log "Remember to reboot before running the post-install script!"
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
