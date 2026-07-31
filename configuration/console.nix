{ pkgs, lib, ... }:

{
  # ── Console Proxmox & Auto-Login TTY1 ──────────────────────────────────────────
  # Automatic login on tty1 (Proxmox console) with custom ASCII art banner.

  services.getty = {
    autologinUser = "lego";
    helpLine = lib.mkForce "";
    greetingLine = lib.mkForce "";
  };

  # Override /etc/issue to completely replace "Welcome to NixOS..." with custom ASCII art
  environment.etc."issue".text = lib.mkForce ''

  ░   ░░░  ░░░      ░░░        ░░   ░░░  ░░  ░░░░  ░
  ▒    ▒▒  ▒▒  ▒▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒    ▒▒  ▒▒▒  ▒▒  ▒▒
  ▓  ▓  ▓  ▓▓  ▓▓▓   ▓▓▓▓▓  ▓▓▓▓▓  ▓  ▓  ▓▓▓▓    ▓▓▓
  █  ██    ██  ████  █████  █████  ██    ███  ██  ██
  █  ███   ███      ███        ██  ███   ██  ████  █

        NPMPlus • CrowdSec • AppSec WAF

'';
}
