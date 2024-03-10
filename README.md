```hcl
resource "azurerm_public_ip" "pip" {
  for_each = { for vm in var.windows_vms : vm.name => vm if vm.public_ip_sku != null }

  name                = each.value.pip_name != null ? each.value.pip_name : "pip-${each.value.name}"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = each.value.allocation_method
  domain_name_label   = try(each.value.pip_custom_dns_label, each.value.computer_name, null)
  sku                 = each.value.public_ip_sku
  tags                = var.tags

  lifecycle {
    ignore_changes = [domain_name_label]
  }
}

resource "azurerm_network_interface" "nic" {
  for_each = { for vm in var.windows_vms : vm.name => vm }

  name                          = each.value.nic_name != null ? each.value.nic_name : "nic-${each.value.name}"
  location                      = var.location
  resource_group_name           = var.rg_name
  enable_accelerated_networking = each.value.enable_accelerated_networking

  ip_configuration {
    name                          = each.value.nic_ipconfig_name != null ? each.value.nic_ipconfig_name : "nic-ipcon-${each.value.name}"
    primary                       = true
    private_ip_address_allocation = each.value.static_private_ip == null ? "Dynamic" : "Static"
    private_ip_address            = each.value.static_private_ip
    public_ip_address_id          = lookup(each.value, "public_ip_sku", null) == null ? null : azurerm_public_ip.pip[each.key].id
    subnet_id                     = each.value.subnet_id
  }
  tags = var.tags

  timeouts {
    create = "5m"
    delete = "10m"
  }
}

resource "azurerm_application_security_group" "asg" {
  for_each = { for vm in var.windows_vms : vm.name => vm if vm.create_asg == true }

  name                = each.value.asg_name != null ? each.value.asg_name : "asg-${each.value.name}"
  location            = var.location
  resource_group_name = var.rg_name
  tags                = var.tags
}

resource "azurerm_network_interface_application_security_group_association" "asg_association" {
  for_each = { for vm in var.windows_vms : vm.name => vm }

  network_interface_id          = azurerm_network_interface.nic[each.key].id
  application_security_group_id = each.value.asg_id != null ? each.value.asg_id : azurerm_application_security_group.asg[each.key].id
}


resource "random_integer" "zone" {
  for_each = { for vm in var.windows_vms : vm.name => vm if vm.availability_zone == "random" }
  min      = 1
  max      = 3
}

locals {
  sanitized_names = { for vm in var.windows_vms : vm.name => upper(replace(replace(replace(vm.name, " ", ""), "-", ""), "_", "")) }
  netbios_names   = { for key, value in local.sanitized_names : key => substr(value, 0, min(length(value), 15)) }
  random_zones    = { for idx, vm in var.windows_vms : vm.name => vm.availability_zone == "random" ? tostring(idx + 1) : vm.availability_zone }
}

resource "azurerm_windows_virtual_machine" "this" {
  for_each = { for vm in var.windows_vms : vm.name => vm }

  // Forces acceptance of marketplace terms before creating a VM
  depends_on = [
    azurerm_marketplace_agreement.plan_acceptance_simple,
    azurerm_marketplace_agreement.plan_acceptance_custom
  ]

  name                         = each.value.name
  resource_group_name          = var.rg_name
  location                     = var.location
  network_interface_ids        = [azurerm_network_interface.nic[each.key].id]
  license_type                 = each.value.license_type
  patch_mode                   = each.value.patch_mode
  enable_automatic_updates     = each.value.enable_automatic_updates
  computer_name                = each.value.computer_name != null ? each.value.computer_name : local.netbios_names[each.key]
  admin_username               = each.value.admin_username
  admin_password               = each.value.admin_password
  size                         = each.value.vm_size
  source_image_id              = try(each.value.use_custom_image, null) == true ? each.value.custom_source_image_id : null
  zone                         = local.random_zones[each.key]
  availability_set_id          = each.value.availability_set_id
  virtual_machine_scale_set_id = each.value.virtual_machine_scale_set_id
  timezone                     = each.value.timezone
  user_data                    = each.value.user_data
  custom_data                  = each.value.custom_data
  tags                         = var.tags

  encryption_at_host_enabled = each.value.enable_encryption_at_host
  allow_extension_operations = each.value.allow_extension_operations
  provision_vm_agent         = each.value.provision_vm_agent

  dynamic "additional_capabilities" {
    for_each = each.value.ultra_ssd_enabled ? [1] : []
    content {
      ultra_ssd_enabled = each.value.ultra_ssd_enabled
    }
  }

  # Use simple image
  dynamic "source_image_reference" {
    for_each = try(each.value.use_simple_image, null) == true && try(each.value.use_simple_image_with_plan, null) == false && try(each.value.use_custom_image, null) == false ? [1] : []
    content {
      publisher = coalesce(each.value.vm_os_publisher, module.os_calculator[each.value.name].calculated_value_os_publisher)
      offer     = coalesce(each.value.vm_os_offer, module.os_calculator[each.value.name].calculated_value_os_offer)
      sku       = coalesce(each.value.vm_os_sku, module.os_calculator[each.value.name].calculated_value_os_sku)
      version   = coalesce(each.value.vm_os_version, "latest")
    }
  }


  # Use custom image reference
  dynamic "source_image_reference" {
    for_each = try(each.value.use_simple_image, null) == false && try(each.value.use_simple_image_with_plan, null) == false && try(length(each.value.source_image_reference), 0) > 0 && try(length(each.value.plan), 0) == 0 && try(each.value.use_custom_image, null) == false ? [1] : []

    content {
      publisher = lookup(each.value.source_image_reference, "publisher", null)
      offer     = lookup(each.value.source_image_reference, "offer", null)
      sku       = lookup(each.value.source_image_reference, "sku", null)
      version   = lookup(each.value.source_image_reference, "version", null)
    }
  }

  dynamic "source_image_reference" {
    for_each = try(each.value.use_simple_image, null) == true && try(each.value.use_simple_image_with_plan, null) == true && try(each.value.use_custom_image, null) == false ? [1] : []

    content {
      publisher = coalesce(each.value.vm_os_publisher, module.os_calculator_with_plan[each.value.name].calculated_value_os_publisher)
      offer     = coalesce(each.value.vm_os_offer, module.os_calculator_with_plan[each.value.name].calculated_value_os_offer)
      sku       = coalesce(each.value.vm_os_sku, module.os_calculator_with_plan[each.value.name].calculated_value_os_sku)
      version   = coalesce(each.value.vm_os_version, "latest")
    }
  }


  dynamic "plan" {
    for_each = try(each.value.use_simple_image, null) == false && try(each.value.use_simple_image_with_plan, null) == false && try(length(each.value.plan), 0) > 0 && try(each.value.use_custom_image, null) == false ? [1] : []

    content {
      name      = coalesce(each.value.vm_os_sku, module.os_calculator_with_plan[each.value.name].calculated_value_os_sku)
      product   = coalesce(each.value.vm_os_offer, module.os_calculator_with_plan[each.value.name].calculated_value_os_offer)
      publisher = coalesce(each.value.vm_os_publisher, module.os_calculator_with_plan[each.value.name].calculated_value_os_publisher)
    }
  }


  dynamic "plan" {
    for_each = try(each.value.use_simple_image, null) == false && try(each.value.use_simple_image_with_plan, null) == false && try(length(each.value.plan), 0) > 0 && try(each.value.use_custom_image, null) == false ? [1] : []

    content {
      name      = lookup(each.value.plan, "name", null)
      product   = lookup(each.value.plan, "product", null)
      publisher = lookup(each.value.plan, "publisher", null)
    }
  }


  dynamic "identity" {
    for_each = each.value.identity_type == "SystemAssigned" ? [each.value.identity_type] : []
    content {
      type = each.value.identity_type
    }
  }

  dynamic "identity" {
    for_each = each.value.identity_type == "SystemAssigned, UserAssigned" ? [each.value.identity_type] : []
    content {
      type         = each.value.identity_type
      identity_ids = try(each.value.identity_ids, [])
    }
  }

  dynamic "identity" {
    for_each = each.value.identity_type == "UserAssigned" ? [each.value.identity_type] : []
    content {
      type         = each.value.identity_type
      identity_ids = length(try(each.value.identity_ids, [])) > 0 ? each.value.identity_ids : []
    }
  }


  priority        = try(each.value.spot_instance, false) ? "Spot" : "Regular"
  max_bid_price   = try(each.value.spot_instance, false) ? each.value.spot_instance_max_bid_price : null
  eviction_policy = try(each.value.spot_instance, false) ? each.value.spot_instance_eviction_policy : null

  os_disk {
    name                             = each.value.os_disk.name != null ? each.value.os_disk.name : "osdisk-${each.value.name}"
    caching                          = each.value.os_disk.caching
    storage_account_type             = each.value.os_disk.os_disk_type
    disk_size_gb                     = each.value.os_disk.disk_size_gb
    disk_encryption_set_id           = each.value.os_disk.disk_encryption_set_id
    secure_vm_disk_encryption_set_id = each.value.os_disk.secure_vm_disk_encryption_set_id
    security_encryption_type         = each.value.os_disk.security_encryption_type
    write_accelerator_enabled        = each.value.os_disk.write_accelerator_enabled

    dynamic "diff_disk_settings" {
      for_each = each.value.os_disk.diff_disk_settings != null ? [each.value.os_disk.diff_disk_settings] : []
      content {
        option = diff_disk_settings.value.option
      }
    }
  }

  dynamic "boot_diagnostics" {
    for_each = each.value.boot_diagnostics_storage_account_uri != null ? [each.value.boot_diagnostics_storage_account_uri] : [null]
    content {
      storage_account_uri = boot_diagnostics.value
    }
  }


  dynamic "additional_unattend_content" {
    for_each = each.value.additional_unattend_content != null ? each.value.additional_unattend_content : []
    content {
      content = additional_unattend_content.value.content
      setting = additional_unattend_content.value.setting
    }
  }

  dynamic "secret" {
    for_each = each.value.secrets != null ? each.value.secrets : []
    content {
      key_vault_id = secret.value.key_vault_id

      dynamic "certificate" {
        for_each = secret.value.certificates
        content {
          store = certificate.value.store
          url   = certificate.value.url
        }
      }
    }
  }

  dynamic "termination_notification" {
    for_each = each.value.termination_notification != null ? [each.value.termination_notification] : []
    content {
      enabled = termination_notification.value.enabled
      timeout = lookup(termination_notification.value, "timeout", "PT5M")
    }
  }

  dynamic "winrm_listener" {
    for_each = each.value.winrm_listener != null ? each.value.winrm_listener : []
    content {
      protocol        = winrm_listener.value.protocol
      certificate_url = winrm_listener.value.certificate_url
    }
  }
}

module "os_calculator" {
  source       = "libre-devops/windows-os-sku-calculator/azurerm"
  for_each     = { for vm in var.windows_vms : vm.name => vm if try(vm.use_simple_image, null) == true }
  vm_os_simple = each.value.vm_os_simple
}

module "os_calculator_with_plan" {
  source       = "libre-devops/windows-os-sku-with-plan-calculator/azurerm"
  for_each     = { for vm in var.windows_vms : vm.name => vm if try(vm.use_simple_image_with_plan, null) == true }
  vm_os_simple = each.value.vm_os_simple
}

resource "azurerm_marketplace_agreement" "plan_acceptance_simple" {
  for_each = { for vm in var.windows_vms : vm.name => vm if try(vm.use_simple_image_with_plan, null) == true && try(vm.accept_plan, null) == true && try(vm.use_custom_image, null) == false }

  publisher = coalesce(each.value.vm_os_publisher, module.os_calculator_with_plan[each.key].calculated_value_os_publisher)
  offer     = coalesce(each.value.vm_os_offer, module.os_calculator_with_plan[each.key].calculated_value_os_offer)
  plan      = coalesce(each.value.vm_os_sku, module.os_calculator_with_plan[each.key].calculated_value_os_sku)
}

resource "azurerm_marketplace_agreement" "plan_acceptance_custom" {
  for_each = { for vm in var.windows_vms : vm.name => vm if try(vm.use_custom_image_with_plan, null) == true && try(vm.accept_plan, null) == true && try(vm.use_custom_image, null) == true }

  publisher = lookup(each.value.plan, "publisher", null)
  offer     = lookup(each.value.plan, "product", null)
  plan      = lookup(each.value.plan, "name", null)
}

resource "azurerm_virtual_machine_extension" "windows_vm_inline_command" {
  for_each   = { for vm in var.windows_vms : vm.name => vm if try(vm.run_vm_command.inline, null) != null }
  depends_on = [azurerm_windows_virtual_machine.this]

  name                       = each.value.run_vm_command.extension_name != null ? each.value.run_vm_command.extension_name : "run-command-${each.value.name}"
  publisher                  = "Microsoft.CPlat.Core"
  type                       = "RunCommandWindows"
  type_handler_version       = "1.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    script = tolist([each.value.run_vm_command.inline])
  })

  tags               = var.tags
  virtual_machine_id = azurerm_windows_virtual_machine.this[each.key].id

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_virtual_machine_extension" "windows_vm_file_command" {
  for_each   = { for vm in var.windows_vms : vm.name => vm if try(vm.run_vm_command.script_file, null) != null }
  depends_on = [azurerm_windows_virtual_machine.this]

  name                       = each.value.run_vm_command.extension_name != null ? each.value.run_vm_command.extension_name : "run-command-file-${each.value.name}"
  publisher                  = "Microsoft.CPlat.Core"
  type                       = "RunCommandWindows"
  type_handler_version       = "1.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    script = compact(tolist([each.value.run_vm_command.script_file]))
  })

  tags               = var.tags
  virtual_machine_id = azurerm_windows_virtual_machine.this[each.key].id

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_virtual_machine_extension" "windows_vm_uri_command" {
  for_each   = { for vm in var.windows_vms : vm.name => vm if try(vm.run_vm_command.script_uri, null) != null }
  depends_on = [azurerm_windows_virtual_machine.this]

  name                       = each.value.run_vm_command.extension_name != null ? each.value.run_vm_command.extension_name : "run-command-uri-${each.value.name}"
  publisher                  = "Microsoft.CPlat.Core"
  type                       = "RunCommandWindows"
  type_handler_version       = "1.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    script = compact(tolist([each.value.run_vm_command.script_uri]))
  })

  tags               = var.tags
  virtual_machine_id = azurerm_windows_virtual_machine.this[each.key].id

  lifecycle {
    ignore_changes = all
  }
}
```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_os_calculator"></a> [os\_calculator](#module\_os\_calculator) | libre-devops/windows-os-sku-calculator/azurerm | n/a |
| <a name="module_os_calculator_with_plan"></a> [os\_calculator\_with\_plan](#module\_os\_calculator\_with\_plan) | libre-devops/windows-os-sku-with-plan-calculator/azurerm | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_application_security_group.asg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_security_group) | resource |
| [azurerm_marketplace_agreement.plan_acceptance_custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/marketplace_agreement) | resource |
| [azurerm_marketplace_agreement.plan_acceptance_simple](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/marketplace_agreement) | resource |
| [azurerm_network_interface.nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_network_interface_application_security_group_association.asg_association](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_application_security_group_association) | resource |
| [azurerm_public_ip.pip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_virtual_machine_extension.windows_vm_file_command](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension) | resource |
| [azurerm_virtual_machine_extension.windows_vm_inline_command](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension) | resource |
| [azurerm_virtual_machine_extension.windows_vm_uri_command](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension) | resource |
| [azurerm_windows_virtual_machine.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) | resource |
| [random_integer.zone](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | The region to place the resources | `string` | n/a | yes |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | The resource group name to place the scale sets in | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to be applied to the resource | `map(string)` | n/a | yes |
| <a name="input_windows_vms"></a> [windows\_vms](#input\_windows\_vms) | List of VM configurations. | <pre>list(object({<br>    accept_plan = optional(bool, false)<br>    additional_unattend_content = optional(list(object({<br>      content = string<br>      setting = string<br>    })))<br>    admin_password                       = string<br>    admin_username                       = string<br>    allocation_method                    = optional(string, "Static")<br>    allow_extension_operations           = optional(bool, true)<br>    asg_id                               = optional(string, null)<br>    asg_name                             = optional(string, null)<br>    availability_set_id                  = optional(string)<br>    availability_zone                    = optional(string, "random")<br>    boot_diagnostics_storage_account_uri = optional(string, null)<br>    secrets = optional(list(object({<br>      key_vault_id = string<br>      certificates = list(object({<br>        store = string<br>        url   = string<br>      }))<br>    })))<br>    computer_name                 = optional(string)<br>    create_asg                    = optional(bool, true)<br>    custom_data                   = optional(string)<br>    custom_source_image_id        = optional(string, null)<br>    enable_accelerated_networking = optional(bool, false)<br>    enable_automatic_updates      = optional(bool, true)<br>    enable_encryption_at_host     = optional(bool, false)<br>    identity_ids                  = optional(list(string))<br>    identity_type                 = optional(string)<br>    license_type                  = optional(string)<br>    name                          = string<br>    nic_ipconfig_name             = optional(string)<br>    nic_name                      = optional(string, null)<br>    os_disk = object({<br>      caching      = optional(string, "ReadWrite")<br>      os_disk_type = optional(string, "StandardSSD_LRS")<br>      diff_disk_settings = optional(object({<br>        option = string<br>      }))<br>      disk_encryption_set_id           = optional(string, null)<br>      disk_size_gb                     = optional(number, "127")<br>      name                             = optional(string, null)<br>      secure_vm_disk_encryption_set_id = optional(string, null)<br>      security_encryption_type         = optional(string, null)<br>      write_accelerator_enabled        = optional(bool, false)<br>    })<br>    patch_mode                    = optional(string, "AutomaticByOS")<br>    pip_custom_dns_label          = optional(string)<br>    pip_name                      = optional(string)<br>    provision_vm_agent            = optional(bool, true)<br>    public_ip_sku                 = optional(string, null)<br>    source_image_reference        = optional(map(string))<br>    spot_instance                 = optional(bool, false)<br>    spot_instance_eviction_policy = optional(string)<br>    spot_instance_max_bid_price   = optional(string)<br>    static_private_ip             = optional(string)<br>    subnet_id                     = string<br>    termination_notification = optional(object({<br>      enabled = bool<br>      timeout = optional(string)<br>    }))<br>    run_vm_command = optional(object({<br>      extension_name = optional(string)<br>      inline         = optional(string)<br>      script_file    = optional(string)<br>      script_uri     = optional(string)<br>    }))<br>    timezone                     = optional(string)<br>    ultra_ssd_enabled            = optional(bool, false)<br>    use_custom_image             = optional(bool, false)<br>    use_custom_image_with_plan   = optional(bool, false)<br>    use_simple_image             = optional(bool, true)<br>    use_simple_image_with_plan   = optional(bool, false)<br>    user_data                    = optional(string, null)<br>    virtual_machine_scale_set_id = optional(string, null)<br>    vm_os_id                     = optional(string, "")<br>    vm_os_offer                  = optional(string)<br>    vm_os_publisher              = optional(string)<br>    vm_os_simple                 = optional(string)<br>    vm_os_sku                    = optional(string)<br>    vm_os_version                = optional(string)<br>    vm_size                      = string<br>    vtpm_enabled                 = optional(bool, false)<br>    winrm_listener = optional(list(object({<br>      protocol        = string<br>      certificate_url = optional(string)<br>    })))<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_asg_ids"></a> [asg\_ids](#output\_asg\_ids) | List of ASG IDs. |
| <a name="output_asg_names"></a> [asg\_names](#output\_asg\_names) | List of ASG Names. |
| <a name="output_managed_identities"></a> [managed\_identities](#output\_managed\_identities) | Managed identities of the VMs |
| <a name="output_nic_private_ipv4_addresses"></a> [nic\_private\_ipv4\_addresses](#output\_nic\_private\_ipv4\_addresses) | List of NIC Private IPv4 Addresses. |
| <a name="output_public_ip_ids"></a> [public\_ip\_ids](#output\_public\_ip\_ids) | List of Public IP IDs. |
| <a name="output_public_ip_names"></a> [public\_ip\_names](#output\_public\_ip\_names) | List of Public IP Names. |
| <a name="output_public_ip_values"></a> [public\_ip\_values](#output\_public\_ip\_values) | List of Public IP Addresses. |
| <a name="output_vm_details_map"></a> [vm\_details\_map](#output\_vm\_details\_map) | A map where the key is the VM name and the value is another map containing the VM ID and private IP address. |
| <a name="output_vm_ids"></a> [vm\_ids](#output\_vm\_ids) | List of VM IDs. |
| <a name="output_vm_names"></a> [vm\_names](#output\_vm\_names) | List of VM Names. |
