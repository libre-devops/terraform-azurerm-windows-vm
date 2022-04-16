output "vm_ids" {
  description = "Virtual machine ids created."
  value       = azurerm_virtual_machine.windows_vm.*.id
}

output "vm_name" {
  value = azurerm_virtual_machine.windows_vm.name
}

output "vm_zones" {
  description = "map with key `Virtual Machine Id`, value `list of the Availability Zone` which the Virtual Machine should be allocated in."
  value       = zipmap(azurerm_virtual_machine.windows_vm.*.id, azurerm_virtual_machine.windows_vm.*.zones)
}

output "vm_identity" {
  description = "map with key `Virtual Machine Id`, value `list of identity` created for the Virtual Machine."
  value       = zipmap(azurerm_virtual_machine.windows_vm.*.id, azurerm_virtual_machine.windows_vm.*.identity)
}