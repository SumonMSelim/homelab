output "public_ip"         { value = module.gpu.public_ip }
output "tailscale_hostname" { value = module.gpu.hostname }
output "vllm_endpoint"      { value = "http://${module.gpu.hostname}:11434" }
