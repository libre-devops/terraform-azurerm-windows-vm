output "vm_ids" {
  description = "Virtual machine ids created."
  value       = azurerm_windows_virtual_machine.windows_vm.*.id
}

output "vm_name" {
  value = azurerm_windows_virtual_machine.windows_vm.*.name
}

output "vm_zones" {
  description = "map with key `Virtual Machine Id`, value `list of the Availability Zone` which the Virtual Machine should be allocated in."
  value       = zipmap(azurerm_windows_virtual_machine.windows_vm.*.id, azurerm_windows_virtual_machine.windows_vm.*.zone)
}

output "vm_identity" {
  description = "map with key `Virtual Machine Id`, value `list of identity` created for the Virtual Machine."
  value       = zipmap(azurerm_windows_virtual_machine.windows_vm.*.id, azurerm_windows_virtual_machine.windows_vm.*.identity)
}

output "vm_amount" {
  description = "The amount of VMs passed to the vm_amount variable"
  value       = var.vm_amount
}

output "nic_id" {
  description = "The ID of the nics"
  value = azurerm_network_interface.nic.*.id
}

output "nic_ip_config_name" {
  description = "The name of the IP Configurations"
  value = azurerm_network_interface.nic.*.ip_configuration
}

output "nic_ip_private_ip" {
  description = "The private IP assigned to the NIC"
  value = azurerm_network_interface.nic.*.private_ip_address
}