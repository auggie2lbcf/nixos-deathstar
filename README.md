# NixOS Deathstar Networking Lab 🚀

> **Easy Setup Version 3.0** - A comprehensive NixOS-based home lab featuring AI model hosting, cloud storage, and secure remote access via Cloudflare tunnels.

## 🎯 What You'll Get

- **🤖 AI Services Hub**: Ollama + Open WebUI for ChatGPT-like interface
- **☁️ Private Cloud**: Nextcloud with MySQL and Redis
- **🎮 Gaming Workstation**: KDE desktop with Steam support
- **🔒 Secure Access**: Cloudflare tunnels (no firewall configuration needed)
- **📦 Container Platform**: Podman for service orchestration
- **🛠️ Easy Management**: Simple commands for all operations

## 🚀 Super Easy Installation

### Step 1: Install NixOS Normally
1. Download NixOS ISO from [nixos.org](https://nixos.org/download.html)
2. Boot from USB and run the **graphical installer**
3. Install NixOS normally with your preferred settings
4. Reboot into your new NixOS system

### Step 2: Run the Easy Setup Script
```bash
# Download and run the setup script
curl -L https://raw.githubusercontent.com/yourusername/nixos-deathstar/main/easy-setup.sh -o easy-setup.sh
chmod +x easy-setup.sh
./easy-setup.sh
```

**That's it!** The script handles everything else automatically.

## 📋 What You'll Need

### Required Information
- **Domain Name**: Any domain managed by Cloudflare (free tier works)
- **Cloudflare API Token**: Get from [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
- **Passwords**: Admin password for Nextcloud and database

### Hardware (Flexible)
- **CPU**: Any modern processor (8+ cores recommended for AI)
- **RAM**: 16GB minimum, 32GB+ recommended
- **Storage**: Works with any storage configuration
  - Single drive: Everything on main drive
  - Multiple drives: Optional setup for dedicated AI/Nextcloud storage
- **GPU**: Optional AMD/NVIDIA for better AI performance

## 🔑 Getting Your Cloudflare API Token

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Use "Cloudflare Tunnels" template or create custom with:
   - **Account**: `Cloudflare Tunnel:Edit`
   - **Zone**: `DNS:Edit` + `Zone:Read`
4. Save the token (you only see it once!)

## 🎮 What Gets Installed

### Core Services
- **Ollama**: Local AI model hosting
- **Open WebUI**: ChatGPT-like web interface
- **Nextcloud**: Your private cloud storage
- **Cloudflare Tunnels**: Secure external access

### Optional Gaming Setup
- **KDE Plasma**: Modern desktop environment
- **Steam**: Full gaming platform with Proton
- **Gaming Tools**: MangoHud, GameMode for performance

### Development Tools
- **Podman**: Container management
- **Git, Python**: Development essentials
- **System Tools**: htop, btop, monitoring tools

## 🌐 Service URLs

After setup, access your services at:

| Service | URL | Description |
|---------|-----|-------------|
| 🤖 **AI Chat** | `https://c3p0.yourdomain.com` | ChatGPT-like interface |
| ☁️ **Nextcloud** | `https://scarif.yourdomain.com` | Private cloud storage |

## 🛠 Management Commands

The setup creates simple commands for managing your lab:

### Main Management
```bash
deathstar-manage status    # Check all services
deathstar-manage restart   # Restart everything
deathstar-manage logs      # View recent logs
deathstar-manage update    # Update system
```

### AI Management
```bash
ai-status                  # Check AI services
ai-pull-model llama2       # Download AI models
ai-pull-model codellama    # Download coding assistant
ai-pull-model mistral      # Download Mistral model
```

### Cloudflare Management
```bash
cf-tunnel-status          # Check tunnel status
cf-test-endpoints         # Test connectivity
cf-restart-tunnels        # Restart tunnels
```

## 📁 Storage Options

The setup automatically detects your storage and offers options:

### Option 1: Single Drive (Default)
- Everything on your main NixOS drive
- Perfect for most home labs
- Automatically creates organized directories

### Option 2: Multiple Drives
- Dedicated drive for AI models (large files)
- Dedicated drive for Nextcloud (fast access)
- Setup wizard guides you through the process

### Option 3: Custom Setup
- Use existing partitions
- Mix of local and network storage
- Advanced users can customize paths

## 🔧 Customization

### Adding AI Models
```bash
# Popular models to try
ai-pull-model llama2:7b        # General chat (4GB)
ai-pull-model codellama:7b     # Code assistant (4GB)
ai-pull-model mistral:7b       # Fast and capable (4GB)
ai-pull-model llama2:13b       # Better quality (7GB)
ai-pull-model dolphin-mistral  # Uncensored model (4GB)
```

### Changing Domains
1. Edit `/etc/nixos/services/*.nix` files
2. Update your domain name
3. Run: `sudo nixos-rebuild switch`
4. Update DNS records in Cloudflare

### Adding Services
The modular design makes it easy to add new services:
1. Create service file in `/etc/nixos/services/`
2. Import in `/etc/nixos/configuration.nix`
3. Rebuild: `sudo nixos-rebuild switch`

## 🛡 Security Features

- ✅ **Zero Open Ports**: All access via Cloudflare tunnels
- ✅ **Encrypted Tunnels**: All traffic secured by Cloudflare
- ✅ **Isolated Services**: Containers provide separation
- ✅ **Secure Secrets**: Passwords stored safely
- ✅ **Automatic Updates**: Easy system maintenance

## 🔄 Backup & Maintenance

### Automatic Backups
- **Nextcloud**: Daily database and config backups
- **AI Models**: Weekly backups (models are large)
- **System Config**: Version controlled via git

### Manual Maintenance
```bash
# Update everything
deathstar-manage update

# Backup now
sudo systemctl start next
