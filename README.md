# Homelab

Source-of-truth for a Proxmox-based homelab: Ansible playbooks and roles to create LXC/VM guests and deploy services via Docker Compose.

## Architecture

```
Proxmox VE (192.168.178.110)
├── LXC 120  Ansible control node
├── LXC 121  Caddy (reverse proxy + Cloudflare Tunnel)
├── LXC 122  PocketID + Tinyauth (identity / OIDC)
├── LXC 123  HashiCorp Vault (secrets)
├── LXC 124  Monitoring (Prometheus + Grafana)
├── LXC 125  LLM (Ollama + Gemma 4)
├── LXC 130  PostgreSQL
├── LXC 131  MySQL
├── LXC 132  Redis
├── LXC 133  MongoDB
├── LXC 140  Jellyfin (media)
├── LXC 141  ARR stack (Radarr, Sonarr, SABnzbd, …)
├── LXC 142  Immich (photo/video backup)
├── LXC 250  Dash (Open WebUI + personal dashboards)
├── LXC 251  OpenClaw (AI agent)
├── LXC 252  Humaun
├── LXC 253  AdGuard Home Primary (DNS + DHCP)
└── LXC 254  AdGuard Home Secondary (DNS)
```

All secrets are managed through Vault and fetched at deploy time via AppRole auth. Container definitions live in `inventory/group_vars/all/lxc.yml`.

## Deploying Changes

The primary interface is `./lab` — run it from your **local machine**. It SSHes into the Ansible LXC (`192.168.178.120`), does `git pull`, and runs the playbook there. Requires bash 4+ (`brew install bash` on macOS).

```bash
./lab deploy <service>        # deploy or redeploy a service
./lab deploy                  # list all available services
./lab upgrade                 # pull latest images + restart all Docker Compose services
./lab upgrade <service>       # upgrade a single service
./lab lxc create              # create all LXC containers
./lab lxc destroy [vmid]      # destroy all or one container
./lab vault-config <token>    # configure Vault (AppRole, policies, OIDC)
./lab help                    # show all commands
```

> **Note:** Caddy uses a custom-built image (`xcaddy` + Cloudflare plugin) and cannot be upgraded via `./lab upgrade`. Use `./lab deploy caddy` instead.

> **Note:** Immich, Vault, MongoDB, and pve-exporter use pinned versions. Bump the version var in `roles/<service>/defaults/main.yml` before redeploying to upgrade.

If you need to run a playbook directly (e.g. with extra flags):

```bash
# SSH into Ansible LXC first
ssh ansible_user@192.168.178.120
cd ~/homelab && git pull

# Then run the playbook
ansible-playbook deployments/deploy_<service>.yml -e "@vars/vault_auth_vars.yml" -vv
```

## Prerequisites

- Ansible installed (`brew install ansible` on macOS or `pip install ansible-core`)
- `community.hashi_vault`, `community.general`, `community.proxmox`, and `community.docker` collections installed
- SSH access to the Proxmox host and all LXC containers (key: see `AGENTS.md`)
- Proxmox API token for LXC create/destroy operations

## Repository Layout

```
homelab/
├── ansible.cfg                  # Inventory path, remote user, defaults
├── Makefile                     # Shortcuts: make create-lxc, destroy-lxc
├── inventory/
│   ├── hosts                    # Host → IP mapping and groups
│   └── group_vars/all/lxc.yml  # Canonical LXC definitions (proxmox_containers)
├── deployments/                 # Playbooks (one per service)
├── roles/                       # Ansible roles (tasks, templates, defaults, handlers)
└── vars/                        # Operator-supplied vars (see vars/README.md)
```

## First Boot — Full Bootstrap Order

Deploy in this order on a fresh Proxmox host. Each step depends on the ones above it.

### 1. Create LXC containers

```bash
ansible-playbook deployments/create_lxc.yml -e "@vars/proxmox_create_vars.yml"
```

Reads `proxmox_containers` from `inventory/group_vars/all/lxc.yml`. Creates all LXCs and applies bind mounts. Requires `vars/proxmox_create_vars.yml` (API token + container root password).

### 2. DNS — AdGuard Home

```bash
ansible-playbook deployments/deploy_adguard.yml
```

No secrets needed. Sets up split-brain DNS so `*.mol.la` resolves internally.

### 3. Vault — secrets management

```bash
ansible-playbook deployments/deploy_vault.yml
```

Installs and starts Vault. After first deploy, **manually initialize and unseal**:

```bash
ssh vault
vault operator init -key-shares=1 -key-threshold=1
vault operator unseal <unseal-key>
```

Save the root token and unseal key securely.

### 4. Configure Vault (AppRole, policies, OIDC)

```bash
ansible-playbook deployments/configure_vault.yml -e "vault_token=<root-token>" -e "@vars/vault_config_vars.yml"
```

Creates the `kv/homelab` secrets engine, AppRole auth, and OIDC config. **Outputs `role_id` and `secret_id`** — save these to `vars/vault_auth_vars.yml`:

```yaml
vault_addr: "http://192.168.178.123:8200"
vault_role_id: "<from output>"
vault_secret_id: "<from output>"
```

### 5. Seed secrets in Vault

Before deploying services, store their secrets:

