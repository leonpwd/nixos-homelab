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

# Nettoyage manuel : supprime les générations de plus de 14 jours + GC
gc:
    sudo nix-collect-garbage --delete-older-than 14d

# Lancer la mise à jour maintenant (sans attendre le timer du lundi)
upgrade:
    sudo systemctl start nixos-upgrade.service
    journalctl -u nixos-upgrade.service -f --no-pager

# Prochains déclenchements des timers systemd
timers:
    systemctl list-timers --no-pager
    
# Berserk : virer toute les précédentes générations NixOS
berserk:
    sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations old

# ── Containers Podman ──────────────────────────────────────────────────────────

# Statut de tous les containers
ps:
    podman ps -a --format "table {{{{.Names}}}}\t{{{{.Status}}}}\t{{{{.Image}}}}"

# Logs d'un container avec 500 lignes + suivi direct (ex: just logs npmplus)
logs container:
    journalctl -u podman-{{ container }}.service -n 500 -f --no-pager

# TOUT l'historique de logs d'un container sans limite (ex: just logs-full npmplus)
logs-full container:
    journalctl -u podman-{{ container }}.service --no-pager

# Logs de TOUS les conteneurs Podman combinés (ex: just logs-all)
logs-all:
    journalctl -u 'podman*' -n 500 -f --no-pager

# Redémarre un container (usage : just restart arcane)
restart container:
    sudo systemctl restart podman-{{ container }}.service

# Arrête tous les containers
stop-all:
    sudo systemctl stop podman-compose-$(hostname)-root.target

# Démarre tous les containers
start-all:
    sudo systemctl start podman-compose-$(hostname)-root.target

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
