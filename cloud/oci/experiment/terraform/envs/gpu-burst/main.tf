locals {
  tags = {
    project = "oci-experiment"
    env     = "gpu-burst"
    ttl     = "2026-05-20"
  }
}

module "network" {
  source           = "../../modules/network"
  compartment_ocid = var.compartment_ocid
  name             = "exp-gpu"
  vcn_cidr         = "10.22.0.0/16"
  subnet_cidr      = "10.22.0.0/24"
  tags             = local.tags
}

module "gpu" {
  source              = "../../modules/compute"
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_id           = module.network.subnet_id
  name                = "oci-exp-gpu"
  shape               = "VM.GPU.A10.1"
  ocpus               = 15
  memory_gbs          = 240
  boot_volume_gb      = 200
  ssh_public_key      = var.ssh_public_key
  tailscale_auth_key  = var.tailscale_auth_key
  use_vllm            = true
  vllm_model          = var.vllm_model
  tags                = local.tags
}
