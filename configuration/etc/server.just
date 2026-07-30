# server.just — commandes utiles sur le serveur NixOS

default:
    @just --list

# ── NixOS ──────────────────────────────────────────────────────────────────────

# Lister les générations NixOS
generations:
    nix-env -p /nix/var/nix/profiles/system --list-generations

# Rollback vers la génération précédente
rollback:
    sudo nixos-rebuild switch --rollback

# Nettoyage manuel : garde les 3 dernières générations + GC
gc:
    sudo systemctl start nixos-cleanup.service
    journalctl -u nixos-cleanup.service --no-pager -n 50

# Lancer la mise à jour maintenant (sans attendre le timer du lundi)
upgrade:
    sudo systemctl start nixos-upgrade.service
    journalctl -u nixos-upgrade.service -f --no-pager

# Prochains déclenchements des timers systemd
timers:
    systemctl list-timers --no-pager

# ── Containers Podman ──────────────────────────────────────────────────────────

# Statut de tous les containers
ps:
    podman ps -a --format "table {{{{.Names}}}}\t{{{{.Status}}}}\t{{{{.Image}}}}"

# Logs d'un container (usage : just logs arcane)
logs container:
    journalctl -u podman-{{ container }}.service -f --no-pager

# Redémarre un container (usage : just restart arcane)
restart container:
    sudo systemctl restart podman-{{ container }}.service

# Arrête tous les containers
stop-all:
    sudo systemctl stop podman-compose-nginx-root.target

# Démarre tous les containers
start-all:
    sudo systemctl start podman-compose-nginx-root.target

# ── Infos système ──────────────────────────────────────────────────────────────

# Utilisation disque
df:
    df -h /

# Utilisation mémoire
mem:
    free -h

# Résumé système complet
info:
    fastfetch --config /etc/fastfetch/config.jsonc
