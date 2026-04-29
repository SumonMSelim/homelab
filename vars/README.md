# vars/

Operator-supplied variable files. These are **not** committed to git (except `.example` templates).

## Setup

Copy each `.example` file, remove the `.example` suffix, and fill in your values:

```bash
cp vars/proxmox_create_vars.yml.example vars/proxmox_create_vars.yml
cp vars/vault_auth_vars.yml.example     vars/vault_auth_vars.yml
cp vars/vault_config_vars.yml.example   vars/vault_config_vars.yml
```

## Files

| File | Used by | Contents |
|------|---------|----------|
| `proxmox_create_vars.yml` | `create_lxc.yml`, `destroy_lxc.yml` | Proxmox API token + container root password |
| `vault_auth_vars.yml` | All service deploys that read from Vault | `vault_addr`, `vault_role_id`, `vault_secret_id` |
| `vault_config_vars.yml` | `configure_vault.yml` | OIDC client ID/secret for Vault UI login |
| `postgresql_apps.yml` | `deploy_postgresql.yml` | List of databases/users to create |
| `mysql_apps.yml` | `deploy_mysql.yml` | List of databases/users to create |
| `mongodb_apps.yml` | `deploy_mongodb.yml` | List of databases/users to create |

## Secrets in Vault

Most service secrets live in Vault (`kv/homelab/data/<service>`), not in local vars files. See the main README for the full `vault kv put` commands needed during first boot.
