############################
# Outputs
############################
output "key_vault_uri" {
  description = "URI del Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

output "vm_private_ip" {
  description = "IP privada de la VM"
  value       = azurerm_network_interface.nic.private_ip_address
}

output "vm_admin_password" {
  description = "Password admin VM (sensible)"
  sensitive   = true
  value       = random_password.vm_admin_pass.result
}