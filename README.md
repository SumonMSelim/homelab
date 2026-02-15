# Homelab

Source-of-truth for a Proxmox-based homelab: Ansible playbooks and roles to create LXC/VM guests and deploy services.

## Prerequisites

- Ansible installed (`brew install ansible` on macOS or `pip install ansible-core`)
- Access to the Proxmox API and target hosts
- Create vars files in `vars/` (see `vars/*.example`)

## Deploy Commands

Run from the project root. Some playbooks require a vars file via `-e "@vars/<name>_vars.yml"`.

### Infrastructure

**Create LXC containers (Proxmox):**
```bash
ansible-playbook deployments/create_lxc.yml -e "@vars/proxmox_create_vars.yml"
```

**Destroy LXC containers:**
```bash
ansible-playbook deployments/destroy_lxc.yml -e "@vars/proxmox_create_vars.yml"
ansible-playbook deployments/destroy_lxc.yml -e "@vars/proxmox_create_vars.yml" -e "vmid=253"  # single container
```

### Playbooks

**AdGuard Home (DNS+DHCP):**
```bash
ansible-playbook deployments/deploy_adguard.yml
```

**Caddy (reverse proxy + Cloudflare Tunnel):**
```bash
ansible-playbook deployments/deploy_caddy.yml -e "@vars/caddy_vars.yml"
```

**PocketID (identity + Tinyauth):**
```bash
ansible-playbook deployments/deploy_pocketid.yml -e "@vars/pocketid_vars.yml"
```

**HashiCorp Vault (secrets management):**
```bash
ansible-playbook deployments/deploy_vault.yml
```

**Configure Vault (kv-v2, AppRole, OIDC, policies):**
```bash
ansible-playbook deployments/configure_vault.yml -e "vault_token=<root-token>" -e "@vars/vault_config_vars.yml"
```

**PostgreSQL (database server):**
```bash
ansible-playbook deployments/deploy_postgresql.yml -e "@vars/vault_auth_vars.yml" -e "@vars/postgresql_apps.yml"
```

> After deploying a new service that Caddy should proxy, redeploy Caddy to update routes.

---
