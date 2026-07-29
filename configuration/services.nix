{ config, lib, pkgs, ... }:
{
  # ---------------------------------------------------------------------------
  # Mise à jour automatique hebdomadaire
  # ---------------------------------------------------------------------------
  # Tous les lundis à 4h00 (+ délai aléatoire jusqu'à 30min).
  # Si la machine était éteinte à l'heure prévue, se lance au prochain boot.
  #
  # Logs : journalctl -u nixos-upgrade.service
  # Timer : systemctl status nixos-upgrade.timer
  # ---------------------------------------------------------------------------

  system.autoUpgrade = {
    enable             = true;
    flake              = "path:/etc/nixos#nginx";
    dates              = "Mon 04:00";
    randomizedDelaySec = "30min";
    persistent         = true;
    allowReboot        = false;
  };

  # ---------------------------------------------------------------------------
  # Nettoyage automatique hebdomadaire des anciennes générations NixOS
  # ---------------------------------------------------------------------------
  # S'exécute le lundi à 5h00 (après la mise à jour).
  # Garde les 3 générations les plus récentes, supprime le reste,
  # puis lance le garbage collector pour libérer l'espace disque.
  #
  # Logs : journalctl -u nixos-cleanup.service
  # Timer : systemctl status nixos-cleanup.timer
  # Tester maintenant : sudo systemctl start nixos-cleanup.service
  # ---------------------------------------------------------------------------

  systemd.services.nixos-cleanup = {
    description = "Nettoyage des anciennes générations NixOS";
    after       = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      echo "=== Générations NixOS avant nettoyage ==="
      ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --list-generations

      echo ""
      echo "=== Suppression des générations > 3 ==="
      # +3 = garde les 3 générations les plus récentes, supprime le reste
      ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations +3

      echo ""
      echo "=== Garbage collection ==="
      ${pkgs.nix}/bin/nix-store --gc

      echo ""
      echo "=== Générations restantes ==="
      ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --list-generations

      echo "=== Nettoyage terminé ==="
    '';
  };

  systemd.timers.nixos-cleanup = {
    wantedBy  = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "Mon 05:00"; # 1h après la mise à jour
      Persistent         = true;        # se rattrape si la machine était éteinte
      RandomizedDelaySec = "15min";
    };
  };
}
