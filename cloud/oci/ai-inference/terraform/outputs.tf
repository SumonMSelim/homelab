output "instance_id" {
  description = "OCID of the compute instance"
  value       = oci_core_instance.ai_inference.id
}

output "public_ip" {
  description = "Ephemeral public IP (for bootstrap only; use Tailscale IP after first boot)"
  value       = oci_core_instance.ai_inference.public_ip
}

output "tailscale_hostname" {
  description = "Hostname registered in Tailscale"
  value       = var.instance_display_name
}

output "ollama_endpoint_tailscale" {
  description = "Ollama API endpoint reachable over Tailscale"
  value       = "http://${var.instance_display_name}:11434"
}
