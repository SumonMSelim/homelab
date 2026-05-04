terraform {
  required_version = ">= 1.15.1"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }

  # OCI Object Storage (S3-compatible) — Always-Free Standard tier.
  # Bootstrap the bucket before first apply — see README.
  backend "s3" {
    # All backend config passed via -backend-config in CI or backend.hcl locally.
    # Do not hardcode values here — region/bucket differ per operator.
  }
}

# When running locally, set private_key_path and leave private_key empty.
# In CI, private_key is populated from GHA secret; private_key_path is ignored.
provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path != "" ? var.private_key_path : null
  private_key      = var.private_key_content != "" ? var.private_key_content : null
  region           = var.region
}
