# Local vars (not in Git)

Create `proxmox_create_vars.yml` here with your Proxmox API credentials and container root password.

**Required variables:**

- `proxmox_api_user` — e.g. `root@pam`
- `proxmox_api_token_id` — token **name** only (e.g. `ansible`), **not** `root@pam!ansible`
- `proxmox_api_token_secret` — token secret
- `proxmox_container_password` — root password for the new LXC containers

Alternatively use `proxmox_api_password` instead of token id/secret.

**Permissions:** The Proxmox API user/token must be allowed to create VMs/containers on the target node and use the chosen storage/template. 403 errors usually mean insufficient permissions.

This file is ignored by `.gitignore` (`*_vars.yml`). Do not commit it.
