output "ids" {
  description = "Map of VM name to resource id."
  value       = module.windows_vm.ids
}

output "ids_zipmap" {
  description = "Map of VM name to { name, id }."
  value       = module.windows_vm.ids_zipmap
}

output "private_ip_addresses" {
  description = "Map of VM name to private IP (resolvable via the private DNS zones)."
  value       = module.windows_vm.private_ip_addresses
}

output "identity_principal_ids" {
  description = "Map of VM name to system identity principal id (RBAC targets)."
  value       = module.windows_vm.identity_principal_ids
}

output "data_disk_ids" {
  description = "Map of vm|disk to managed disk id."
  value       = module.windows_vm.data_disk_ids
}

output "data_collection_rule_id" {
  description = "The VM Insights DCR the VMs are associated with."
  value       = module.windows_vm.data_collection_rule_id
}

output "bastion_dns_names" {
  description = "The bastion's DNS name (the door to the VMs)."
  value       = module.bastion.dns_names
}

output "admin_password_secret_ids" {
  description = "The vaulted admin password (write-only secret) an operator retrieves."
  value       = module.keyvault_secret.secret_ids
}
