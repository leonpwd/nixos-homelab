# NixOS Server — NPMPlus & CrowdSec (AppSec WAF)

Configuration NixOS modulaire et déclarative utilisant **Nix Flakes**, **Podman (`oci-containers`)**, **SOPS-nix**, **NPMPlus** (Nginx Proxy Manager Extended), **CrowdSec** (LAPI + WAF AppSec) et **Tailscale**.

---

### Architecture & Fonctionnement

```
                  ┌────────────────────────────────────────────────────────┐
                  │            Hôte NixOS (Network: host)                  │
                  │                                                        │
                  │   ┌────────────────────────────────────────────────┐   │
                  │   │                    NPMPlus                     │   │
                  │   │         (Nginx Proxy Manager Extended)         │   │
                  │   └──────┬──────────────────┬──────────────────────┘   │
                  │          │ (Logs Nginx)     │ (LAPI :8080 / WAF :7422) │
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

#### Points clés de la pile :

* **NPMPlus en `--network=host`** : Conserve les véritables adresses IP des clients WAN sans masquage NAT pour un bannissement CrowdSec efficace.
* **CrowdSec AppSec WAF (Port 7422)** : Protection au niveau applicatif contre les injections SQL, XSS, bots et attaques HTTP directes.
* **Gestion des Secrets SOPS-nix** : Aucune donnée sensible ou clé API n'est stockée en clair dans Git ou le Nix Store.
* **Auto-updates quotidiens à 4h00** : Timer Systemd qui met à jour les images Podman marquées `io.containers.autoupdate=registry` et purge les anciennes images.

---

### Structure du dépôt

```
.
├── Justfile                     # Commandes de déploiement et logs depuis votre Mac
├── README.md                    # Documentation complète du projet
├── flake.nix                    # Point d'entrée du Flake NixOS
├── encrypt-secrets.sh           # Script pour chiffrer votre .env local vers SOPS
├── crowdsec/                    # Configuration CrowdSec défragmentée
│   ├── npmplus.yaml             # Ingestion des logs Nginx & écoute WAF AppSec
│   └── npmplus-crowdsec.conf    # Template Nginx bouncer (LAPI, Turnstile, WAF)
├── secrets/
│   └── containers.yaml          # Fichier de secrets chiffré par SOPS (Age / SSH key)
└── configuration/
    ├── configuration.nix        # Système de base (Utilisateur, Shell, SSH, Firewall, Podman)
    ├── containers.nix           # Définition des conteneurs OCI (NPMPlus, CrowdSec, Arcane...)
    ├── secrets.nix              # Templates et injection des secrets SOPS-nix
    ├── services.nix             # Mises à jour automatiques (NixOS + Podman) & Nettoyage GC
    ├── hardware-configuration.nix
    └── etc/
        ├── server.just          # Commandes utilitaires installées sur le serveur sous /Justfile
        ├── fastfetch.jsonc      # Configuration Fastfetch au login
        └── p10k                 # Thème Zsh Powerlevel10k
```

---

### Adapter cette configuration pour votre propre serveur

#### 1. Personnaliser l'Utilisateur & la Clé SSH

Dans `configuration/configuration.nix` :

- Modifiez `users.users.lego` avec votre nom d'utilisateur.
- Remplacez la clé publique dans `openssh.authorizedKeys.keys` par votre propre clé SSH Ed25519.

#### 2. Adapter le Réseau & Firewall

Dans `configuration/configuration.nix` :

- `networking.hostName` : Choisissez le nom d'hôte de votre serveur.
- `networking.firewall.interfaces.ens18` : Remplacez `ens18` par le nom de votre interface réseau (ex: `eth0`, `enp1s0`).

#### 3. Configurer vos Secrets avec SOPS-nix

##### Étape A : Créer votre fichier `.env` local (exclus de Git)

Créez un fichier `.env` à la racine avec vos vraies clés :

```ini
ARCANE_ENCRYPTION_KEY=votre_cle_arcane_32_caracteres
ARCANE_JWT_SECRET=votre_jwt_secret
ACME_EMAIL=votre-email@domaine.com
GEOIPUPDATE_ACCOUNT_ID=votre_id_maxmind
GEOIPUPDATE_LICENSE_KEY=votre_cle_maxmind
BOUNCER_API_KEY=votre_cle_api_crowdsec_custom
TURNSTILE_SECRET_KEY=votre_cle_secrete_cloudflare_turnstile
TURNSTILE_SITE_KEY=votre_cle_site_cloudflare_turnstile
```

##### Étape B : Convertir la clé SSH du serveur en clé Age avec `ssh-to-age`

SOPS déchiffre les secrets sur le serveur en utilisant la clé d'hôte SSH (`/etc/ssh/ssh_host_ed25519_key`). Pour autoriser cette clé dans `.sops.yaml`, vous devez obtenir sa correspondance au format Age :

- **Méthode 1 : Directement depuis le serveur via Nix**
  ```bash
  ssh user@<ip-serveur> "sudo nix run nixpkgs#ssh-to-age -- < /etc/ssh/ssh_host_ed25519_key.pub"
  ```
- **Méthode 2 : Sans Nix (avec ssh-to-age installé localement)**
  ```bash
  ssh-to-age < /chemin/vers/ssh_host_ed25519_key.pub
  ```

  *(Exemple de sortie : `age1mg58jgrdvumx7d85axdd2gmgcmqh7838lxsh8gqvjts5uwtez4kq65a54a`)*

Copiez cette clé produite dans votre fichier `.sops.yaml` sous la section `keys`.

##### Étape C : Chiffrer le fichier de secrets

Exécutez la commande de chiffrement :

```bash
just encrypt
# ou directement : ./encrypt-secrets.sh
```

Cette commande va générer le fichier `secrets/containers.yaml` chiffré, prêt à être commité dans Git.

---

### Commandes Utiles (`Justfile`)

#### Depuis votre ordinateur local (Mac)

```bash
just deploy <ip-du-serveur>      # Synchronise le code via rsync et applique nixos-rebuild switch
just test <ip-du-serveur>        # Teste la configuration sans la rendre permanente
just diff <ip-du-serveur>        # Affiche la différence de paquets/services avant bascule
just encrypt                     # Chiffre le fichier .env -> secrets/containers.yaml
```

#### Directement sur le serveur NixOS (via `/Justfile`)

```bash
just ps                          # Liste l'état des conteneurs Podman
just logs npmplus                # 500 dernières lignes de logs NPMPlus + suivi direct
just logs-full crowdsec          # L'intégralité des logs de CrowdSec sans limite
just logs-all                    # Logs combinés de tous les conteneurs
just restart arcane              # Redémarre un conteneur
just gc                          # Lance le Garbage Collector Nix (purge anciennes générations)
just info                        # Dashboard Fastfetch du système
```
