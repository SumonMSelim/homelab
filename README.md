# Homelab

Source-of-truth for a Proxmox-based homelab: Ansible playbooks and roles to create LXC/VM guests and deploy services.

## Prerequisites

- Ansible installed on the ansible LXC (`pip install ansible-core`)
- Access to the Proxmox API and target hosts
- Vars files in `vars/` on the ansible LXC (see `vars/*.example`)
- SSH access from your machine to the ansible LXC (`ansible_user@192.168.178.120`)

## Usage

All commands run via the `lab` script from your local machine. It SSHes into the ansible LXC, pulls the latest code, and runs the playbook there.

```bash
./lab <command> [options]
```

> **macOS:** requires bash 4+ — `brew install bash`

Run `./lab help` to see all commands.

## Infrastructure

```bash
./lab lxc create              # create all LXC containers
./lab lxc destroy             # destroy all LXC containers (prompts for confirmation)
./lab lxc destroy 253         # destroy a single container
```

Requires `vars/proxmox_create_vars.yml` (Proxmox API token + container password).

## Deploy Services

```bash
./lab deploy <service>        # deploy (or redeploy) a service
./lab deploy                  # list all available services
```

| Service | Description | Requires |
|---|---|---|
| `adguard` | AdGuard Home (DNS + DHCP) | — |
| `caddy` | Caddy reverse proxy + Cloudflare Tunnel | `caddy_vars.yml` |
| `pocketid` | PocketID identity + Tinyauth | `pocketid_vars.yml` |
| `vault` | HashiCorp Vault | — |
| `postgresql` | PostgreSQL | `vault_auth_vars.yml` |
| `mysql` | MySQL | `vault_auth_vars.yml` |
| `redis` | Redis | `vault_auth_vars.yml` |
| `mongodb` | MongoDB | `vault_auth_vars.yml` |
| `monitoring` | Prometheus + Grafana | `vault_auth_vars.yml` |
| `node-exporter` | Node Exporter (all hosts) | — |
| `pve-exporter` | Proxmox VE metrics exporter | `vault_auth_vars.yml` |
| `jellyfin` | Jellyfin media server | — |
| `arr` | *arr stack (Radarr, Sonarr, SABnzbd, etc.) | — |
| `immich` | Immich photo/video backup | `vault_auth_vars.yml` |

Redeploying an existing service is safe — it applies config changes and restarts only if something changed.

## Upgrade Services

```bash
./lab upgrade                 # pull latest images + restart all services
./lab upgrade arr             # upgrade a single service
```

Services with pinned versions (`immich`, `vault`, `mongodb`, `pve-exporter`) must have their version bumped in `roles/<service>/defaults/main.yml` before redeploying.

## Configure Vault

```bash
./lab vault-config <root-token>
```

Requires `vars/vault_config_vars.yml`.

## Notes

### Adding a new LXC

1. Add the container to `proxmox_containers` in `roles/proxmox_create_lxc/defaults/main.yml` (vmid, hostname, IP, resources)
2. Run `./lab lxc create` — existing containers are skipped, only new ones are created

If you want to deploy services to it via Ansible (not manage it manually):

3. Add the host and group to `inventory/hosts`
4. Add it to `prometheus_scrape_jobs` in `roles/monitoring/defaults/main.yml`, then:
   ```bash
   ./lab deploy node-exporter
   ./lab deploy monitoring
   ```

- After deploying a new service that Caddy should proxy, redeploy Caddy: `./lab deploy caddy`

### Immich prerequisites

Uses central PostgreSQL and Redis. Before deploying:
- Ensure `immich` user/db exist in `postgresql_apps`
- PostgreSQL has `pgvector` extension
- Vault `kv/homelab/data/postgresql` has key `immich` (db password)

OIDC (PocketID): create client at `https://id.mol.la/settings/admin/oidc-clients` with redirect URIs `https://photos.mol.la/auth/login`, `https://photos.mol.la/user-settings`, `app.immich:///oauth-callback`; then:
```bash
vault kv put kv/homelab/data/immich_oidc client_id="..." client_secret="..."
```
