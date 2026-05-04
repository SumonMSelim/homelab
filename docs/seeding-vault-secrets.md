# Seeding Vault Secrets

All service secrets live in Vault under `kv/homelab/data/<service>`. Seed them once after bootstrapping Vault. Vault must be initialized, unsealed, and AppRole configured before running any service deploys.

Substitute `<root_token>` with your Vault root token. All `curl` commands can be run from the Ansible LXC (`192.168.178.120`).

---

## Helper

All examples use curl. If you prefer the Vault UI: **Secrets → kv/homelab → Create secret** with the path and keys below.

```bash
VAULT=http://192.168.178.123:8200
TOKEN=<root_token>
```

---

## Caddy

**Where to get values:**

- `cloudflare_api_token` — [dash.cloudflare.com](https://dash.cloudflare.com) → My Profile → API Tokens → Create Token → *Edit zone DNS* template → scope to `mol.la`
- `cloudflare_tunnel_token` — Zero Trust → Networks → Tunnels → your tunnel → Configure → Docker command → copy the `--token` value
- `cloudflare_account_email` — your Cloudflare account email

```bash
curl -s -X POST $VAULT/v1/kv/homelab/data/caddy \
  -H "X-Vault-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "cloudflare_api_token": "YOUR_CF_API_TOKEN",
      "cloudflare_tunnel_token": "YOUR_TUNNEL_TOKEN",
      "cloudflare_account_email": "you@example.com"
    }
  }'
```

---

## PocketID + Tinyauth

**Where to get values:**

- `pocketid_encryption_key` — generate randomly (see below)
- `tinyauth_pocketid_client_id` / `tinyauth_pocketid_client_secret` — create OIDC client at `https://id.mol.la/settings/admin/oidc-clients`, callback URL: `https://id.mol.la/api/oauth/callback/pocketid`
- `pocketid_maxmind_license_key` — optional, leave empty if not using GeoIP

```bash
curl -s -X POST $VAULT/v1/kv/homelab/data/pocketid \
  -H "X-Vault-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"data\": {
      \"pocketid_encryption_key\": \"$(openssl rand -base64 32)\",
      \"tinyauth_pocketid_client_id\": \"YOUR_CLIENT_ID\",
      \"tinyauth_pocketid_client_secret\": \"YOUR_CLIENT_SECRET\",
      \"pocketid_maxmind_license_key\": \"\"
    }
  }"
```

---

## PostgreSQL

```bash
curl -s -X POST $VAULT/v1/kv/homelab/data/postgresql \
  -H "X-Vault-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "homelab_password": "STRONG_PASSWORD",
      "immich_password": "STRONG_PASSWORD"
    }
  }'
```

---

## Redis

```bash
curl -s -X POST $VAULT/v1/kv/homelab/data/redis \
  -H "X-Vault-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "password": "STRONG_PASSWORD"
    }
  }'
```

---

## MySQL

```bash
curl -s -X POST $VAULT/v1/kv/homelab/data/mysql \
  -H "X-Vault-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "mysql_password": "STRONG_PASSWORD"
    }
  }'
```

---

## MongoDB

```bash
curl -s -X POST $VAULT/v1/kv/homelab/data/mongodb \
  -H "X-Vault-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "admin_password": "STRONG_PASSWORD",
      "homelab": "STRONG_PASSWORD"
    }
  }'
```

---

## Grafana OIDC

**Where to get values:** Create OIDC client at `https://id.mol.la/settings/admin/oidc-clients`, callback URL: `https://grafana.mol.la/login/generic_oauth`

```bash
curl -s -X POST $VAULT/v1/kv/homelab/data/grafana \
  -H "X-Vault-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "client_id": "YOUR_CLIENT_ID",
      "client_secret": "YOUR_CLIENT_SECRET"
    }
  }'
```

---

## Immich OIDC

**Where to get values:** Create OIDC client at `https://id.mol.la/settings/admin/oidc-clients`, redirect URIs:
- `https://photos.mol.la/auth/login`
- `https://photos.mol.la/user-settings`
- `app.immich:///oauth-callback`

```bash
curl -s -X POST $VAULT/v1/kv/homelab/data/immich_oidc \
  -H "X-Vault-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "client_id": "YOUR_CLIENT_ID",
      "client_secret": "YOUR_CLIENT_SECRET"
    }
  }'
```

---

## PVE Exporter

**Where to get values:** Proxmox UI → Datacenter → Permissions → API Tokens → Add. Use `root@pam`, token ID `prometheus`, uncheck Privilege Separation.

```bash
curl -s -X POST $VAULT/v1/kv/homelab/data/pve-exporter \
  -H "X-Vault-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "user": "root@pam",
      "token_name": "prometheus",
      "token_value": "YOUR_TOKEN_VALUE"
    }
  }'
```

---

## Vault OIDC (for Vault UI login via PocketID)

**Where to get values:** Create OIDC client at `https://id.mol.la/settings/admin/oidc-clients`, callback URL: `https://vault.mol.la/ui/vault/auth/oidc/oidc/callback`

These go in `vars/vault_config_vars.yml` (not Vault), used during `./lab vault-config`:

```yaml
vault_oidc_client_id: "YOUR_CLIENT_ID"
vault_oidc_client_secret: "YOUR_CLIENT_SECRET"
```

---

## Verify a secret was stored correctly

```bash
curl -s -H "X-Vault-Token: $TOKEN" \
  $VAULT/v1/kv/homelab/data/<service> | python3 -m json.tool
```
