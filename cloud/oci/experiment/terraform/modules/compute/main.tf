locals {
  cloud_init = base64encode(templatefile("${path.module}/cloud-init.yml.tftpl", {
    tailscale_auth_key = var.tailscale_auth_key
    ollama_model       = var.ollama_model
    hostname           = var.name
    use_vllm           = var.use_vllm
    vllm_model         = var.vllm_model
  }))
}

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "this" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = var.name
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = true
    hostname_label   = replace(var.name, "-", "")
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = local.cloud_init
  }

  freeform_tags = var.tags

  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}
