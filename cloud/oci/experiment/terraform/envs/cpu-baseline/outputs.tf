output "public_ip"         { value = module.cpu.public_ip }
output "tailscale_hostname" { value = module.cpu.hostname }
output "ollama_endpoint"    { value = "http://${module.cpu.hostname}:11434" }
