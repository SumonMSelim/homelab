variable "compartment_ocid" {
  type = string
}

variable "availability_domain" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "name" {
  type = string
}

variable "shape" {
  type = string
}

variable "ocpus" {
  type = number
}

variable "memory_gbs" {
  type = number
}

variable "boot_volume_gb" {
  type    = number
  default = 100
}

variable "ssh_public_key" {
  type = string
}

variable "tailscale_auth_key" {
  type      = string
  sensitive = true
}

variable "ollama_model" {
  type    = string
  default = ""
}

variable "use_vllm" {
  type    = bool
  default = false
}

variable "vllm_model" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
