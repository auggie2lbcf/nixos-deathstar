# NixOS Deathstar Networking Lab

A comprehensive NixOS configuration for a gaming workstation with AI model hosting and Nextcloud, all accessible via Cloudflare tunnels.

## 🎯 Features

- **Gaming Setup**: Full KDE desktop with AMD GPU support, Steam, and gaming optimizations
- **AI Model Hosting**: Ollama, Open WebUI, Text Generation WebUI, and Stable Diffusion
- **Cloud Storage**: Nextcloud with MySQL backend and Redis caching
- **Secure Access**: Cloudflare tunnels for secure external access
- **Container Management**: Podman for reproducible deployments
- **Storage Layout**: Optimized for SSD (OS), HDD (AI models), and NVME (Nextcloud)

## 📋 Prerequisites

- NixOS installer ISO
- Three storage devices:
  - SSD (`/dev/sdb`) - Boot and main OS
  - HDD (`/dev/sda`) - AI model storage
  - NVME (`/dev/nvme0n1`) - Nextcloud storage
- Cloudflare account with domain `thebennett.net`
- AMD Radeon graphics card
- Intel processor

## 🚀 Quick Setup

### 1. Boot from NixOS installer

### 2. Download and run the setup script

```bash
# Download the setup script
curl -L https://raw.githubusercontent.com/yourusername/nixos-deathstar/main/setup.sh -o setup.sh
chmod +x setup.sh

# Set configuration repository (optional)
export CONFIG_REPO="https://github.com/yourusername/nixos-deathstar.git"

# Run setup
sudo ./setup.sh
```

### 3. Manual setup (if not using the script)

```bash
# Partition disks
sudo parted /dev/sdb --script mklabel gpt
sudo parted /dev/sdb --script mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/sdb --script set 1 esp on
sudo parted /dev/sdb --script mkpart primary ext4 512MiB 100%

# Format partitions
sudo mkfs.fat -F 32 -n boot /dev/sdb1
sudo mkfs.ext4 -L nixos-root /dev/sdb2
sudo mkfs.ext4 -L ai-storage /dev/sda
sudo mkfs.ext4 -L nextcloud-storage /dev/nvme0n1p1

# Mount filesystems
sudo mount /dev/disk/by-label/nixos-root /mnt
sudo mkdir -p /mnt/boot /mnt/mnt/ai-models /mnt/mnt/nextcloud
sudo mount /dev/disk/by-label/boot /mnt/boot
sudo mount /dev/disk/by-label/ai-storage /mnt/mnt/ai-models
sudo mount /dev/disk/by-label/nextcloud-storage /mnt/mnt/nextcloud

# Generate config and install
sudo nixos-generate-config --root /mnt
# Copy configuration files to /mnt/etc/nixos/
sudo nixos-install
```

## 🔑 Secret Management

Create these files in `/run/secrets/` (or set as environment variables):

```bash
# Cloudflare API token
echo "your-cloudflare-token" | sudo tee /run/secrets/cloudflare-token

# Nextcloud admin password
echo "your-secure-password" | sudo tee /run/secrets/nextcloud-admin-pass

# Nextcloud database password
echo "your-db-password" | sudo tee /run/secrets/nextcloud-db-pass
```

Set environment variables for tunnel IDs:
```bash
export CLOUDFLARE_AI_TUNNEL_ID="your-ai-tunnel-id"
export CLOUDFLARE_NEXTCLOUD_TUNNEL_ID="your-nextcloud-tunnel-id"
```

## 🌐 Service URLs

After setup, your services will be available at:

- **AI Services**: https://c3p0.thebennett.net
  - Main interface: Open WebUI
  - Ollama API: `/ollama/`
  - Text Generation: `/textgen/` (manual start)
  - Stable Diffusion: `/sd/` (manual start)
- **Nextcloud**: https://scarif.thebennett.net

## 🛠 Management Commands

