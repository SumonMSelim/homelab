# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Does

Ansible-based IaC for a Proxmox homelab. Services run as Docker Compose stacks inside unprivileged LXC containers on `192.168.178.0/24`. Every service gets its own LXC with a fixed IP.

## Commands

The primary interface is `./lab` — a bash wrapper that SSHes into the ansible LXC (`192.168.178.120`), does `git pull`, and runs the playbook there. Run from your local machine; requires bash 4+ (`brew install bash` on macOS).

```bash
./lab deploy <service>        # deploy/redeploy a service
./lab deploy                  # list available services
./lab upgrade                 # pull latest images + restart all Docker Compose services
./lab upgrade <service>       # upgrade a single service
./lab lxc create              # create all LXC containers (requires vars/proxmox_create_vars.yml)
./lab lxc destroy [vmid]      # destroy all or one container
./lab vault-config <token>    # configure Vault (requires vars/vault_config_vars.yml)
./lab help
```

Fallback direct invocation (if needed):
```bash
ansible-galaxy install -r requirements.yml
ansible-playbook deployments/deploy_<service>.yml -vv
```

Makefile aliases (equivalent to `./lab lxc`):
```bash
make create-lxc    # same as ./lab lxc create
make destroy-lxc   # same as ./lab lxc destroy
```

`ansible.cfg` sets `become_ask_pass = True` — playbooks prompt for sudo password unless `ansible_become_pass` is set in `vars/vault_auth_vars.yml`.

No test suite or linter. Validation is manual (SSH into deployed hosts, verify Docker Compose status).

### Pinned-version services

These services use explicit version vars in `roles/<service>/defaults/main.yml` — bump the var before redeploying to upgrade:

| Service        | Var                    |
|----------------|------------------------|
| `immich`       | `immich_version`       |
| `vault`        | `vault_version`        |
| `mongodb`      | `mongodb_version`      |
| `pve-exporter` | `pve_exporter_version` |
| `pocketid`     | `pocketid_image`       |
| `tinyauth`     | `tinyauth_image`       |

## Architecture

```
inventory/hosts          → static inventory with groups (core, data_services, dns, applications)
inventory/group_vars/    → per-group Ansible variables
inventory/host_vars/     → per-host overrides (e.g. adguard_primary uses host network for DHCP)
deployments/             → one playbook per service
roles/                   → one role per service (tasks, templates, defaults, handlers)
vars/                    → runtime secrets/config (gitignored); *.example files are templates
```

### Core Infrastructure

| IP              | Service                           | Runtime        |
|-----------------|-----------------------------------|----------------|
| 192.168.178.110 | Proxmox host                      | —              |
| 192.168.178.120 | Ansible control                   | —              |
| 192.168.178.121 | Caddy (reverse proxy + Tunnel)    | Docker Compose |
| 192.168.178.122 | PocketID (OIDC) + Tinyauth        | Docker Compose |
| 192.168.178.123 | Vault                             | systemd binary |
| 192.168.178.124 | Monitoring (Prometheus + Grafana) | systemd apt    |
| 192.168.178.130 | PostgreSQL                        | systemd apt    |
| 192.168.178.131 | MariaDB                           | systemd apt    |
| 192.168.178.132 | Redis                             | systemd apt    |
| 192.168.178.133 | MongoDB                           | systemd apt    |
| 192.168.178.125 | LLM (Ollama + Gemma 4)            | Docker Compose |
| 192.168.178.140 | Jellyfin                          | Docker Compose |
| 192.168.178.141 | *arr stack                        | Docker Compose |
| 192.168.178.142 | Immich                            | Docker Compose |
| 192.168.178.250 | Dash (Open WebUI + dashboards)    | Docker Compose |
| 192.168.178.251 | OpenClaw AI agent                 | Node.js        |
| 192.168.178.252 | Humaun                            | Docker Compose |
| 192.168.178.253 | AdGuard Primary                   | Docker Compose |
| 192.168.178.254 | AdGuard Secondary                 | Docker Compose |

### Vars Files Required Per Playbook

Most playbooks need runtime secrets that are gitignored. Copy the `.example` file and fill in values.

