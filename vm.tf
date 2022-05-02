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
  timezone                 = var.timezone

  #checkov:skip=CKV_AZURE_151:Ensure Encryption at host is enabled
  encryption_at_host_enabled = var.enable_encryption_at_host

  #checkov:skip=CKV_AZURE_50:Ensure Virtual Machine extensions are not installed
  allow_extension_operations = var.allow_extension_operations
  provision_vm_agent         = var.provision_vm_agent

  dynamic "source_image_reference" {
    for_each = try(var.use_simple_image, null) == true && try(var.use_simple_image_with_plan, null) == false ? [1] : []
    content {
      publisher = var.vm_os_id == "" ? coalesce(var.vm_os_publisher, module.os_calculator[0].calculated_value_os_publisher) : ""
      offer     = var.vm_os_id == "" ? coalesce(var.vm_os_offer, module.os_calculator[0].calculated_value_os_offer) : ""
      sku       = var.vm_os_id == "" ? coalesce(var.vm_os_sku, module.os_calculator[0].calculated_value_os_sku) : ""
      version   = var.vm_os_id == "" ? var.vm_os_version : ""
    }
  }

  dynamic "source_image_reference" {
    for_each = try(var.use_simple_image, null) == false && try(var.use_simple_image_with_plan, null) == false ? [1] : []
    content {
      publisher = lookup(var.source_image_reference, "publisher", null)
      offer     = lookup(var.source_image_reference, "offer", null)
      sku       = lookup(var.source_image_reference, "sku", null)
      version   = lookup(var.source_image_reference, "version", null)
    }
  }

  // To be used when a VM with a plan is used
  dynamic "source_image_reference" {
    for_each = try(var.use_simple_image, null) == true && try(var.use_simple_image_with_plan, null) == true ? [1] : []
    content {
      publisher = var.vm_os_id == "" ? coalesce(var.vm_os_publisher, module.os_calculator_with_plan[0].calculated_value_os_publisher) : ""
      offer     = var.vm_os_id == "" ? coalesce(var.vm_os_offer, module.os_calculator_with_plan[0].calculated_value_os_offer) : ""
      sku       = var.vm_os_id == "" ? coalesce(var.vm_os_sku, module.os_calculator_with_plan[0].calculated_value_os_sku) : ""
      version   = var.vm_os_id == "" ? var.vm_os_version : ""
    }
  }

  dynamic "plan" {
    for_each = try(var.use_simple_image, null) == true && try(var.use_simple_image_with_plan, null) == true ? [1] : []
    content {
      name      = var.vm_os_id == "" ? coalesce(var.vm_os_sku, module.os_calculator_with_plan[0].calculated_value_os_sku) : ""
      product   = var.vm_os_id == "" ? coalesce(var.vm_os_offer, module.os_calculator_with_plan[0].calculated_value_os_offer) : ""
      publisher = var.vm_os_id == "" ? coalesce(var.vm_os_publisher, module.os_calculator_with_plan[0].calculated_value_os_publisher) : ""
    }
  }

  // To be used when a custom image is wanted without the simple OS module, which has a plan attached
  dynamic "source_image_reference" {
    for_each = try(var.use_simple_image, null) == false && try(var.use_simple_image_with_plan, null) == false ? [1] : []
    content {
      publisher = lookup(var.source_image_reference, "publisher", null)
      offer     = lookup(var.source_image_reference, "offer", null)
      sku       = lookup(var.source_image_reference, "sku", null)
      version   = lookup(var.source_image_reference, "version", null)
    }
  }

  dynamic "plan" {
    for_each = try(var.use_simple_image, null) == false && try(var.use_simple_image_with_plan, null) == false ? [1] : []
    content {
      name      = toset(lookup(var.source_image_reference.plan, "name", null))
      product   = toset(lookup(var.source_image_reference.plan, "product", null))
      publisher = toset(lookup(var.source_image_reference.plan, "publisher", null))
    }
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

  priority        = var.spot_instance ? "Spot" : "Regular"
  max_bid_price   = var.spot_instance ? var.spot_instance_max_bid_price : null
  eviction_policy = var.spot_instance ? var.spot_instance_eviction_policy : null

  os_disk {
    name                 = "osdisk-${var.vm_hostname}${format("%02d", count.index + 1)}"
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type
    disk_size_gb         = var.vm_os_disk_size_gb
  }

  boot_diagnostics {
    storage_account_uri = null // Use managed storage account
  }

  tags = var.tags
}

module "os_calculator" {
  source = "registry.terraform.io/libre-devops/windows-os-sku-calculator/azurerm"

  count = try(var.use_simple_image, null) == true ? 1 : 0

  vm_os_simple = var.vm_os_simple
}

module "os_calculator_with_plan" {
  source = "registry.terraform.io/libre-devops/windows-os-sku-with-plan-calculator/azurerm"

  count = try(var.use_simple_image_with_plan, null) == true ? 1 : 0

  vm_os_simple = var.vm_os_simple
}