### AI Services
```bash
# Check AI services status
ai-status

# Pull a new model
ai-pull-model llama2

# Start Text Generation WebUI
ai-start-textgen

# Start Stable Diffusion WebUI
ai-start-sd
```

### Cloudflare Tunnels
```bash
# Check tunnel status
cf-tunnel-status

# Restart tunnels
cf-restart-tunnels

# Test endpoints
cf-test-endpoints

# Setup helper
cf-setup-tunnel
```

### System Management
```bash
# Update system
sudo nixos-rebuild switch

# Check all services
systemctl status

# View logs
journalctl -u cloudflared-ai
journalctl -u nextcloud-mysql-backup
```

## 📁 Directory Structure

```
/
├── mnt/
│   ├── ai-models/          # HDD - AI model storage
│   │   ├── models/         # Ollama models
│   │   ├── stable-diffusion/
│   │   ├── text-generation/
│   │   └── backups/
│   └── nextcloud/          # NVME - Nextcloud storage
│       ├── data/
│       └── backups/
├── etc/nixos/
│   ├── configuration.nix
│   └── services/
│       ├── nextcloud.nix
│       ├── ai-models.nix
│       └── cloudflare-tunnel.nix
└── run/secrets/            # Sensitive configuration
    ├── cloudflare-token
    ├── nextcloud-admin-pass
    └── tunnel credentials
```

## 🔧 Customization

### Adding New AI Models

```bash
# List available models
curl http://localhost:11434/api/tags

# Pull a specific model
ai-pull-model mistral
ai-pull-model codellama:13b
```

### Modifying Services

Edit the respective configuration files in `/etc/nixos/services/` and rebuild:

```bash
sudo nixos-rebuild switch
```

### Changing Domains

Update the domain names in:
- `services/cloudflare-tunnel.nix`
- `services/nextcloud.nix`
- `services/ai-models.nix`

## 🛡 Security Considerations

- All external access goes through Cloudflare tunnels (no open ports)
- Secrets are managed externally (not hardcoded)
- Services run with minimal privileges
- Regular automated backups
- Firewall enabled with minimal open ports

## 🔄 Backup Strategy

### Automated Backups
- **Nextcloud**: Daily database and config backups
- **AI Models**: Weekly model backups (configurable)
- **System**: Use `nixos-rebuild` for system state

### Manual Backup
```bash
# Backup Nextcloud
sudo systemctl start nextcloud-backup

# Backup AI models
sudo systemctl start ai-models-backup

# Create system snapshot
sudo nixos-rebuild build
```

## 🎮 Gaming Setup

The configuration includes:
- KDE Plasma desktop environment
- Steam with Proton support
- GameMode for performance optimization
- Gamescope for containerized gaming
- AMD GPU drivers with Vulkan support
- MangoHud for performance monitoring

## 🐛 Troubleshooting

### Common Issues

1. **Tunnels not connecting**
   ```bash
   cf-tunnel-status
   sudo systemctl restart cloudflared-ai cloudflared-nextcloud
   ```

2. **AI services not starting**
   ```bash
   podman ps -a
   podman logs ollama
   ai-status
   ```

3. **Nextcloud issues**
   ```bash
   sudo systemctl status nextcloud-mysql-backup
   sudo -u nextcloud nextcloud-occ status
   ```

4. **Storage issues**
   ```bash
   df -h
   sudo mount -a
   ```

### Log Locations
- Cloudflare tunnels: `/var/log/cloudflared/`
- Nextcloud: `journalctl -u phpfpm-nextcloud`
- AI services: `podman logs <container-name>`
- System: `journalctl -xe`

## 📚 References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Ollama Documentation](https://ollama.ai/docs)
- [Nextcloud Admin Manual](https://docs.nextcloud.com/server/latest/admin_manual/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This configuration is provided as-is under the MIT License. Use at your own risk.

---

**May the Force be with your deployments!** ⭐️