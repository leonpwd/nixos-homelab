# NixOS Server — NPMPlus & CrowdSec (AppSec WAF)

Modular, declarative, and highly secure NixOS configuration powered by **Nix Flakes**, **Podman (`oci-containers`)**, **SOPS-nix**, **NPMPlus** (Nginx Proxy Manager Extended), **CrowdSec** (LAPI + WAF AppSec), and **Tailscale**.

---

### Architecture & Overview

```
                  ┌────────────────────────────────────────────────────────┐
                  │              NixOS Host (Network: host)                │
                  │                                                        │
                  │   ┌────────────────────────────────────────────────┐   │
                  │   │                    NPMPlus                     │   │
                  │   │         (Nginx Proxy Manager Extended)         │   │
                  │   └──────┬──────────────────┬──────────────────────┘   │
                  │          │ (Nginx logs)     │ (LAPI :8080 / WAF :7422) │
                  └──────────┼──────────────────┼──────────────────────────┘
                             │                  │
                ┌────────────┴──────────────────▼──────────────────────────┐
                │             Bridge Container (`netPROXY`)               │
                │                                                          │
                │   ┌──────────────────┐        ┌──────────────────────┐   │
                │   │     CrowdSec     │        │  docker-socket-proxy │   │
                │   │ (LAPI + AppSec)  │        │   (Secured socket)   │   │
                │   └──────────────────┘        ───────────┬───────────┘   │
                │                                          │               │
                │                               ┌──────────▼───────────┐   │
                │                               │        Arcane        │   │
                │                               │  (Docker UI Admin)   │   │
                │                               └──────────────────────┘   │
                └──────────────────────────────────────────────────────────┘
```

#### Key Architecture Points:
* **NPMPlus in `--network=host`**: Preserves real client WAN IP addresses without NAT masking, allowing CrowdSec to issue accurate bans.
* **CrowdSec AppSec WAF (Port 7422)**: Active application-layer defense against SQL injection, XSS, automated bots, and direct HTTP attacks.
* **Automated Bouncer Registration**: A Systemd service (`register-crowdsec-bouncer`) automatically registers the SOPS API key with CrowdSec on boot.
* **Secret Management with SOPS-nix**: No sensitive API keys or credentials stored unencrypted in Git or the Nix Store.
* **Daily Auto-Updates at 04:00 AM**: Systemd timer updates container images tagged `io.containers.autoupdate=registry` and prunes dangling images.

---

### Repository Structure

```
.
├── Justfile                     # Deployment and log commands for local workstation
├── README.md                    # Complete project documentation
├── flake.nix                    # NixOS Flake entrypoint
├── encrypt-secrets.sh           # Script to encrypt local .env to SOPS
├── crowdsec/                    # Defragmented CrowdSec configuration
│   ├── npmplus.yaml             # Nginx log parsing & AppSec WAF listener
│   └── npmplus-crowdsec.conf    # Nginx bouncer template (LAPI, Turnstile, WAF)
├── secrets/
│   └── containers.yaml          # SOPS-encrypted secrets file (Age / SSH host key)
└── configuration/
    ├── configuration.nix        # Core system (User, Shell, SSH, Firewall, Podman)
    ├── containers.nix           # OCI Container definitions (NPMPlus, CrowdSec, Arcane...)
    ├── secrets.nix              # SOPS-nix templates and secret injections
    ├── services.nix             # Automatic upgrades (NixOS + Podman) & GC cleanup
    ├── hardware-configuration.nix
    └── etc/
        ├── server.just          # Server-side helper commands installed at /Justfile
        ├── fastfetch.jsonc      # Fastfetch login screen configuration
        └── p10k                 # Zsh Powerlevel10k theme configuration
```

---

### Adapting This Configuration for Your Own Server

#### 1. Customize User & SSH Key
In `configuration/configuration.nix`:
- Change `users.users.lego` to your desired username.
- Replace the public key in `openssh.authorizedKeys.keys` with your SSH Ed25519 public key.

#### 2. Configure Hostname & Network Interface
In `configuration/configuration.nix`:
- `networking.hostName`: Set your target server's hostname.
- `networking.firewall.interfaces.ens18`: Replace `ens18` with your primary network interface (e.g. `eth0`, `enp1s0`).

#### 3. Setup Secrets with SOPS-nix

##### Step A: Create local `.env` file (excluded from Git)
Create a `.env` file at the repository root with your actual credentials:
```ini
ARCANE_ENCRYPTION_KEY=your_32_character_arcane_key
ARCANE_JWT_SECRET=your_jwt_secret
ACME_EMAIL=your-email@domain.com
GEOIPUPDATE_ACCOUNT_ID=your_maxmind_account_id
GEOIPUPDATE_LICENSE_KEY=your_maxmind_license_key
BOUNCER_API_KEY=your_custom_crowdsec_bouncer_key
TURNSTILE_SECRET_KEY=your_cloudflare_turnstile_secret_key
TURNSTILE_SITE_KEY=your_cloudflare_turnstile_site_key
```

##### Step B: Convert server SSH key to Age key using `ssh-to-age`
SOPS decrypts secrets on the host using the server's SSH host key (`/etc/ssh/ssh_host_ed25519_key`). You need to retrieve its corresponding Age public key to authorize it in `.sops.yaml`:

- **Option 1: Directly from target server via Nix**
  ```bash
  ssh user@<server-ip> "sudo nix run nixpkgs#ssh-to-age -- < /etc/ssh/ssh_host_ed25519_key.pub"
  ```
- **Option 2: Locally (with ssh-to-age binary installed)**
  ```bash
  ssh-to-age < /path/to/ssh_host_ed25519_key.pub
  ```
  *(Example output: `age1mg58jgrdvumx7d85axdd2gmgcmqh7838lxsh8gqvjts5uwtez4kq65a54a`)*

Copy the generated key into your `.sops.yaml` under the `keys` section.

##### Step C: Encrypt secrets file
Run the encryption helper:
```bash
just encrypt
# or run directly: ./encrypt-secrets.sh
```
This generates the encrypted `secrets/containers.yaml` file, ready to be committed to Git.

---

### Command Reference (`Justfile`)

#### From Local Workstation (Mac)
```bash
just deploy <server-ip>      # Syncs files via rsync and runs nixos-rebuild switch
just test <server-ip>        # Tests configuration without persisting changes
just diff <server-ip>        # Shows package/service diff before switching
just encrypt                 # Encrypts local .env -> secrets/containers.yaml
```

#### Directly on the NixOS Server (via `/Justfile`)
```bash
just ps                      # Lists Podman container statuses
just logs npmplus            # Last 500 lines of NPMPlus logs + live tailing
just logs-full crowdsec      # Complete untruncated CrowdSec log history
just logs-all                # Combined logs from all running containers
just restart arcane          # Restarts a container service
just gc                      # Runs Nix Garbage Collector (prunes old generations)
just info                    # Displays Fastfetch system dashboard
```
