# OCI A1 Flex — AI Inference

OCI Always-Free Ampere A1 Flex instance running **Ollama + Qwen3.6:27b** for homelab agent use (NanoClaw/Timothy). No public exposure — access via Tailscale only. Infrastructure managed via GitHub Actions.

## Hardware

| Resource | Value |
|---|---|
| Shape | VM.Standard.A1.Flex |
| OCPU | 4 (Arm Neoverse N1) |
| RAM | 24 GB |
| Boot volume | 100 GB |
| Cost | $0 (Always-Free) |

## Model

**`qwen3.6:27b`** (default Q4 quant, ~17 GB)

| Item | Size |
|---|---|
| Model weights | ~17 GB |
| KV cache + runtime | ~4 GB |
| OS + Tailscale | ~1.5 GB |
| **Headroom** | **~1.5 GB** |

Expected throughput: **3–6 tok/s** on 4× Neoverse N1 (CPU-only, bandwidth-bound). Acceptable for agentic non-streaming calls.

> `qwen3.6:35b` (24 GB) is off the table — zero headroom after OS overhead.

---

## Prerequisites

- OCI account with A1 Always-Free quota available
- OCI CLI installed and configured (`~/.oci/config`)
- Tailscale account with an ephemeral auth key (`tag:homelab`, pre-authorized)

---

## One-Time Bootstrap

Bootstrap creates the S3-compatible state bucket and injects the Customer Secret Key back into GHA secrets — fully automated via GitHub Actions. Only the initial OCI credentials need manual entry.

### 1. Get OCI identifiers (OCI Console or CLI)

```bash
oci iam tenancy get --query 'data.id' --raw-output          # tenancy OCID
oci iam user list --query 'data[0].id' --raw-output          # user OCID
oci os ns get --query 'data' --raw-output                    # object storage namespace
oci iam availability-domain list --query 'data[].name'       # availability domains
```

### 2. Set initial GitHub secrets and variables manually

These are set once and never change. The bootstrap workflow sets the remaining two secrets automatically.

#### Repository secrets (`Settings → Secrets → Actions`):

| Secret | Value |
|---|---|
| `OCI_TENANCY_OCID` | Tenancy OCID |
| `OCI_USER_OCID` | User OCID |
| `OCI_FINGERPRINT` | API key fingerprint |
| `OCI_PRIVATE_KEY_CONTENT` | Full PEM content of `~/.oci/oci_api_key.pem` |
| `OCI_COMPARTMENT_OCID` | Compartment OCID |
| `OCI_SSH_PUBLIC_KEY` | `cat ~/.ssh/id_ed25519.pub` |
| `TAILSCALE_AUTH_KEY_OCI` | Tailscale ephemeral auth key (`tag:homelab`, pre-authorized) |
| `GH_PAT` | GitHub classic PAT with `repo` scope (used by bootstrap to write secrets) |

#### Repository variables (`Settings → Variables → Actions`):

| Variable | Value |
|---|---|
| `OCI_REGION` | e.g. `eu-frankfurt-1` |
| `OCI_AVAILABILITY_DOMAIN` | e.g. `XoEF:EU-FRANKFURT-1-AD-1` |
| `OCI_STATE_NAMESPACE` | Object storage namespace from step 1 |
| `OCI_STATE_BUCKET` | `homelab-tfstate` |

### 3. Run the bootstrap workflow

**Actions → OCI Bootstrap → Run workflow**

This creates the `homelab-tfstate` bucket (idempotent) and a Customer Secret Key, then automatically sets `OCI_STATE_ACCESS_KEY` and `OCI_STATE_SECRET_KEY` as repository secrets. Run once — or re-run if the secret key is rotated.

---

## Deployment (GitHub Actions)

Trigger from **Actions → OCI AI Inference → Run workflow**:

- **plan** — always runs on push to `main` touching `terraform/**`; also manual
- **apply** — manual only, deploys the instance
- **destroy** — manual only, tears down everything

