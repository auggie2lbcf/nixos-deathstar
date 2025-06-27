# NixOS Deathstar Networking Lab 🚀

> A comprehensive NixOS-based home lab featuring AI model hosting, cloud storage, and secure remote access via Cloudflare tunnels.

## 🎯 What You'll Build

- **🤖 AI Services Hub**: Ollama, Open WebUI, Text Generation WebUI, Stable Diffusion
- **☁️ Private Cloud**: Nextcloud with MySQL and Redis
- **🎮 Gaming Workstation**: KDE desktop with Steam and gaming optimizations
- **🔒 Secure Access**: Cloudflare tunnels (no open firewall ports)
- **📦 Container Platform**: Podman for service orchestration
- **💾 Optimized Storage**: SSD (OS), HDD (AI models), NVME (cloud storage)

## 📋 Hardware Requirements

### Required Storage Devices
- **SSD** (`/dev/sdb`) - 250GB+ for boot and NixOS root
- **HDD** (`/dev/sda`) - 1TB+ for AI model storage  
- **NVME** (`/dev/nvme0n1`) - 500GB+ for Nextcloud data

### Recommended Specs
- **CPU**: Intel/AMD with 8+ cores (AI workloads benefit from more cores)
- **RAM**: 32GB+ (AI models are memory-hungry)
- **GPU**: AMD Radeon (for gaming and AI acceleration)
- **Network**: Gigabit ethernet (for model downloads and streaming)

## 🌐 Prerequisites

