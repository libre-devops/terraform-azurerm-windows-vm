resource "azurerm_virtual_machine" "windows_vm" {
  count                         = var.vm_amount
  name                          = "${var.vm_hostname}-vmWindows-${count.index}"
  resource_group_name           = var.rg_name
  location                      = var.location
  vm_size                       = var.vm_size
  network_interface_ids         = [var.nic_ids]
  delete_os_disk_on_termination = var.delete_os_disk_on_termination
  license_type                  = var.license_type

  dynamic "identity" {
    for_each = length(var.identity_ids) == 0 && var.identity_type == "SystemAssigned" ? [var.identity_type] : []
    content {
      type = var.identity_type
    }
  }

  dynamic "identity" {
    for_each = length(var.identity_ids) > 0 || var.identity_type == "UserAssigned" ? [var.identity_type] : []
    content {
      type         = var.identity_type
      identity_ids = length(var.identity_ids) > 0 ? var.identity_ids : []
    }
  }

  storage_os_disk {
    name              = "${var.vm_hostname}-osdisk-${count.index}"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = var.storage_account_type
  }

  os_profile {
    computer_name  = "${var.vm_hostname}-${count.index}"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  tags = var.tags

  os_profile_windows_config {
    provision_vm_agent = true
  }

  dynamic "os_profile_secrets" {
    for_each = var.os_profile_secrets
    content {
      source_vault_id = os_profile_secrets.value["source_vault_id"]

      vault_certificates {
        certificate_url   = os_profile_secrets.value["certificate_url"]
        certificate_store = os_profile_secrets.value["certificate_store"]
      }
    }
  }
}
