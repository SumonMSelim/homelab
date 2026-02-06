# Homelab IaC — run from your laptop (or any host that can reach the Proxmox API).
# You need Ansible installed: brew install ansible (macOS) or pip install ansible-core

.PHONY: help create-lxc

help:
	@echo "Homelab IaC — usage:"
	@echo "  make create-lxc   Create LXC containers on Proxmox (uses vars/proxmox_create_vars.yml)"
	@echo ""
	@echo "First time: install Ansible, then make create-lxc"

create-lxc:
	ansible-playbook deployments/create_lxc.yml -e "@vars/proxmox_create_vars.yml"