```bash
# Caddy
vault kv put kv/homelab/data/caddy \
  cloudflare_api_token="..." cloudflare_tunnel_token="..." caddy_cloudflare_email="..."

# PocketID
vault kv put kv/homelab/data/pocketid \
  pocketid_encryption_key="$(openssl rand -base64 32)" \
  tinyauth_pocketid_client_id="..." tinyauth_pocketid_client_secret="..." \
  pocketid_maxmind_license_key=""

# Databases
vault kv put kv/homelab/data/postgresql immich="<password>"
vault kv put kv/homelab/data/redis password="<password>"
vault kv put kv/homelab/data/mysql root="<password>"
vault kv put kv/homelab/data/mongodb admin="<password>"

# Grafana OIDC
vault kv put kv/homelab/data/grafana client_id="..." client_secret="..."

# PVE Exporter
vault kv put kv/homelab/data/pve_exporter user="..." password="..."
```

See each `vars/*.example` file for the full list of expected keys.

### 6. Core services

Deploy in order — PocketID before Caddy (Caddy's Tinyauth forward-auth points to PocketID):

```bash
ansible-playbook deployments/deploy_pocketid.yml  -e "@vars/vault_auth_vars.yml"
ansible-playbook deployments/deploy_caddy.yml      -e "@vars/vault_auth_vars.yml"
```

### 7. Data services

No ordering dependency between these:

```bash
ansible-playbook deployments/deploy_postgresql.yml -e "@vars/vault_auth_vars.yml" -e "@vars/postgresql_apps.yml"
ansible-playbook deployments/deploy_mysql.yml      -e "@vars/vault_auth_vars.yml" -e "@vars/mysql_apps.yml"
ansible-playbook deployments/deploy_redis.yml      -e "@vars/vault_auth_vars.yml"
ansible-playbook deployments/deploy_mongodb.yml    -e "@vars/vault_auth_vars.yml" -e "@vars/mongodb_apps.yml"
```

### 8. Monitoring

```bash
ansible-playbook deployments/deploy_node_exporter.yml
ansible-playbook deployments/deploy_monitoring.yml    -e "@vars/vault_auth_vars.yml"
ansible-playbook deployments/deploy_pve_exporter.yml  -e "@vars/vault_auth_vars.yml"
```

Node exporter goes on all hosts first, then Prometheus + Grafana, then PVE exporter.

### 9. Applications

```bash
ansible-playbook deployments/deploy_jellyfin.yml
ansible-playbook deployments/deploy_arr.yml
ansible-playbook deployments/deploy_immich.yml -e "@vars/vault_auth_vars.yml"
```

Immich depends on PostgreSQL (with `pgvector`) and Redis being deployed first.

## Service Dependencies

```
AdGuard ──────────────────────────────────── (standalone)
Vault ────────────────────────────────────── (standalone, init manually)
PocketID ─── Vault
Caddy ────── Vault, PocketID (Tinyauth forward-auth)
PostgreSQL ── Vault
MySQL ─────── Vault
Redis ─────── Vault
MongoDB ───── Vault
Monitoring ── Vault, Node Exporter (on all hosts)
PVE Exporter ─ Vault
Jellyfin ──── (standalone, needs media bind mount)
ARR ────────── (standalone, needs media bind mount)
Immich ─────── Vault, PostgreSQL (pgvector), Redis
```

## Day-to-Day Operations

### Destroy LXC containers

```bash
ansible-playbook deployments/destroy_lxc.yml -e "@vars/proxmox_create_vars.yml"              # all
ansible-playbook deployments/destroy_lxc.yml -e "@vars/proxmox_create_vars.yml" -e "vmid=253" # single
```

### Redeploy a service

Re-run its playbook. All playbooks are idempotent — they converge to the desired state.

### Rollback

Services run as Docker Compose stacks in `/opt/compose/<service>-<hostname>/`. To roll back:

1. SSH into the LXC host.
2. Edit `compose.yml` to pin the previous image tag.
3. `docker compose up -d` to restart with the old version.

Or re-run the Ansible playbook after reverting the role change in git.

LXC containers can be recreated from scratch — all persistent data lives in named Docker volumes or bind-mounted storage. Vault data persists in its LXC filesystem; back it up via Proxmox Backup Server.

## Adding a New Service

1. **Allocate an LXC** — add an entry to `inventory/group_vars/all/lxc.yml` and `inventory/hosts`.
2. **Create the LXC** — `make create-lxc` (or run `create_lxc.yml`).
3. **Create the role** — `roles/<service>/tasks/main.yml`, `templates/compose.yml.j2`, `defaults/main.yml`.
4. **Create the playbook** — `deployments/deploy_<service>.yml` targeting the new host group.
5. **Store secrets** — `vault kv put kv/homelab/data/<service> key=value ...`
6. **Deploy** — `ansible-playbook deployments/deploy_<service>.yml -e "@vars/vault_auth_vars.yml"`
7. **Add to Caddy** — add a reverse proxy block in `roles/caddy/templates/Caddyfile.j2`, then redeploy Caddy.
8. **Add DNS** — create a DNS rewrite in AdGuard: `<service>.mol.la → <ip>`.
9. **Monitoring** — run `deploy_node_exporter.yml`, then redeploy monitoring (node targets auto-derive from `proxmox_containers`).

---
