# Justfile — commandes locales Mac

USER := "lego"

default:
    @just --list

# ── Secrets ────────────────────────────────────────────────────────────────────

# Chiffre le .env → secrets/containers.yaml (commiter ensuite)
encrypt:
    ./encrypt-secrets.sh

# ── Déploiement ────────────────────────────────────────────────────────────────

# Copie les fichiers de config vers le serveur
sync host:
    rsync -av --rsync-path="sudo rsync" \
      --exclude='.git/' \
      --exclude='.env' \
      --exclude='docker-compose nginx.yml' \
      ./ {{ USER }}@{{ host }}:/etc/nixos/

# Sync + nixos-rebuild switch
deploy host: (sync host)
    ssh {{ USER }}@{{ host }} "sudo nixos-rebuild switch --flake path:/etc/nixos#nginx"

# Sync + nixos-rebuild test (applique sans rendre permanent)
test host: (sync host)
    ssh {{ USER }}@{{ host }} "sudo nixos-rebuild test --flake path:/etc/nixos#nginx"

# Voir le diff entre génération actuelle et nouvelle
diff host: (sync host)
    ssh {{ USER }}@{{ host }} "sudo nixos-rebuild switch --flake path:/etc/nixos#nginx --diff"
