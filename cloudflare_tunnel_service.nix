# Cloudflare Tunnel Service Configuration
# File: /etc/nixos/services/cloudflare-tunnel.nix

{ config, pkgs, lib, ... }:

{
  # Cloudflare tunnel service
  services.cloudflared = {
    enable = true;
    
    tunnels = {
      # Tunnel for AI services (c3p0.thebennett.net)
      "ai-tunnel" = {
        credentialsFile = "/run/secrets/cloudflare-ai-tunnel.json";
        default = "http_status:404";
        
        ingress = {
          "c3p0.thebennett.net" = "http://localhost:3000";
          # Fallback
          "*" = "http_status:404";
        };
      };
      
      # Tunnel for Nextcloud (scarif.thebennett.net)
      "nextcloud-tunnel" = {
        credentialsFile = "/run/secrets/cloudflare-nextcloud-tunnel.json";
        default = "http_status:404";
        
        ingress = {
          "scarif.thebennett.net" = "http://localhost:80";
          # Fallback
          "*" = "http_status:404";
        };
      };
    };
  };

  # Alternative: Manual cloudflared setup with systemd services
  systemd.services.cloudflared-ai = {
    description = "Cloudflare Tunnel for AI Services";
    after = [ "network.target"   ];

  # Environment variables for tunnel IDs (loaded from secrets)
  environment.variables = {
    CLOUDFLARE_AI_TUNNEL_ID = builtins.getEnv "CLOUDFLARE_AI_TUNNEL_ID";
    CLOUDFLARE_NEXTCLOUD_TUNNEL_ID = builtins.getEnv "CLOUDFLARE_NEXTCLOUD_TUNNEL_ID";
  };

  # Ensure secrets directory exists and has correct permissions
  systemd.tmpfiles.rules = [
    "d /run/secrets 0755 root root"
    "d /etc/cloudflared 0755 cloudflared cloudflared"
    "d /var/log/cloudflared 0755 cloudflared cloudflared"
  ];
}
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      User = "cloudflared";
      Group = "cloudflared";
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --config /etc/cloudflared/ai-config.yml run";
      Restart = "always";
      RestartSec = "5s";
      
      # Security settings
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/log/cloudflared" ];
    };
    
    preStart = ''
      # Create config directory
      mkdir -p /etc/cloudflared
      mkdir -p /var/log/cloudflared
      chown cloudflared:cloudflared /var/log/cloudflared
      
      # Create AI tunnel config if it doesn't exist
      if [ ! -f /etc/cloudflared/ai-config.yml ]; then
        cat > /etc/cloudflared/ai-config.yml << 'EOF'
tunnel: $CLOUDFLARE_AI_TUNNEL_ID
credentials-file: /run/secrets/cloudflare-ai-tunnel.json

ingress:
  - hostname: c3p0.thebennett.net
    service: http://localhost:3000
  - hostname: "*.c3p0.thebennett.net"
    service: http://localhost:3000
  - service: http_status:404

