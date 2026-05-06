terraform {
  required_version = ">= 1.15.1"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }

  backend "s3" {}
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path != "" ? var.private_key_path : null
  private_key      = var.private_key_content != "" ? var.private_key_content : null
  region           = var.region
}
