# AI Models Service Configuration  
# File: /etc/nixos/services/ai-models.nix

{ config, pkgs, lib, ... }:

{
  # Podman container for Ollama (local LLM hosting)
  virtualisation.oci-containers.containers.ollama = {
    image = "ollama/ollama:latest";
    autoStart = true;
    
    volumes = [
      "/mnt/ai-models:/root/.ollama"
      "/var/lib/ai-models:/models"
    ];
    
    ports = [ "11434:11434" ];
    
    environment = {
      OLLAMA_HOST = "0.0.0.0";
      OLLAMA_MODELS = "/models";
    };
    
    extraOptions = [
      "--device=/dev/kfd"
      "--device=/dev/dri"
      "--security-opt=seccomp=unconfined"
      "--group-add=video"
    ];
  };

  # Open WebUI for Ollama (ChatGPT-like interface)
  virtualisation.oci-containers.containers.open-webui = {
    image = "ghcr.io/open-webui/open-webui:main";
    autoStart = true;
    dependsOn = [ "ollama" ];
    
    ports = [ "3000:8080" ];
    
    volumes = [
      "open-webui:/app/backend/data"
    ];
    
    environment = {
      OLLAMA_BASE_URL = "http://ollama:11434";
      WEBUI_SECRET_KEY = "your-secret-key-here";
    };
    
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"
    ];
  };

  # Text Generation WebUI (for more advanced models)
  virtualisation.oci-containers.containers.text-generation-webui = {
    image = "atinoda/text-generation-webui:default";
    autoStart = false; # Start manually when needed
    
    ports = [ "7860:7860" ];
    
    volumes = [
      "/mnt/ai-models/text-generation:/app/models"
      "/mnt/ai-models/characters:/app/characters"
      "/mnt/ai-models/presets:/app/presets"
    ];
    
    environment = {
      CLI_ARGS = "--listen --api";
    };
    
    extraOptions = [
      "--device=/dev/kfd"
      "--device=/dev/dri"
      "--security-opt=seccomp=unconfined"
      "--group-add=video"
    ];
  };

  # Stable Diffusion WebUI
  virtualisation.oci-containers.containers.stable-diffusion-webui = {
    image = "ghcr.io/AbdBarho/stable-diffusion-webui-docker:master";
    autoStart = false; # GPU intensive, start when needed
    
    ports = [ "7861:7860" ];
    
    volumes = [
      "/mnt/ai-models/stable-diffusion:/app/models"
      "/mnt/ai-models/outputs:/app/outputs"
    ];
    
    environment = {
      CLI_ARGS = "--listen --api --enable-insecure-extension-access";
    };
    
    extraOptions = [
      "--device=/dev/kfd"
      "--device=/dev/dri"
      "--security-opt=seccomp=unconfined"
      "--group-add=video"
    ];
  };

  # Nginx reverse proxy for AI services
  services.nginx.virtualHosts."c3p0.thebennett.net" = {
    forceSSL = false; # Let Cloudflare handle SSL
    
    locations = {
      # Main OpenWebUI interface
      "/" = {
        proxyPass = "http://127.0.0.1:3000";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
      
      # Ollama API
      "/ollama/" = {
        proxyPass = "http://127.0.0.1:11434/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          
          # Remove /ollama prefix
          rewrite ^/ollama/(.*)$ /$1 break;
        '';
      };
      
      # Text Generation WebUI (when enabled)
      "/textgen/" = {
        proxyPass = "http://127.0.0.1:7860/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          
          # Remove /textgen prefix
          rewrite ^/textgen/(.*)$ /$1 break;
        '';
      };
      
      # Stable Diffusion WebUI (when enabled)
      "/sd/" = {
        proxyPass = "http://127.0.0.1:7861/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          
          # Remove /sd prefix
          rewrite ^/sd/(.*)$ /$1 break;
        '';
      };
    };
  };

  # Create podman network for AI services
  systemd.services.create-ai-network = {
    description = "Create AI services network";
    after = [ "podman.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.podman}/bin/podman network create ai-network || true";
      ExecStop = "${pkgs.podman}/bin/podman network rm ai-network || true";
    };
  };

  # AI model management scripts
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "ai-status" ''
      echo "=== AI Services Status ==="
      echo "Ollama:"
      podman ps --filter name=ollama --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
      echo
      echo "Open WebUI:"
      podman ps --filter name=open-webui --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
      echo
      echo "Available Models:"
      curl -s http://localhost:11434/api/tags | ${jq}/bin/jq -r '.models[].name' 2>/dev/null || echo "Ollama not responding"
    '')
    
    (writeShellScriptBin "ai-pull-model" ''
      if [ -z "$1" ]; then
        echo "Usage: ai-pull-model <model-name>"
        echo "Example: ai-pull-model llama2"
        exit 1
      fi
      
      echo "Pulling model: $1"
      curl -X POST http://localhost:11434/api/pull -d "{\"name\":\"$1\"}"
    '')
    
    (writeShellScriptBin "ai-start-textgen" ''
      echo "Starting Text Generation WebUI..."
      podman start text-generation-webui
      echo "Text Generation WebUI available at: http://c3p0.thebennett.net/textgen/"
    '')
    
    (writeShellScriptBin "ai-start-sd" ''
      echo "Starting Stable Diffusion WebUI..."
      podman start stable-diffusion-webui
      echo "Stable Diffusion WebUI available at: http://c3p0.thebennett.net/sd/"
    '')
  ];

  # Backup AI models
  systemd.services.ai-models-backup = {
    description = "AI Models Backup";
    serviceConfig = {
      Type = "oneshot";
      User = "vader";
      ExecStart = pkgs.writeShellScript "ai-models-backup" ''
        #!/bin/bash
        BACKUP_DIR="/mnt/ai-models/backups"
        DATE=$(date +%Y%m%d_%H%M%S)
        
        mkdir -p "$BACKUP_DIR"
        
        # Backup Ollama models
        if [ -d "/mnt/ai-models/models" ]; then
          tar -czf "$BACKUP_DIR/ollama_models_$DATE.tar.gz" -C "/mnt/ai-models" models/
        fi
        
        # Keep only last 3 backups (AI models are large)
        find "$BACKUP_DIR" -name "ollama_models_*" -mtime +3 -delete
      '';
    };
  };

  # Weekly AI models backup
  systemd.timers.ai-models-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };
}