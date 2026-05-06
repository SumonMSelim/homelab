output "public_ip"  { value = oci_core_instance.this.public_ip }
output "id"         { value = oci_core_instance.this.id }
output "hostname"   { value = var.name }
