# Multi-Host NixOS Infrastructure

Declarative, multi-host NixOS infrastructure featuring an edge Reverse Proxy & WAF node (`nginx`) and a dedicated Media & Automation stack (`media`), managed seamlessly via Nix Flakes, Podman, Tailscale, and SOPS-nix.

---

## 🏗️ System Architecture

```text
                               ┌───────────────────────────┐
                               │ Self Hosted Media Stack   │
                               └─────────────┬─────────────┘
                                             │
                       ┌─────────────────────┴─────────────────────┐
                       │                                           │
                       ▼                                           ▼
        ┌───────────────────────────────┐           ┌───────────────────────────────┐
        │        Host 1: "nginx"        │           │        Host 2: "media"        │
        │     Reverse Proxy & WAF       │           │    Media & Automation Stack   │
        ├───────────────────────────────┤           ├───────────────────────────────┤
        │ • NPMPlus (Nginx Proxy)       │           │ • Jellyfin Media Server       │
        │ • CrowdSec AppSec WAF         │           │ • Sonarr / Radarr / Prowlarr  │
        │ • GeoIP2 Radical Filter (444) │           │ • QBittorrent & Cross-Seed    │
        │ • Arcane Management UI        │           │ • Gluetun WireGuard VPN       │
        └───────────────────────────────┘           └───────────────────────────────┘
```

---

## 💻 Host Breakdown

### 1. `nginx` — Edge Reverse Proxy & WAF

- **NPMPlus**: Nginx Proxy Manager running in host network mode (`--network=host`) for true client IP logging and Real IP restoration.
- **CrowdSec LAPI & AppSec WAF**: Real-time threat intelligence and layer-7 Web Application Firewall protecting upstream proxy hosts against SQLi, XSS, and bot scans.
- **GeoIP2 Filter**: Automated MaxMind database updater with a global Nginx policy returning `444` (Connection Closed) for traffic outside Europe and the US.
- **Arcane**: Centralized Docker container management web dashboard.

### 2. `media` — Media Server & Automation Stack

- **Media Suite**: Jellyfin Media Server for streaming.
- **Automation (*Arr Stack)**: Sonarr, Radarr, Prowlarr, ...
- **Download Engine**: QBittorrent routed securely through a Gluetun WireGuard VPN tunnel with dynamic port forwarding.

---

## 📂 Repository Structure

```text
.
├── Justfile                     # Local deployment & secret management recipes
├── flake.nix                    # Multi-host Flake output declarations (nginx, media)
├── encrypt-secrets.sh           # Per-host SOPS secret generator script
│
├── modules/                     # Shared NixOS modules across all hosts
│   ├── base.nix                 # Core OS, Zsh, SSH, Tailscale, Podman, and sudo
│   ├── services.nix             # Automatic upgrades, cleanup timers, and container updates
│   └── etc/                     # Shared terminal assets (Fastfetch, Powerlevel10k, Justfile)
│
├── hosts/                       # Per-host specific configurations
│   ├── nginx/                   # Proxy host configuration
│   │   ├── configuration.nix    # Host network & firewall rules
│   │   ├── containers.nix       # NPMPlus, CrowdSec, Arcane, GeoIP containers
│   │   ├── console.nix          # Cyan theme fastfetch & TTY1 autologin
│   │   └── secrets.nix          # SOPS secret bindings for Proxy
│   │
│   └── media/                   # Media host configuration
│       ├── configuration.nix    # Host network & media firewall rules
│       ├── containers.nix       # *Arr stack & Gluetun containers
│       ├── console.nix          # Red dual-tone fastfetch & TTY1 autologin
│       └── secrets.nix          # SOPS secret bindings for Media & WireGuard
│
├── crowdsec/                    # Nginx acquisition rules & GeoIP block maps
└── secrets/                     # Encrypted SOPS secret stores (nginx.yaml, media.yaml)
```

---

## 🔒 Secret Management (SOPS-nix & Age)

Secrets are encrypted using [SOPS](https://github.com/getsops/sops) and `Age` public-key cryptography tied to each host's SSH host key (`/etc/ssh/ssh_host_ed25519_key`). No plaintext credentials exist in Git or the Nix Store.

### Adding a New Host Key

To onboard a new host key into `.sops.yaml`:

```bash
cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
```

### Encrypting Secrets

Update your local `.env` or `.env.<target>` file and run:

```bash
just encrypt nginx   # Encrypts proxy secrets into secrets/nginx.yaml
just encrypt media   # Encrypts media secrets into secrets/media.yaml
```

---

## 🚀 Deployment & Operations

Deployment is triggered remotely from your local workstation using `just`:

| Command | Description |
| :--- | :--- |
| `just deploy [target]` | Syncs repository and rebuilds target configuration (`nginx` or `media`) |
| `just test [target]` | Tests target configuration without making it permanent |
| `just diff [target]` | Displays configuration diff between current and new generation |
| `just encrypt [target]` | Encrypts local environment variables into SOPS YAML files |

### Deployment Examples

```bash
# Deploy Reverse Proxy host (IP read from .env / .env.nginx)
just deploy nginx

# Deploy Media Stack host (IP read from .env / .env.media)
just deploy media
```
