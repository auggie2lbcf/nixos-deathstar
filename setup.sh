#!/bin/bash
# NixOS Deathstar Lab Setup Script
# Run this script after booting from NixOS installer

set -e

echo "=========================================="
echo "  NixOS Deathstar Lab Setup Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run this script as root"
fi

# Step 1: Partition and format disks
log "Setting up disk partitions..."

# Unmount any existing mounts
umount -R /mnt 2>/dev/null || true

# Partition SSD (/dev/sdb) - Boot and main NixOS
log "Partitioning SSD (/dev/sdb)..."
parted /dev/sdb --script mklabel gpt
parted /dev/sdb --script mkpart ESP fat32 1MiB 512MiB
parted /dev/sdb --script set 1 esp on
parted /dev/sdb --script mkpart primary ext4 512MiB 100%

# Format SSD partitions
mkfs.fat -F 32 -n boot /dev/sdb1
mkfs.ext4 -L nixos-root /dev/sdb2

# Format HDD (/dev/sda) - AI model storage
log "Formatting HDD (/dev/sda) for AI models..."
parted /dev/sda --script mklabel gpt
parted /dev/sda --script mkpart primary ext4 1MiB 100%
mkfs.ext4 -L ai-storage /dev/sda1

# Format NVME (/dev/nvme0n1) - Nextcloud storage
log "Formatting NVME (/dev/nvme0n1) for Nextcloud..."
parted /dev/nvme0n1 --script mklabel gpt
parted /dev/nvme0n1 --script mkpart primary ext4 1MiB 100%
mkfs.ext4 -L nextcloud-storage /dev/nvme0n1p1

# Step 2: Mount filesystems
log "Mounting filesystems..."
mount /dev/disk/by-label/nixos-root /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot

mkdir -p /mnt/mnt/ai-models
mount /dev/disk/by-label/ai-storage /mnt/mnt/ai-models

mkdir -p /mnt/mnt/nextcloud
mount /dev/disk/by-label/nextcloud-storage /mnt/mnt/nextcloud

# Step 3: Generate hardware configuration
log "Generating hardware configuration..."
nixos-generate-config --root /mnt

# Step 4: Download and setup configuration files
log "Setting up NixOS configuration..."

# Create configuration directory structure
mkdir -p /mnt/etc/nixos/services

# Download configuration files (assuming they're in a git repo or provided)
if [ -n "$CONFIG_REPO" ]; then
    log "Cloning configuration from $CONFIG_REPO..."
    git clone "$CONFIG_REPO" /tmp/nixos-config
    cp -r /tmp/nixos-config/* /mnt/etc/nixos/
else
    warn "No CONFIG_REPO specified. Please manually copy configuration files."
    warn "Expected files:"
    warn "  - /mnt/etc/nixos/configuration.nix"
    warn "  - /mnt/etc/nixos/services/nextcloud.nix"
    warn "  - /mnt/etc/nixos/services/ai-models.nix"
    warn "  - /mnt/etc/nixos/services/cloudflare-tunnel.nix"
    read -p "Press Enter when configuration files are in place..."
fi

# Step 5: Setup secrets directory
log "Setting up secrets..."
mkdir -p /mnt/run/secrets

# Prompt for required secrets
echo
echo "Please provide the following secrets:"

read -s -p "Cloudflare API Token: " CF_TOKEN
echo
echo "$CF_TOKEN" > /mnt/run/secrets/cloudflare-token

read -s -p "Nextcloud Admin Password: " NC_PASS
echo
echo "$NC_PASS" > /mnt/run/secrets/nextcloud-admin-pass

read -s -p "Nextcloud Database Password: " NC_DB_PASS
echo
echo "$NC_DB_PASS" > /mnt/run/secrets/nextcloud-db-pass

# Set proper permissions
chmod 600 /mnt/run/secrets/*

# Step 6: Create swap file
log "Creating swap file..."
dd if=/dev/zero of=/mnt/swapfile bs=1M count=16384
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile

# Step 7: Install NixOS
log "Installing NixOS..."
nixos-install --root /mnt

# Step 8: Set user password
log "Setting up user password..."
echo "Please set password for user 'vader':"
nixos-enter --root /mnt -c "passwd vader"

# Step 9: Create post-install setup script
log "Creating post-install setup script..."
cat > /mnt/home/vader/post-install-setup.sh << 'EOF'
#!/bin/bash
# Post-install setup script for Deathstar lab

echo "=========================================="
echo "  Post-Install Setup"
echo "=========================================="

# Update system
sudo nixos-rebuild switch

# Setup Cloudflare tunnels
echo "Setting up Cloudflare tunnels..."
echo "1. Login to Cloudflare:"
cloudflared tunnel login

echo "2. Create tunnels:"
AI_TUNNEL_ID=$(cloudflared tunnel create ai-tunnel | grep -o '[a-f0-9-]\{36\}')
NC_TUNNEL_ID=$(cloudflared tunnel create nextcloud-tunnel | grep -o '[a-f0-9-]\{36\}')

echo "AI Tunnel ID: $AI_TUNNEL_ID"
echo "Nextcloud Tunnel ID: $NC_TUNNEL_ID"

# Copy credentials
sudo cp ~/.cloudflared/$AI_TUNNEL_ID.json /run/secrets/cloudflare-ai-tunnel.json
sudo cp ~/.cloudflared/$NC_TUNNEL_ID.json /run/secrets/cloudflare-nextcloud-tunnel.json
sudo chmod 600 /run/secrets/cloudflare-*-tunnel.json

# Set environment variables
echo "export CLOUDFLARE_AI_TUNNEL_ID=$AI_TUNNEL_ID" >> ~/.bashrc
echo "export CLOUDFLARE_NEXTCLOUD_TUNNEL_ID=$NC_TUNNEL_ID" >> ~/.bashrc
source ~/.bashrc

# Create DNS records
cloudflared tunnel route dns ai-tunnel c3p0.thebennett.net
cloudflared tunnel route dns nextcloud-tunnel scarif.thebennett.net

# Start services
sudo systemctl enable --now cloudflared-ai
sudo systemctl enable --now cloudflared-nextcloud

# Pull default AI models
sleep 10  # Wait for services to start
ai-pull-model llama2
ai-pull-model codellama

echo "Setup complete!"
echo "Services available at:"
echo "  - AI: https://c3p0.thebennett.net"
echo "  - Nextcloud: https://scarif.thebennett.net"
echo
echo "Useful commands:"
echo "  - ai-status: Check AI services status"
echo "  - cf-tunnel-status: Check tunnel status"
echo "  - cf-test-endpoints: Test connectivity"
EOF

chmod +x /mnt/home/vader/post-install-setup.sh
chown 1000:1000 /mnt/home/vader/post-install-setup.sh

# Step 10: Final instructions
echo
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo
log "NixOS has been installed successfully!"
log "Please reboot and run the post-install setup:"
echo
echo "1. Reboot the system"
echo "2. Login as 'vader'"
echo "3. Run: ./post-install-setup.sh"
echo
warn "Don't forget to:"
warn "  - Configure your Cloudflare account"
warn "  - Update DNS settings if needed"
warn "  - Test all services after setup"
echo
read -p "Press Enter to reboot..." 
reboot
