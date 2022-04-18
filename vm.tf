resource "azurerm_network_interface" "nic" {
  count = var.vm_amount

  name                = "nic-${var.vm_hostname}${format("%02d", count.index + 1)}"
  resource_group_name = var.rg_name
  location            = var.location

  enable_accelerated_networking = var.enable_accelerated_networking

  ip_configuration {
    name                          = "nic-ipconfig-${var.vm_hostname}${format("%02d", count.index + 1)}"
    primary                       = true
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.subnet_id
  }
  tags = var.tags

  timeouts {
    create = "5m"
    delete = "10m"
  }
}

resource "azurerm_windows_virtual_machine" "windows_vm" {

  count                    = var.vm_amount
  name                     = "${var.vm_hostname}${format("%02d", count.index + 1)}"
  resource_group_name      = var.rg_name
  location                 = var.location
  network_interface_ids    = [azurerm_network_interface.nic[count.index].id]
  license_type             = var.license_type
  patch_mode               = var.patch_mode
  enable_automatic_updates = var.enable_automatic_updates
  computer_name            = var.vm_hostname
  admin_username           = var.admin_username
  admin_password           = var.admin_password
  size                     = var.vm_size
  zone                     = var.availability_zone == "alternate" ? (count.index % 3) + 1 : null // Alternates zones for VMs in count, 1, 2 then 3. Use availability set if you want HA.

  provision_vm_agent         = true
  timezone                   = var.timezone

  #checkov:skip=CKV_AZURE_151:Ensure Virtual Machine extensions are not installed
  encryption_at_host_enabled = false

  #checkov:skip=CKV_AZURE_50:Ensure Virtual Machine extensions are not installed
  allow_extension_operations = true

  source_image_reference {
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

  os_disk {
    name                 = "osdisk-${var.vm_hostname}${format("%02d", count.index + 1)}"
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type
    disk_size_gb         = var.vm_os_disk_size_gb
  }

  tags = var.tags
}

module "os_calculator" {
  source = "registry.terraform.io/libre-devops/win-os-sku-calculator/azurerm"

  vm_os_simple = var.vm_os_simple
}