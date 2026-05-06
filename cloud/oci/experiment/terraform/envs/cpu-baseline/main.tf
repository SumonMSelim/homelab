locals {
  tags = {
    project = "oci-experiment"
    env     = "cpu-baseline"
    ttl     = "2026-05-20"
  }
}

module "network" {
  source         = "../../modules/network"
  compartment_ocid = var.compartment_ocid
  name           = "exp-cpu"
  vcn_cidr       = "10.21.0.0/16"
  subnet_cidr    = "10.21.0.0/24"
  tags           = local.tags
}

module "cpu" {
  source              = "../../modules/compute"
  compartment_ocid    = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_id           = module.network.subnet_id
  name                = "oci-exp-cpu"
  shape               = "VM.Standard.A1.Flex"
  ocpus               = 16
  memory_gbs          = 128
  ssh_public_key      = var.ssh_public_key
  tailscale_auth_key  = var.tailscale_auth_key
  ollama_model        = var.ollama_model
  tags                = local.tags
}
