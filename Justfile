# Justfile — local Mac commands

USER := "lego"

default:
    @just --list

# ── Secrets ────────────────────────────────────────────────────────────────────

# Encrypt secrets for a target host (e.g. just encrypt nginx or just encrypt media)
encrypt target="nginx":
    ./encrypt-secrets.sh {{ target }}

# ── Deployment ─────────────────────────────────────────────────────────────────

# Sync configuration files to target server
sync host:
    rsync -av --rsync-path="sudo rsync" \
      --exclude='.git/' \
      --exclude='.env*' \
      --exclude='docker-compose nginx.yml' \
      ./ {{ USER }}@{{ host }}:/etc/nixos/

# Sync + nixos-rebuild switch (usage: just deploy 192.168.1.101 nginx)
deploy host target="nginx": (sync host)
    ssh {{ USER }}@{{ host }} "sudo systemctl stop nixos-rebuild-switch-to-configuration.service 2>/dev/null || true; sudo systemctl daemon-reload; sudo nixos-rebuild switch --flake path:/etc/nixos#{{ target }}"

# Sync + nixos-rebuild test
test host target="nginx": (sync host)
    ssh {{ USER }}@{{ host }} "sudo nixos-rebuild test --flake path:/etc/nixos#{{ target }}"

# Compare diff between current generation and new generation
diff host target="nginx": (sync host)
    ssh {{ USER }}@{{ host }} "sudo nixos-rebuild switch --flake path:/etc/nixos#{{ target }} --diff"