> `destroy` is manual-only and requires `main` branch. No accidental teardown from PRs.

---

## Post-Provisioning

### Wait for cloud-init (~15–25 min)

cloud-init installs Tailscale, Ollama, pulls `qwen3.6:27b` (~17 GB), and hardens UFW.

```bash
# SSH in during bootstrap via the public IP shown in Terraform output
ssh ubuntu@<public_ip>
sudo tail -f /var/log/cloud-init-output.log
sudo journalctl -u ollama-pull-model.service -f
```

### Verify

```bash
# From any Tailscale-connected host
curl http://oci-ai-inference:11434/api/tags | jq '.models[].name'
```

Should return `qwen3.6:27b`.

### Run Ansible

```bash
ansible-playbook cloud/oci/ai-inference/ansible/playbooks/deploy_oci_ollama.yml \
  -e "@vars/vault_auth_vars.yml"
```

---

## Local Terraform (optional)

```bash
cd cloud/oci/ai-inference/terraform
cp terraform.tfvars.example terraform.tfvars   # fill in values
cp backend.hcl.example backend.hcl             # fill in values
terraform init -backend-config=backend.hcl
terraform plan
```

---

## Connecting from Timothy / NanoClaw

Set the Ollama base URL to:

```
http://oci-ai-inference:11434
```

The Tailscale hostname resolves on all tailnet nodes. No port forwarding, no public IP.

```bash
curl http://oci-ai-inference:11434/api/generate \
  -d '{"model":"qwen3.6:27b","prompt":"ping","stream":false}'
```

---

## Monitoring

node-exporter on port 9100. UFW allows scraping from `192.168.178.124` (Prometheus) only.

OCI node registered as Prometheus scrape target via `inventory/host_vars/monitoring.yml`. Requires monitoring LXC enrolled in Tailscale with MagicDNS. If MagicDNS unavailable, replace hostname with static Tailscale IP in `monitoring.yml`.

Activate:
```bash
./lab deploy monitoring
```

Suggested Grafana alerts:
- `node_memory_MemAvailable_bytes{instance="oci-ai-inference"} < 512000000` — OOM risk
- `node_load1{instance="oci-ai-inference"} > 4` — sustained overload

---

## Updating the Model

```bash
ssh ubuntu@oci-ai-inference
ollama pull qwen3.6:27b   # update in place
ollama rm <old-model>     # free disk if switching
```

Or change `ollama_model` in `roles/oci_ollama/defaults/main.yml` and re-run Ansible.

---

## Rollback / Destroy

Trigger **Actions → OCI AI Inference → Run workflow → destroy**.

> **Warning:** Permanently deletes the instance and boot volume. Model weights re-downloaded on next apply (~17 GB).

---

## Cost & Quota Safety

- OCI Always-Free A1: **4 OCPU + 24 GB RAM total** — this instance uses the full allocation.
- Boot volume: 100 GB of 200 GB free block storage.
- Object Storage state: negligible size, Always-Free Standard tier (20 GB free).
- Outbound bandwidth: 10 TB/month free.
- No paid resources provisioned. If OCI introduces charges, trigger destroy immediately.

---

## File Layout

```
cloud/oci/ai-inference/
├── terraform/
│   ├── versions.tf               # provider, Terraform version, S3 backend
│   ├── main.tf                   # VCN, subnet, security list, instance
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example  # local use template
│   ├── backend.hcl.example       # local backend config template
│   └── files/
│       └── cloud-init.yml.tftpl  # bootstrap: Tailscale + Ollama + UFW
└── ansible/
    └── playbooks/
        └── deploy_oci_ollama.yml # role resolved from top-level roles/oci_ollama/

.github/workflows/
├── oci-bootstrap.yml             # one-time: create state bucket + set GHA secrets
└── oci-ai-inference.yml          # plan / apply / destroy
```
