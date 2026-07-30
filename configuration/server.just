# server.just — commandes serveur NixOS
# Déployé dans /home/lego/Justfile par NixOS à chaque rebuild.

default:
    @just --list

# ── NixOS ──────────────────────────────────────────────────────────────────────

# Lister les générations
generations:
    nix-env -p /nix/var/nix/profiles/system --list-generations

# Rollback vers la génération précédente
rollback:
    sudo nixos-rebuild switch --rollback

# Nettoyage manuel (garde 3 générations + GC)
gc:
    sudo systemctl start nixos-cleanup.service
    journalctl -u nixos-cleanup.service --no-pager -n 50

# Lancer la mise à jour maintenant
upgrade:
    sudo systemctl start nixos-upgrade.service
    journalctl -u nixos-upgrade.service -f --no-pager

# Prochains déclenchements des timers
timers:
    systemctl list-timers --no-pager

# ── Containers ─────────────────────────────────────────────────────────────────

# Statut de tous les containers
ps:
    podman ps -a --format "table \{{.Names}}\t\{{.Status}}\t\{{.Image}}"

# Logs d'un container  →  just logs arcane
logs container:
    journalctl -u podman-{{ container }}.service -f --no-pager

# Redémarre un container  →  just restart arcane
restart container:
    sudo systemctl restart podman-{{ container }}.service

# Arrête / démarre tous les containers
stop-all:
    sudo systemctl stop podman-compose-nginx-root.target
start-all:
    sudo systemctl start podman-compose-nginx-root.target

# ── Système ────────────────────────────────────────────────────────────────────

df:
    df -h /
mem:
    free -h
info:
    fastfetch --config /etc/fastfetch/config.jsonc
