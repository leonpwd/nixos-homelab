# Justfile — Homelab commands (Colmena & SOPS)

default:
    @just --list

# ── Secrets ────────────────────────────────────────────────────────────────────

# Encrypt secrets for a target host (usage: just encrypt nginx or just encrypt media)
encrypt target="nginx":
    ./encrypt-secrets.sh {{ target }}

# ── Colmena Deployment ─────────────────────────────────────────────────────────

# Apply configuration with Colmena (usage: just apply [nginx|media] or just apply for all)
apply target="":
    @if [ -z "{{ target }}" ]; then \
      nix run nixpkgs#colmena -- apply; \
    else \
      nix run nixpkgs#colmena -- apply --on {{ target }}; \
    fi

# Dry-run activation with Colmena (usage: just dry [nginx|media])
dry target="":
    @if [ -z "{{ target }}" ]; then \
      nix run nixpkgs#colmena -- apply dry-activate; \
    else \
      nix run nixpkgs#colmena -- apply dry-activate --on {{ target }}; \
    fi

# Test configuration with Colmena without setting boot default (usage: just test-colmena [nginx|media])
test-colmena target="":
    @if [ -z "{{ target }}" ]; then \
      nix run nixpkgs#colmena -- apply test; \
    else \
      nix run nixpkgs#colmena -- apply test --on {{ target }}; \
    fi
