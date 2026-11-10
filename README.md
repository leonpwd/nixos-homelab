# nixos-homelab

NixOS configuration for two homelab VMs, deployed with [Colmena](https://github.com/zhaofengli/colmena) from a single flake. Services run as Podman containers; secrets are encrypted with [sops-nix](https://github.com/Mic92/sops-nix).

This is my own setup, not a ready-to-use template: hostnames, domains and addresses are specific to my network. Feel free to borrow ideas.

## Hosts

| Host      | Role                  | Main services                                                                        |
| :-------- | :-------------------- | :----------------------------------------------------------------------------------- |
| `nginx` | Reverse proxy and WAF | NPMplus, CrowdSec, Arcane                                                            |
| `media` | Media and automation  | Sonarr, Radarr, Prowlarr, qBittorrent behind Gluetun, Navidrome, slskd, Beets, Seerr |

Both hosts are reachable over Tailscale. A separate Raspberry Pi lives in its own repository.

## Layout

```text
flake.nix            Hosts and Colmena deployment definitions
Justfile             Deployment and secret recipes
encrypt-secrets.sh   Encrypts a host's .env file into secrets/<host>.yaml
.sops.yaml           SOPS recipients (one age key per host)
modules/             Shared modules (base system, SSH, shell, auto-upgrade)
hosts/<host>/        Per-host configuration, containers, secrets, extra files
crowdsec/            CrowdSec acquisition and whitelist files
secrets/             Encrypted SOPS stores
```

## Usage

Requires Nix with flakes and access to the hosts over Tailscale.

| Command                      | Description                                             |
| :--------------------------- | :------------------------------------------------------ |
| `just dry [host]`          | Build and dry-activate without changing anything        |
| `just test-colmena [host]` | Activate without setting the boot default               |
| `just apply [host]`        | Build on the target and activate                        |
| `just encrypt <host>`      | Encrypt the local `.env` into `secrets/<host>.yaml` |

Omit `[host]` to target both hosts.

## Secrets

Each host decrypts its secrets with an age key derived from its SSH host key. To add a host, convert its public key and add the result to `.sops.yaml`:

```bash
cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
```

Put values in a local, git-ignored `.env`, then run `just encrypt <host>`.