### 1. Domain & Cloudflare Setup
- **Domain**: You need a domain (e.g., `yourdomain.com`) managed by Cloudflare
- **Cloudflare Account**: Free tier works fine
- **API Token**: Required for tunnel creation ([Get Token Guide](#cloudflare-api-token))

### 2. NixOS Installer
- Download latest NixOS ISO from [nixos.org](https://nixos.org/download.html)
- Create bootable USB drive
- Boot from installer

## 🚀 Quick Start Installation

### Step 1: Boot NixOS Installer
Boot from your NixOS installer USB and ensure you have internet connectivity.

### Step 2: Download and Run Setup Script
```bash
# Download the latest setup script
curl -L https://raw.githubusercontent.com/auggie2lbcf/nixos-deathstar/main/setup.sh -o setup.sh
chmod +x setup.sh

# Set your configuration repository (optional - uses default if not set)
export CONFIG_REPO="https://github.com/auggie2lbcf/nixos-deathstar.git"

# Run the installation
sudo ./setup.sh
```

### Step 3: Follow the Interactive Setup
The script will:
1. ✅ Validate your hardware and environment
2. 💽 Partition and format your storage devices
3. 📦 Download NixOS configuration files
4. 🔐 Securely collect your passwords and API tokens
5. 🔧 Install and configure NixOS
6. 🎯 Prepare post-installation setup

### Step 4: Reboot and Complete Setup
```bash
# After installation completes, reboot
sudo reboot

# Login as 'vader' (you'll set this password during installation)
# Run the post-installation script
./post-install-setup.sh
```

## 🔧 Advanced Installation Options

### Custom Device Configuration
```bash
# Override default device assignments
export SSD_DEVICE="/dev/nvme0n1"
export HDD_DEVICE="/dev/sdb" 
export NVME_DEVICE="/dev/sdc"
sudo ./setup.sh
```

### Test Mode (Dry Run)
```bash
# Test the script without making changes
export DRY_RUN=true
sudo ./setup.sh
```

### Resume Installation
```bash
# Skip partitioning if already done
export SKIP_PARTITIONING=true
sudo ./setup.sh
```

### Unattended Installation
```bash
# Skip confirmations (use with caution!)
export FORCE_FORMAT=true
sudo ./setup.sh
```

## 🔑 Required Secrets

During installation, you'll be prompted for:

### Cloudflare API Token
- **Purpose**: Creates secure tunnels for external access
- **How to get**: [Follow this guide](#cloudflare-api-token)
- **Permissions needed**: `Cloudflare Tunnel:Edit`, `DNS:Edit`, `Zone:Read`

### Nextcloud Admin Password
- **Purpose**: Admin login for your private cloud
- **Requirements**: Use a strong password
- **Usage**: Login to `https://yoursubdomain.yourdomain.com`

### Nextcloud Database Password  
- **Purpose**: MySQL database security
- **Requirements**: Use a different password than admin
- **Usage**: Handled automatically by the system

## 🌐 Service URLs

After successful setup, your services will be available at:

| Service | URL | Description |
|---------|-----|-------------|
| 🤖 **AI Hub** | `https://c3p0.yourdomain.com` | Open WebUI interface for AI models |
| ☁️ **Nextcloud** | `https://scarif.yourdomain.com` | Your private cloud storage |
| 🔧 **Ollama API** | `https://c3p0.yourdomain.com/ollama/` | Direct API access |
| 🎨 **Stable Diffusion** | `https://c3p0.yourdomain.com/sd/` | Image generation (manual start) |
| 📝 **Text Generation** | `https://c3p0.yourdomain.com/textgen/` | Advanced text models (manual start) |

## 🛠 Management Commands

### AI Services
```bash
# Check status of all AI services
ai-status

# Download new AI models
ai-pull-model llama2
ai-pull-model mistral
ai-pull-model codellama:13b

# Start optional services
ai-start-textgen    # Text Generation WebUI
ai-start-sd         # Stable Diffusion WebUI
```

### Cloudflare Tunnels
```bash
# Check tunnel connectivity
cf-tunnel-status

# Test all endpoints
cf-test-endpoints

# Restart tunnels if needed
cf-restart-tunnels

# Setup helper (if manual config needed)
cf-setup-tunnel
```

### System Management
```bash
# Update system configuration
sudo nixos-rebuild switch

# View service logs
journalctl -u cloudflared-ai
journalctl -u cloudflared-nextcloud
podman logs ollama

# Check system resources
htop
df -h
```

## 📁 Storage Layout

```
/                           # SSD - Fast OS and applications
├── boot/                   # EFI boot partition
├── nix/                    # Nix store (packages)
├── etc/nixos/              # System configuration
└── home/vader/             # User home directory

/mnt/ai-models/             # HDD - Large AI model storage
├── models/                 # Ollama models
├── stable-diffusion/       # SD models and outputs
├── text-generation/        # TextGen models
└── backups/                # AI model backups

/mnt/nextcloud/             # NVME - High-performance cloud storage
├── data/                   # Nextcloud user data
└── backups/                # Daily database backups
```

## 🔧 Customization

### Adding New AI Models
```bash
# List available models
curl http://localhost:11434/api/tags

# Download specific models
ai-pull-model mistral:7b
ai-pull-model llama2:70b
ai-pull-model codellama:python
```

### Changing Service Domains
1. Edit `/etc/nixos/services/cloudflare-tunnel.nix`
2. Update domain names in configuration
3. Rebuild: `sudo nixos-rebuild switch`
4. Update DNS records in Cloudflare

### Adding New Services
1. Create new service file in `/etc/nixos/services/`
2. Add container definition or service configuration
3. Import in `/etc/nixos/configuration.nix`
4. Rebuild and restart services

## 🛡 Security Features

- ✅ **Zero Open Ports**: All access via Cloudflare tunnels
- ✅ **Encrypted Storage**: Full disk encryption available
- ✅ **Secrets Management**: Passwords stored securely
- ✅ **Minimal Attack Surface**: Only required services enabled
- ✅ **Automatic Updates**: NixOS declarative configuration
- ✅ **Container Isolation**: Services run in isolated containers

## 🔄 Backup Strategy

### Automated Backups
- **Nextcloud**: Daily database and config backups
- **AI Models**: Weekly model backups (large files)
- **System Config**: Version controlled in git

### Manual Backup Commands
```bash
# Backup Nextcloud immediately
sudo systemctl start nextcloud-backup

# Backup AI models
sudo systemctl start ai-models-backup

# Export NixOS configuration
sudo tar -czf nixos-config-backup.tar.gz /etc/nixos/
```

## 🎮 Gaming Features

Included gaming setup:
- **Desktop**: KDE Plasma with gaming optimizations
- **Steam**: Full Steam client with Proton support
- **Performance**: GameMode and Gamescope for better performance
- **Monitoring**: MangoHud for FPS and system stats
- **Hardware**: AMD GPU drivers with Vulkan support

## 📚 Cloudflare API Token

### Getting Your Token
1. **Visit**: [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. **Create**: "Create Token"
3. **Template**: Use "Cloudflare Tunnels" template
4. **Configure**:
   - Token name: `NixOS Deathstar Lab`
   - Account: Your account
   - Zone: Your domain
5. **Permissions**:
   - Account: `Cloudflare Tunnel:Edit`
   - Zone: `DNS:Edit` + `Zone:Read`
6. **Copy**: Save the token (you only see it once!)

### Token Verification
```bash
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer YOUR_TOKEN_HERE" \
     -H "Content-Type:application/json"
```

## 🐛 Troubleshooting

### Common Issues

#### "Device not found" errors
```bash
# Check available devices
lsblk

# Override device paths
export SSD_DEVICE="/dev/your-ssd"
export HDD_DEVICE="/dev/your-hdd"
export NVME_DEVICE="/dev/your-nvme"
```

#### Tunnels not connecting
```bash
# Check tunnel status
cf-tunnel-status

# Restart tunnels
cf-restart-tunnels

# Check logs
journalctl -u cloudflared-ai
```

#### AI services not starting
```bash
# Check container status
podman ps -a

# Check AI service status
ai-status

# Restart AI services
sudo systemctl restart podman
```

#### Mount failures
```bash
# Check filesystem labels
ls -la /dev/disk/by-label/

# Check mounts
df -h | grep mnt

# Remount if needed
sudo mount -a
```

### Getting Help

1. **Check logs**: `journalctl -xe`
2. **Verify config**: `sudo nixos-rebuild dry-run`
3. **Test connectivity**: `cf-test-endpoints`
4. **Resource usage**: `htop` and `df -h`

## 🔄 Updates and Maintenance

### System Updates
```bash
# Update NixOS
sudo nixos-rebuild switch

# Update containers
podman auto-update
```

### Configuration Changes
1. Edit files in `/etc/nixos/`
2. Test: `sudo nixos-rebuild dry-run`
3. Apply: `sudo nixos-rebuild switch`

### Model Management
```bash
# Clean old models
ollama rm old-model-name

# Update to newer versions
ai-pull-model llama2:latest
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Test your changes thoroughly
4. Submit pull request with clear description

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **NixOS Community** for the excellent declarative OS
- **Ollama Team** for making AI models accessible
- **Cloudflare** for secure tunnel technology
- **Open Source Contributors** for all the amazing tools

---

## 🚀 Ready to Deploy?

```bash
curl -L https://raw.githubusercontent.com/auggie2lbcf/nixos-deathstar/main/setup.sh | sudo bash
```

**May the Force be with your deployments!** ⭐

---

*Last updated: $(date +%Y-%m-%d) | Version: 2.0*
