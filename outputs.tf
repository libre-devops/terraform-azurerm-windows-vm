output "asg_ids" {
  description = "List of ASG IDs."
  value       = [for k, v in azurerm_application_security_group.asg : v.id]
}

output "asg_names" {
  description = "List of ASG Names."
  value       = [for k, v in azurerm_application_security_group.asg : k]
}

output "managed_identities" {
  description = "Managed identities of the VMs"
  value       = [for k, v in azurerm_windows_virtual_machine.this : v.identity[0].type if length(v.identity) > 0]
}

output "nic_private_ipv4_addresses" {
  description = "List of NIC Private IPv4 Addresses."
  value       = [for k, v in azurerm_network_interface.nic : v.ip_configuration[0].private_ip_address]
}

output "public_ip_ids" {
  description = "List of Public IP IDs."
  value       = [for k, v in azurerm_public_ip.pip : v.id]
}

output "public_ip_names" {
  description = "List of Public IP Names."
  value       = [for k, v in azurerm_public_ip.pip : k]
}

output "public_ip_values" {
  description = "List of Public IP Addresses."
  value       = [for k, v in azurerm_public_ip.pip : v.ip_address]
}

output "vm_details_map" {
  description = "A map where the key is the VM name and the value is another map containing the VM ID and private IP address."
  value = {
    for k, v in azurerm_windows_virtual_machine.this :
    k => {
      id         = v.id,
      private_id = azurerm_network_interface.nic[k].ip_configuration[0].private_ip_address
    }
  }
}

output "vm_ids" {
  description = "List of VM IDs."
  value       = [for k, v in azurerm_windows_virtual_machine.this : v.id]
}

output "vm_names" {
  description = "List of VM Names."
  value       = [for k, v in azurerm_windows_virtual_machine.this : k]
}
