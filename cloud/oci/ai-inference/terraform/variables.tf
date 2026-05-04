variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID"
}

variable "user_ocid" {
  type        = string
  description = "OCI user OCID"
}

variable "fingerprint" {
  type        = string
  description = "API key fingerprint"
}

variable "private_key_path" {
  type        = string
  description = "Path to OCI API private key PEM file (local use). Leave empty in CI."
  default     = ""
}

variable "private_key_content" {
  type        = string
  sensitive   = true
  description = "OCI API private key PEM content (CI use). Leave empty when using private_key_path."
  default     = ""
}

variable "region" {
  type        = string
  description = "OCI region (e.g. eu-frankfurt-1)"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID to deploy resources into"
}

variable "availability_domain" {
  type        = string
  description = "Availability domain name (e.g. get from: oci iam availability-domain list)"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key content for initial bootstrap access"
}

variable "tailscale_auth_key" {
  type        = string
  sensitive   = true
  description = "Tailscale ephemeral auth key (generate at tailscale.com/admin/settings/keys)"
}

variable "instance_display_name" {
  type        = string
  description = "Display name for the OCI instance"
  default     = "oci-ai-inference"
}

variable "boot_volume_size_gb" {
  type        = number
  description = "Boot volume size in GB (free tier allows up to 200 GB total block storage)"
  default     = 100
}

variable "ollama_model" {
  type        = string
  description = "Ollama model tag to pull on first boot (see https://ollama.com/library/qwen3)"
  default     = "qwen3.6:27b"
}

variable "vcn_cidr" {
  type        = string
  description = "CIDR block for the VCN"
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet"
  default     = "10.10.0.0/24"
}
