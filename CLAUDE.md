# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Does

Ansible-based IaC for a Proxmox homelab. Services run as Docker Compose stacks inside unprivileged LXC containers on `192.168.178.0/24`. Every service gets its own LXC with a fixed IP.

## Commands

```bash
# Install Ansible collections
ansible-galaxy install -r requirements.yml

# Provision LXC containers
make create-lxc                    # requires vars/proxmox_create_vars.yml
make destroy-lxc CTID=253          # destroy specific container

# Deploy services (most require -e "@vars/<name>_vars.yml")
ansible-playbook deployments/deploy_caddy.yml -e "@vars/caddy_vars.yml"
ansible-playbook deployments/deploy_postgresql.yml -e "@vars/vault_auth_vars.yml" -e "@vars/postgresql_apps.yml"
ansible-playbook deployments/deploy_vault.yml
ansible-playbook deployments/configure_vault.yml -e "vault_token=<root-token>" -e "@vars/vault_config_vars.yml"

# Verbose output
ansible-playbook deployments/deploy_<service>.yml -vv
```

There is no test suite or linter. Validation is manual (SSH into deployed hosts, verify Docker Compose status).

## Architecture

```
inventory/hosts          → static inventory with groups (core, data_services, dns, applications)
inventory/group_vars/    → per-group Ansible variables
inventory/host_vars/     → per-host overrides
deployments/             → one playbook per service
roles/                   → one role per service (tasks, templates, defaults, handlers)
vars/                    → runtime secrets/config (gitignored); *.example files are templates
```

### Core Infrastructure

| IP              | Service            |
|-----------------|--------------------|
| 192.168.178.110 | Proxmox host       |
| 192.168.178.120 | Ansible control    |
| 192.168.178.121 | Caddy              |
| 192.168.178.122 | PocketID (OIDC)    |
| 192.168.178.123 | Vault              |
| 192.168.178.124 | Monitoring (Prometheus + Grafana) |
| 192.168.178.130 | PostgreSQL         |
| 192.168.178.131 | MariaDB            |
| 192.168.178.132 | Redis              |
| 192.168.178.133 | MongoDB            |
| 192.168.178.140 | Jellyfin           |
| 192.168.178.141 | *arr stack         |
| 192.168.178.142 | Immich             |
| 192.168.178.253 | AdGuard Primary    |
| 192.168.178.254 | AdGuard Secondary  |

### Patterns to Follow When Adding a Service

1. **New role** at `roles/<service>/` with `tasks/main.yml`, `templates/compose.yml.j2`, optionally `defaults/main.yml` and `handlers/main.yml`
2. **New playbook** at `deployments/deploy_<service>.yml` targeting the host
3. **Add host** to `inventory/hosts` under the appropriate group
4. **Add group_vars** at `inventory/group_vars/<service>_host.yml` for service-specific variables
5. **Add vars template** at `vars/<service>_vars.yml.example` for any secrets/config needed at deploy time
6. **DNS rewrite** entry in AdGuard Home: `<domain>:<ip>`

### Key Conventions

- Docker Compose files are templated via Jinja2 (`compose.yml.j2`) and deployed to `/opt/compose/<service>-{{ inventory_hostname }}/`
- `container_name: <service>-{{ inventory_hostname }}`
- All services use `restart: unless-stopped` and named volumes
- Secrets come from Vault via AppRole auth — never hardcode them; use `vars/vault_auth_vars.yml` at runtime
- Caddy handles all SSL termination and external access (including Cloudflare Tunnel); services listen internally only
- Caddy uses a custom Dockerfile (in `roles/caddy/files/`) that includes the Cloudflare DNS plugin
- PostgreSQL has pgvector installed for Immich; `pg_hba.conf` is templated
- Monitoring: Prometheus + Grafana scrape all hosts via node_exporter; add new scrape targets in `inventory/group_vars/monitoring_host.yml`
