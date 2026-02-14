# Homelab IaC — run from your laptop (or any host that can reach the Proxmox API).
# You need Ansible installed: brew install ansible (macOS) or pip install ansible-core

.PHONY: create-lxc destroy-lxc help

create-lxc:
	ansible-playbook deployments/create_lxc.yml -e "@vars/proxmox_create_vars.yml"

destroy-lxc:
	ansible-playbook deployments/destroy_lxc.yml -e "@vars/proxmox_create_vars.yml" $(if $(CTID),-e "vmid=$(CTID)",)

help:
	@echo "Homelab IaC — usage:"
	@echo "  make create-lxc        Create LXC containers on Proxmox (uses vars/proxmox_create_vars.yml)"
	@echo "  make destroy-lxc       Destroy all LXCs from proxmox_containers"
	@echo "  make destroy-lxc CTID=253   Destroy only container 253"
	@echo ""
	@echo "First time: install Ansible, then create vars files in vars/"
