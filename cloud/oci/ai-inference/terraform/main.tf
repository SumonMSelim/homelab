locals {
  cloud_init = base64encode(templatefile("${path.module}/files/cloud-init.yml.tftpl", {
    tailscale_auth_key = var.tailscale_auth_key
    ollama_model       = var.ollama_model
    hostname           = var.instance_display_name
  }))
}

# ── Network ────────────────────────────────────────────────────────────────────

resource "oci_core_vcn" "ai_inference" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.instance_display_name}-vcn"
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = "aiinference"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ai_inference.id
  display_name   = "${var.instance_display_name}-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ai_inference.id
  display_name   = "${var.instance_display_name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# Minimal ingress: Tailscale direct UDP + HTTPS for Tailscale DERP fallback.
# SSH (22) intentionally omitted — access via Tailscale only post-bootstrap.
resource "oci_core_security_list" "ai_inference" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.ai_inference.id
  display_name   = "${var.instance_display_name}-sl"

  # Allow all egress (required for Tailscale, Ollama model pull, apt)
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # Tailscale direct WireGuard
  ingress_security_rules {
    protocol  = "17" # UDP
    source    = "0.0.0.0/0"
    stateless = false
    udp_options {
      min = 41641
      max = 41641
    }
  }

  # HTTPS for Tailscale DERP relay fallback
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.ai_inference.id
  cidr_block        = var.subnet_cidr
  display_name      = "${var.instance_display_name}-subnet"
  dns_label         = "pub"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.ai_inference.id]

  # Public subnet — instance gets ephemeral public IP for egress during bootstrap.
  # After Tailscale connects the public IP is unused.
  prohibit_public_ip_on_vnic = false
}

# ── Compute ────────────────────────────────────────────────────────────────────

# Canonical Ubuntu 24.04 LTS for aarch64 — query latest image.
# OCI Always-Free A1 requires aarch64 image.
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "ai_inference" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = var.instance_display_name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    # 4 OCPU + 24 GB = full Always-Free A1 allocation
    ocpus         = 4
    memory_in_gbs = 24
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    hostname_label   = var.instance_display_name
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = local.cloud_init
  }

  # Prevent accidental destroy of the model storage
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}
