# Justfile — local Mac commands

USER := "lego"

# Host IPs dynamically read from .env (NGINX_IP and MEDIA_IP) or fallback defaults
NGINX_IP := `grep -E '^NGINX_IP=' .env 2>/dev/null | head -n1 | cut -d= -f2 || echo "192.168.1.101"`
MEDIA_IP := `grep -E '^MEDIA_IP=' .env 2>/dev/null | head -n1 | cut -d= -f2 || echo "192.168.1.103"`

default:
    @just --list

# ── Secrets ────────────────────────────────────────────────────────────────────

# Encrypt secrets for a target host (usage: just encrypt nginx or just encrypt media)
encrypt target="nginx":
    ./encrypt-secrets.sh {{ target }}

# ── Deployment ─────────────────────────────────────────────────────────────────

# Sync configuration files to target server (usage: just sync nginx or just sync media)
sync target="nginx":
    @HOST_IP=$([ "{{ target }}" = "media" ] && echo "{{ MEDIA_IP }}" || echo "{{ NGINX_IP }}"); \
    echo "📦 Syncing repository to {{ target }} ($HOST_IP)..."; \
    rsync -av --rsync-path="sudo rsync" \
      --exclude='.git/' \
      --exclude='.env*' \
      --exclude='docker-compose nginx.yml' \
      ./ {{ USER }}@$HOST_IP:/etc/nixos/

# Sync + nixos-rebuild switch (usage: just deploy nginx or just deploy media)
deploy target="nginx": (sync target)
    @HOST_IP=$([ "{{ target }}" = "media" ] && echo "{{ MEDIA_IP }}" || echo "{{ NGINX_IP }}"); \
    echo "🚀 Rebuilding NixOS configuration for {{ target }} ($HOST_IP)..."; \
    ssh {{ USER }}@$HOST_IP "sudo systemctl stop nixos-rebuild-switch-to-configuration.service 2>/dev/null || true; sudo systemctl daemon-reload; sudo nixos-rebuild switch --flake path:/etc/nixos#{{ target }}"

# Sync + nixos-rebuild test (usage: just test nginx or just test media)
test target="nginx": (sync target)
    @HOST_IP=$([ "{{ target }}" = "media" ] && echo "{{ MEDIA_IP }}" || echo "{{ NGINX_IP }}"); \
    echo "🧪 Testing NixOS configuration for {{ target }} ($HOST_IP)..."; \
    ssh {{ USER }}@$HOST_IP "sudo nixos-rebuild test --flake path:/etc/nixos#{{ target }}"

# Compare diff between current generation and new generation (usage: just diff nginx or just diff media)
diff target="nginx": (sync target)
    @HOST_IP=$([ "{{ target }}" = "media" ] && echo "{{ MEDIA_IP }}" || echo "{{ NGINX_IP }}"); \
    echo "🔍 Comparing configuration diff for {{ target }} ($HOST_IP)..."; \
    ssh {{ USER }}@$HOST_IP "sudo nixos-rebuild switch --flake path:/etc/nixos#{{ target }} --diff"
