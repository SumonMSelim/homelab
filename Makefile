# Homelab IaC — run from your laptop (or any host that can reach the Proxmox API).
# You need Ansible installed: brew install ansible (macOS) or pip install ansible-core

.PHONY: help create-lxc destroy-lxc deploy-caddy deploy-pocketid deploy-adguard

help:
	@echo "Homelab IaC — usage:"
	@echo "  make create-lxc        Create LXC containers on Proxmox (uses vars/proxmox_create_vars.yml)"
	@echo "  make destroy-lxc       Destroy all LXCs from proxmox_containers"
	@echo "  make destroy-lxc CTID=253   Destroy only container 253"
	@echo "  make deploy-caddy      Deploy Caddy + Cloudflare Tunnel (uses vars/caddy_vars.yml)"
	@echo "  make deploy-pocketid   Deploy PocketID (uses vars/pocketid_vars.yml)"
	@echo "  make deploy-adguard    Deploy AdGuard Home on dns hosts"
	@echo ""
	@echo "First time: install Ansible, then create vars files in vars/"

create-lxc:
	ansible-playbook deployments/create_lxc.yml -e "@vars/proxmox_create_vars.yml"

destroy-lxc:
	ansible-playbook deployments/destroy_lxc.yml -e "@vars/proxmox_create_vars.yml" $(if $(CTID),-e "vmid=$(CTID)",)

deploy-caddy:
	ansible-playbook deployments/deploy_caddy.yml -e "@vars/caddy_vars.yml"

deploy-pocketid:
	ansible-playbook deployments/deploy_pocketid.yml -e "@vars/pocketid_vars.yml"

deploy-adguard:
	ansible-playbook deployments/deploy_adguard.yml
