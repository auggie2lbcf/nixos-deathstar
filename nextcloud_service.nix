# Nextcloud Service Configuration
# File: /etc/nixos/services/nextcloud.nix

{ config, pkgs, lib, ... }:

{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud28;
    hostName = "scarif.thebennett.net";
    
    # Use external storage
    datadir = "/mnt/nextcloud/data";
    
    config = {
      # Database configuration
      dbtype = "mysql";
      dbname = "nextcloud";
      dbuser = "nextcloud";
      dbpassFile = "/run/secrets/nextcloud-db-pass";
      
      # Admin user
      adminuser = "vader";
      adminpassFile = "/run/secrets/nextcloud-admin-pass";
      
      # Trusted domains
      extraTrustedDomains = [ 
        "scarif.thebennett.net"
        "localhost"
        "127.0.0.1"
      ];
    };

    # Additional settings
    settings = {
      # Performance tuning
      "memcache.local" = "\\OC\\Memcache\\APCu";
      "memcache.redis" = "\\OC\\Memcache\\Redis";
      
      # File handling
      "max_input_time" = 3600;
      "max_execution_time" = 3600;
      "post_max_size" = "16G";
      "upload_max_filesize" = "16G";
      
      # Security
      "overwriteprotocol" = "https";
      "trusted_proxies" = [ "127.0.0.1" ];
    };
  };

  # MySQL database for Nextcloud
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    
    initialDatabases = [
      { name = "nextcloud"; }
    ];
    
    initialScript = pkgs.writeText "mysql-init.sql" ''
      CREATE USER IF NOT EXISTS 'nextcloud'@'localhost' IDENTIFIED BY 'nextcloud_password';
      GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
      FLUSH PRIVILEGES;
    '';
  };

  # Redis for caching
  services.redis.servers.nextcloud = {
    enable = true;
    port = 6379;
  };

  # Nginx reverse proxy
  services.nginx = {
    enable = true;
    
    virtualHosts."scarif.thebennett.net" = {
      forceSSL = false; # Let Cloudflare handle SSL
      
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.nextcloud.port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          
          # Increase timeouts for large file uploads
          proxy_connect_timeout 600;
          proxy_send_timeout 600;
          proxy_read_timeout 600;
          send_timeout 600;
          
          # Increase max body size
          client_max_body_size 16G;
        '';
      };
    };
  };

  # Podman container for additional Nextcloud apps (if needed)
  virtualisation.oci-containers.containers.nextcloud-redis = {
    image = "redis:alpine";
    autoStart = false; # Using system redis instead
  };

  # Backup script
  systemd.services.nextcloud-backup = {
    description = "Nextcloud Backup";
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      ExecStart = pkgs.writeShellScript "nextcloud-backup" ''
        #!/bin/bash
        BACKUP_DIR="/mnt/nextcloud/backups"
        DATE=$(date +%Y%m%d_%H%M%S)
        
        mkdir -p "$BACKUP_DIR"
        
        # Backup database
        ${pkgs.mariadb}/bin/mysqldump nextcloud > "$BACKUP_DIR/nextcloud_db_$DATE.sql"
        
        # Backup config
        cp -r ${config.services.nextcloud.home}/config "$BACKUP_DIR/config_$DATE"
        
        # Keep only last 7 backups
        find "$BACKUP_DIR" -name "nextcloud_db_*" -mtime +7 -delete
        find "$BACKUP_DIR" -name "config_*" -mtime +7 -delete
      '';
    };
  };

  # Run backup daily
  systemd.timers.nextcloud-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}