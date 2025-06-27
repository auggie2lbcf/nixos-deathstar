# NixOS Configuration for Deathstar Networking Lab
# File: /etc/nixos/configuration.nix

{ config, pkgs, lib, ... }:

let
  # Load secrets from environment or files
  secrets = {
    cloudflareToken = builtins.getEnv "CLOUDFLARE_TOKEN";
    nextcloudAdminPass = builtins.getEnv "NEXTCLOUD_ADMIN_PASS";
    aiApiKey = builtins.getEnv "AI_API_KEY";
  };
in

{
  imports = [
    ./hardware-configuration.nix
    ./services/nextcloud.nix
    ./services/ai-models.nix
    ./services/cloudflare-tunnel.nix
  ];

  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    
    # Support for multiple file systems
    supportedFilesystems = [ "ext4" "btrfs" "ntfs" ];
    
    # Kernel parameters for gaming and performance
    kernelParams = [
      "amd_pstate=active"
      "video=1920x1080@144"
    ];
    
    # Latest kernel for best hardware support
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # File systems configuration
  fileSystems = {
    # SSD - Boot and main NixOS (/dev/sdb)
    "/" = {
      device = "/dev/disk/by-label/nixos-root";
      fsType = "ext4";
      options = [ "noatime" ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };

    # HDD - AI model storage (/dev/sda)
    "/mnt/ai-models" = {
      device = "/dev/disk/by-label/ai-storage";
      fsType = "ext4";
      options = [ "noatime" "user" "exec" ];
    };

    # NVME - Nextcloud storage (/dev/nvme0n1)
    "/mnt/nextcloud" = {
      device = "/dev/disk/by-label/nextcloud-storage";
      fsType = "ext4";
      options = [ "noatime" "user" "exec" ];
    };
  };

  # Swap configuration
  swapDevices = [
    { device = "/swapfile"; size = 16384; } # 16GB swap file
  ];

  # Networking configuration
  networking = {
    hostName = "deathstar";
    networkmanager.enable = true;
    
    # Open required ports
    firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 8080 22 ];
      allowedUDPPorts = [ 53 ];
    };
  };

  # Time zone and locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # X11 and Desktop Environment
  services.xserver = {
    enable = true;
    displayManager.sddm.enable = true;
    desktopManager.plasma5.enable = true;
    
    # AMD GPU configuration
    videoDrivers = [ "amdgpu" ];
    
    # Keyboard layout
    layout = "us";
    xkbVariant = "";
  };

  # Gaming optimizations
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
    
    gamemode.enable = true;
    gamescope.enable = true;
  };

  # Hardware configuration
  hardware = {
    # AMD GPU support
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
    
    # Bluetooth
    bluetooth.enable = true;
  };

  # Audio with PipeWire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Virtualization and containers
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    
    # Enable nested virtualization
    libvirtd.enable = true;
  };

  # User configuration
  users.users.vader = {
    isNormalUser = true;
    description = "Vader";
    extraGroups = [ 
      "networkmanager" 
      "wheel" 
      "audio" 
      "video" 
      "storage" 
      "podman"
      "libvirtd"
    ];
    shell = pkgs.zsh;
  };

  # Enable sudo without password for convenience (lab environment)
  security.sudo.wheelNeedsPassword = false;

  # System packages
  environment.systemPackages = with pkgs; [
    # System utilities
    vim
    wget
    curl
    git
    htop
    btop
    neofetch
    tree
    unzip
    p7zip
    
    # Networking tools
    nmap
    wireshark
    tcpdump
    netcat
    
    # Development
    docker-compose
    podman-compose
    
    # Gaming
    lutris
    heroic
    mangohud
    
    # Desktop applications
    firefox
    discord
    vscode
    
    # AI/ML tools
    python3
    python3Packages.pip
    python3Packages.torch
    python3Packages.transformers
    
    # Cloudflare
    cloudflared
  ];

  # Shell configuration
  programs.zsh.enable = true;

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  # Auto-mount USB devices
  services.udisks2.enable = true;

  # Enable CUPS for printing
  services.printing.enable = true;

  # System state version
  system.stateVersion = "23.11";

  # Environment variables for secrets
  environment.variables = {
    CLOUDFLARE_TOKEN_FILE = "/run/secrets/cloudflare-token";
    NEXTCLOUD_ADMIN_PASS_FILE = "/run/secrets/nextcloud-admin-pass";
  };

  # Create directories for services
  systemd.tmpfiles.rules = [
    "d /mnt/ai-models 0755 vader users"
    "d /mnt/nextcloud 0755 nextcloud nextcloud"
    "d /var/lib/ai-models 0755 vader users"
    "d /run/secrets 0755 root root"
  ];
}