variable "tenancy_ocid"        { type = string }
variable "user_ocid"           { type = string }
variable "fingerprint"         { type = string }
variable "private_key_path"    { type = string; default = "" }
variable "private_key_content" { type = string; sensitive = true; default = "" }
variable "region"              { type = string }
variable "compartment_ocid"    { type = string }
variable "availability_domain" { type = string }
variable "ssh_public_key"      { type = string }
variable "tailscale_auth_key"  { type = string; sensitive = true }
variable "vllm_model"          { type = string; default = "mistralai/Mistral-7B-Instruct-v0.3" }