| Playbook          | Required vars flags                                             |
|-------------------|-----------------------------------------------------------------|
| deploy_caddy      | `-e "@vars/caddy_vars.yml"`                                     |
| deploy_pocketid   | `-e "@vars/pocketid_vars.yml"`                                  |
| configure_vault   | `-e "vault_token=<root>" -e "@vars/vault_config_vars.yml"`      |
| deploy_monitoring | `-e "@vars/vault_auth_vars.yml"`                                |
| deploy_postgresql | `-e "@vars/vault_auth_vars.yml" -e "@vars/postgresql_apps.yml"` |
| deploy_mysql      | `-e "@vars/vault_auth_vars.yml"`                                |
| deploy_redis      | `-e "@vars/vault_auth_vars.yml"`                                |
| deploy_immich     | `-e "@vars/vault_auth_vars.yml"`                                |
| create_lxc        | `-e "@vars/proxmox_create_vars.yml"`                            |

### Patterns to Follow When Adding a Service

1. **New LXC**: add entry to `proxmox_containers` in `roles/proxmox_create_lxc/defaults/main.yml`, run `./lab lxc create`
2. **New role** at `roles/<service>/` with `tasks/main.yml`, `templates/compose.yml.j2`, optionally `defaults/main.yml` and `handlers/main.yml`
3. **New playbook** at `deployments/deploy_<service>.yml` targeting the host
4. **Add host** to `inventory/hosts` under the appropriate group
5. **Add group_vars** at `inventory/group_vars/<service>_host.yml` for service-specific variables
6. **Add vars template** at `vars/<service>_vars.yml.example` for any secrets/config needed at deploy time
7. **Deploy**: `./lab deploy node-exporter`, then `./lab deploy <service>`
8. **DNS rewrite** entry in AdGuard Home: `<domain>:<ip>`
9. **Add scrape target** to `roles/monitoring/defaults/main.yml` → `prometheus_node_targets`; run `./lab deploy monitoring`
10. **Open UFW port** for monitoring host scrape: allow `192.168.178.124` → port `9100` (see `roles/node_exporter`)
11. **Caddy**: add route to `roles/caddy/templates/Caddyfile.j2`, run `./lab deploy caddy`

### Ansible Galaxy Collections

```
community.proxmox, community.docker, community.hashi_vault, community.postgresql, community.mysql
```

Install before first run: `ansible-galaxy install -r requirements.yml`

### Key Conventions

- Docker Compose files are templated via Jinja2 (`compose.yml.j2`) and deployed to `/opt/compose/<service>-{{ inventory_hostname }}/`
- `container_name: <service>-{{ inventory_hostname }}`
- All services use `restart: unless-stopped` and named volumes
- Secrets come from Vault via AppRole auth — never hardcode them; use `vars/vault_auth_vars.yml` at runtime
- Caddy handles all SSL termination and external access (including Cloudflare Tunnel); services listen internally only
- Caddy uses a custom Dockerfile (in `roles/caddy/files/`) that builds the Cloudflare DNS plugin via `xcaddy`; runs in `network_mode: host`
- Caddy Caddyfile defines a reusable `(protected)` snippet for Tinyauth forward-auth; import it with `import protected` on protected routes
- Database roles (postgresql, mysql, mongodb) have a `create_app.yml` task file separate from `main.yml` — included by playbooks that need per-app users/databases. PostgreSQL apps also specify extensions (e.g. `vector`, `earthdistance` for Immich).
- PostgreSQL has pgvector installed for Immich; `pg_hba.conf` is templated
- Monitoring: Prometheus + Grafana scrape all hosts via node_exporter; add new scrape targets in `roles/monitoring/defaults/main.yml` → `prometheus_node_targets`
- AdGuard Primary runs in host network mode (required for DHCP broadcasts); Secondary uses bridge
- *arr stack runs as uid/gid 0:0 — unprivileged LXC quirk so containers can write to bind-mounted media
- Media bind-mount directories are set to 0777 on the Proxmox host (see `deployments/create_lxc.yml`) to allow unprivileged container writes

### Vault Secret Paths

All secrets live under `kv/homelab/data/<service>` (kv-v2 engine):

| Path                          | Keys                                  |
|-------------------------------|---------------------------------------|
| `kv/homelab/data/postgresql`  | `homelab_password`, `immich_password` |
| `kv/homelab/data/redis`       | `redis_password`                      |
| `kv/homelab/data/mysql`       | `mysql_password`                      |
| `kv/homelab/data/grafana`     | `client_id`, `client_secret` (OIDC)   |
| `kv/homelab/data/immich_oidc` | `client_id`, `client_secret` (OIDC)   |
| `kv/homelab/pve-exporter`     | `user`, `token_name`, `token_value`   |

Vault reads always use `delegate_to: localhost` + `become: false` (runs on Ansible control, not target host).
