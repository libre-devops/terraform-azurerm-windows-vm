resource "azurerm_virtual_machine" "windows_vm" {
  count                         = var.vm_amount
  name                          = var.vm_hostname
  resource_group_name           = var.rg_name
  location                      = var.location
  vm_size                       = var.vm_size
  network_interface_ids         = [var.nic_ids]
  delete_os_disk_on_termination = var.delete_os_disk_on_termination
  license_type                  = var.license_type
  patch_mode                    = var.patch_mode
  enable_automatic_updates      = var.enable_automatic_updates

  zone = var.availability_zone == "1" || "2" || "3" || "alternate" ? (count.index % 2) + 1 : null

  timezone = var.timezone

  storage_image_reference {
    id        = var.vm_os_id
    publisher = var.vm_os_id == "" ? coalesce(var.vm_os_publisher, module.os_calculator.calculated_value_os_publisher) : ""
    offer     = var.vm_os_id == "" ? coalesce(var.vm_os_offer, module.os_calculator.calculated_value_os_offer) : ""
    sku       = var.vm_os_id == "" ? coalesce(var.vm_os_sku, module.os_calculator.calculated_value_os_sku) : ""
    version   = var.vm_os_id == "" ? var.vm_os_version : ""
  }

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
    name              = "${var.vm_hostname}-osdisk"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = var.storage_account_type
    disk_size_gb      = var.vm_os_disk_size_gb
  }

  os_profile {
    computer_name  = var.vm_hostname
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

module "os_calculator" {
  source = "registry.terraform.io/libre-devops/win-os-sku-calculator/azurerm"

  vm_os_simple = var.vm_os_simple
}