logfile: /var/log/cloudflared/ai-tunnel.log
loglevel: info
EOF
      fi
    '';
  };

  systemd.services.cloudflared-nextcloud = {
    description = "Cloudflare Tunnel for Nextcloud";
    after = [ "network.target" "nginx.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      User = "cloudflared";
      Group = "cloudflared";
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --config /etc/cloudflared/nextcloud-config.yml run";
      Restart = "always";
      RestartSec = "5s";
      
      # Security settings
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/log/cloudflared" ];
    };
    
    preStart = ''
      # Create nextcloud tunnel config if it doesn't exist
      if [ ! -f /etc/cloudflared/nextcloud-config.yml ]; then
        cat > /etc/cloudflared/nextcloud-config.yml << 'EOF'
tunnel: $CLOUDFLARE_NEXTCLOUD_TUNNEL_ID
credentials-file: /run/secrets/cloudflare-nextcloud-tunnel.json

ingress:
  - hostname: scarif.thebennett.net
    service: http://localhost:80
  - hostname: "*.scarif.thebennett.net"
    service: http://localhost:80
  - service: http_status:404

logfile: /var/log/cloudflared/nextcloud-tunnel.log
loglevel: info
EOF
      fi
    '';
  };

  # Create cloudflared user
  users.users.cloudflared = {
    group = "cloudflared";
    isSystemUser = true;
    home = "/var/lib/cloudflared";
    createHome = true;
  };
  
  users.groups.cloudflared = {};

  # Helper scripts for tunnel management
  environment.systemPackages = with pkgs; [
    cloudflared
    
    (writeShellScriptBin "cf-tunnel-status" ''
      echo "=== Cloudflare Tunnel Status ==="
      echo "AI Tunnel (c3p0.thebennett.net):"
      systemctl status cloudflared-ai --no-pager -l
      echo
      echo "Nextcloud Tunnel (scarif.thebennett.net):"
      systemctl status cloudflared-nextcloud --no-pager -l
      echo
      echo "=== Tunnel Logs ==="
      echo "AI Tunnel logs:"
      tail -n 10 /var/log/cloudflared/ai-tunnel.log 2>/dev/null || echo "No AI tunnel logs found"
      echo
      echo "Nextcloud Tunnel logs:"
      tail -n 10 /var/log/cloudflared/nextcloud-tunnel.log 2>/dev/null || echo "No Nextcloud tunnel logs found"
    '')
    
    (writeShellScriptBin "cf-restart-tunnels" ''
      echo "Restarting Cloudflare tunnels..."
      systemctl restart cloudflared-ai
      systemctl restart cloudflared-nextcloud
      echo "Tunnels restarted!"
    '')
    
    (writeShellScriptBin "cf-setup-tunnel" ''
      echo "Cloudflare Tunnel Setup Helper"
      echo "==============================="
      echo
      echo "1. First, login to Cloudflare:"
      echo "   cloudflared tunnel login"
      echo
      echo "2. Create tunnels:"
      echo "   cloudflared tunnel create ai-tunnel"
      echo "   cloudflared tunnel create nextcloud-tunnel"
      echo
      echo "3. Copy the tunnel credentials to /run/secrets/:"
      echo "   cp ~/.cloudflared/<tunnel-id>.json /run/secrets/cloudflare-ai-tunnel.json"
      echo "   cp ~/.cloudflared/<tunnel-id>.json /run/secrets/cloudflare-nextcloud-tunnel.json"
      echo
      echo "4. Set the tunnel IDs in environment variables:"
      echo "   export CLOUDFLARE_AI_TUNNEL_ID=<ai-tunnel-id>"
      echo "   export CLOUDFLARE_NEXTCLOUD_TUNNEL_ID=<nextcloud-tunnel-id>"
      echo
      echo "5. Create DNS records:"
      echo "   cloudflared tunnel route dns ai-tunnel c3p0.thebennett.net"
      echo "   cloudflared tunnel route dns nextcloud-tunnel scarif.thebennett.net"
      echo
      echo "6. Restart the services:"
      echo "   cf-restart-tunnels"
    '')
    
    (writeShellScriptBin "cf-test-endpoints" ''
      echo "Testing Cloudflare tunnel endpoints..."
      echo
      echo "Testing c3p0.thebennett.net (AI services):"
      curl -I https://c3p0.thebennett.net || echo "AI endpoint not reachable"
      echo
      echo "Testing scarif.thebennett.net (Nextcloud):"
      curl -I https://scarif.thebennett.net || echo "Nextcloud endpoint not reachable"
      echo
      echo "Local services:"
      echo "AI (port 3000): $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 || echo "Not running")"
      echo "Nextcloud (port 80): $(curl -s -o /dev/null -w "%{http_code}" http://localhost:80 || echo "Not running")"
    '')