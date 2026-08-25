{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/base.nix
    ../../modules/services.nix
    ./secrets.nix
    ./hardware-configuration.nix
    ./containers.nix
  ];

  networking.hostName = "nginx";

  environment.etc."fastfetch/config.jsonc".source = ./etc/fastfetch.jsonc;

  # Force IPv4 preference for outbound connections (fixes certbot → Cloudflare API
  # with rotating IPv6 privacy extensions causing token rejection)
  environment.etc."gai.conf".text = ''
    precedence ::ffff:0:0/96 100
  '';

  # Reverse Path Filtering — safe on nginx (no complex Podman container routing)
  boot.kernel.sysctl."net.ipv4.conf.all.rp_filter" = 1;

  # Specific firewall rules for Proxy host (WAN/LAN HTTP/HTTPS ports)
  networking.firewall.interfaces = {
    ens18 = {
      allowedTCPPorts = [ 22 80 443 81 ];
      allowedUDPPorts = [ 80 443 ];
    };
    tailscale0 = {
      allowedTCPPorts = [ 22 ];
    };
  };
  
  environment.etc."issue".text = lib.mkForce ''
    ░   ░░░  ░░░      ░░░        ░░   ░░░  ░░  ░░░░  ░░░      ░░░░      ░░
    ▒    ▒▒  ▒▒  ▒▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒    ▒▒  ▒▒▒  ▒▒  ▒▒▒  ▒▒▒▒  ▒▒  ▒▒▒▒▒▒▒
    ▓  ▓  ▓  ▓▓  ▓▓▓   ▓▓▓▓▓  ▓▓▓▓▓  ▓  ▓  ▓▓▓▓    ▓▓▓▓  ▓▓▓▓  ▓▓▓      ▓▓
    █  ██    ██  ████  █████  █████  ██    ███  ██  ███  ████  ████████  █
    █  ███   ███      ███        ██  ███   ██  ████  ███      ████      ██
                    
                  NPMPlus • CrowdSec • AppSec 
  '';

  # ── NPMPlus Log Viewer — Colored aliases for nginx access logs & CrowdSec bans ──
  # Format: [$time] [Client $ip] [$country] [$host] "$request" $status $req_time $upstream_time "$referer" $bytes "$ua"
  # Colors: 🔵 Cyan=IP  🟡 Yellow=Host  🟣 Magenta=2xx/3xx  🟠 Orange=timing  🔴 Red=4xx/5xx/ban

  programs.zsh.interactiveShellInit = lib.mkAfter ''
    # NPMPlus access log path (volume: /config/npmplus:/data)
    NPM_LOG="/config/npmplus/nginx/logs/access.log"

    # Detect dark vs light terminal background.
    # Override: export LIVE_THEME=dark  or  export LIVE_THEME=light
    _live_is_dark() {
      local t=''${LIVE_THEME:-auto}
      [[ $t == dark ]]  && return 0
      [[ $t == light ]] && return 1
      # Auto-detect via COLORFGBG ("fg;bg"): bg <= 8 = dark, > 8 = light
      if [[ -n ''${COLORFGBG:-} ]]; then
        local _bg=''${COLORFGBG##*;}
        (( _bg <= 8 )) && return 0
        return 1
      fi
      return 1  # default: assume light terminal
    }

    # Coloring + redaction function for npmplus_geo log format
    color_live() {
      if _live_is_dark; then
        # ── Dark terminal palette ──────────────────────────────
        sed -u \
          -e 's/api_key=[^&" ]*/api_key=[REDACTED]/g' \
          -e 's/access_token=[^&" ]*/access_token=[REDACTED]/g' \
          -e 's/token=[^&" ]*/token=[REDACTED]/g' \
          -e 's/deviceId=[^&" ]*/deviceId=[REDACTED]/g' \
          -e 's/X-Emby-Token=[^&" ]*/X-Emby-Token=[REDACTED]/g' \
          -e 's/api_token=[^&" ]*/api_token=[REDACTED]/g' \
          -e 's/\[Client [^]]*\]/\x1b[38;5;51m&\x1b[0m/g' \
          -e 's/\[[A-Z][A-Z]\]/\x1b[38;5;118m&\x1b[0m/g' \
          -e 's/\[--\]/\x1b[38;5;245m&\x1b[0m/g' \
          -e 's/\[[a-zA-Z0-9._-]*\.legotv\.org\]/\x1b[38;5;226m&\x1b[0m/g' \
          -e 's/" 40[34] /"\x1b[1;38;5;203m 40[34] \x1b[0m/g' \
          -e 's/" 5[0-9][0-9] /"\x1b[1;38;5;203m& \x1b[0m/g' \
          -e 's/" 4[0-9][0-9] /"\x1b[38;5;160m&\x1b[0m/g' \
          -e 's/" 2[0-9][0-9] /"\x1b[38;5;201m&\x1b[0m/g' \
          -e 's/" 3[0-9][0-9] /"\x1b[38;5;201m&\x1b[0m/g' \
          -e 's/[0-9]\+\.[0-9]\+[[:space:]][0-9]\+\.[0-9]\+/\x1b[38;5;208m&\x1b[0m/g' \
          -e 's/"GET /\x1b[38;5;75m"GET \x1b[0m/g' \
          -e 's/"POST /\x1b[38;5;208m"POST \x1b[0m/g' \
          -e 's/"DELETE /\x1b[1;38;5;196m"DELETE \x1b[0m/g' \
          -e 's/"https\?:\/\/[^"]*/\x1b[38;5;226m&\x1b[0m/g'
      else
        # ── Light terminal palette ─────────────────────────────
        sed -u \
          -e 's/api_key=[^&" ]*/api_key=[REDACTED]/g' \
          -e 's/access_token=[^&" ]*/access_token=[REDACTED]/g' \
          -e 's/token=[^&" ]*/token=[REDACTED]/g' \
          -e 's/deviceId=[^&" ]*/deviceId=[REDACTED]/g' \
          -e 's/X-Emby-Token=[^&" ]*/X-Emby-Token=[REDACTED]/g' \
          -e 's/api_token=[^&" ]*/api_token=[REDACTED]/g' \
          -e 's/\[Client [^]]*\]/\x1b[38;5;24m&\x1b[0m/g' \
          -e 's/\[[A-Z][A-Z]\]/\x1b[38;5;28m&\x1b[0m/g' \
          -e 's/\[--\]/\x1b[38;5;243m&\x1b[0m/g' \
          -e 's/\[[a-zA-Z0-9._-]*\.legotv\.org\]/\x1b[38;5;130m&\x1b[0m/g' \
          -e 's/" 40[34] /"\x1b[1;38;5;124m 40[34] \x1b[0m/g' \
          -e 's/" 5[0-9][0-9] /"\x1b[1;38;5;124m& \x1b[0m/g' \
          -e 's/" 4[0-9][0-9] /"\x1b[38;5;160m&\x1b[0m/g' \
          -e 's/" 2[0-9][0-9] /"\x1b[38;5;54m&\x1b[0m/g' \
          -e 's/" 3[0-9][0-9] /"\x1b[38;5;54m&\x1b[0m/g' \
          -e 's/[0-9]\+\.[0-9]\+[[:space:]][0-9]\+\.[0-9]\+/\x1b[38;5;136m&\x1b[0m/g' \
          -e 's/"GET /\x1b[38;5;26m"GET \x1b[0m/g' \
          -e 's/"POST /\x1b[38;5;166m"POST \x1b[0m/g' \
          -e 's/"DELETE /\x1b[1;38;5;124m"DELETE \x1b[0m/g' \
          -e 's/"https\?:\/\/[^"]*/\x1b[38;5;130m&\x1b[0m/g'
      fi
    }

    # Convert [XX] country code to 🇽🇽 [XX] flag emoji using Unicode Regional Indicators
    # Regional Indicator 'A' = U+1F1E6 = 127462 = 127461 + index(1-based)
    # NOTE: use result+rest pattern — modifying $0 in-place would cause infinite loop
    #       because the replacement keeps [XX] in the output which re-matches.
    add_flags() {
      LC_ALL=en_US.UTF-8 gawk '
        function flag(cc,   c1, c2) {
          c1 = 127461 + index("ABCDEFGHIJKLMNOPQRSTUVWXYZ", substr(cc,1,1))
          c2 = 127461 + index("ABCDEFGHIJKLMNOPQRSTUVWXYZ", substr(cc,2,1))
          return sprintf("%c%c", c1, c2)
        }
        {
          result = ""
          rest = $0
          while (match(rest, /\[[A-Z][A-Z]\]|\[--\]/)) {
            cc = substr(rest, RSTART+1, RLENGTH-2)
            repl = (cc == "--") ? "❓ [--]" : flag(cc) " [" cc "]"
            result = result substr(rest, 1, RSTART-1) repl
            rest = substr(rest, RSTART+RLENGTH)
          }
          print result rest
          fflush()
        }
      '
    }

    # All access logs in color with flag emojis
    alias live='sudo tail -f "$NPM_LOG" | add_flags | color_live'

    # Access logs excluding Tailscale (100.x) and internal IPs
    alias live-ext='sudo tail -f "$NPM_LOG" | grep --line-buffered -v -E "(100\.[0-9]+\.[0-9]+\.[0-9]+|127\.0\.0\.1|::1)" | add_flags | color_live'

    # CrowdSec bans only — filters out AppSec reload noise from podman logs
    alias bans='sudo podman logs npmplus -f 2>&1 | grep --line-buffered -v -E "(APPSEC is enabled|Initialisation done|crowdsec\.lua:243|crowdsec\.conf.*init|Failed to create the timer|nginx -tq|nginx -s reload|certbot|Renew|logrotate|acquired lock|Reading state|Allocating hash|Creating new state|rotating pattern|log needs|log does not)"'
  '';
}
