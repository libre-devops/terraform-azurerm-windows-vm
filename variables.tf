variable "resource_group_id" {
  description = "Resource id of the resource group to create the VMs in. The name is parsed from it (pass the rg module's ids output)."
  type        = string

  validation {
    condition     = try(provider::azurerm::parse_resource_id(var.resource_group_id).resource_type, "") == "resourceGroups"
    error_message = "resource_group_id must be a resource group id of the form /subscriptions/<sub>/resourceGroups/<name>."
  }
}

variable "location" {
  description = "Azure region for the VMs."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource this module creates (merged with any per-VM tags)."
  type        = map(string)
  default     = {}
}

variable "vm_insights" {
  description = <<DESC
Opt-in VM Insights for every VM in this call: the module installs the Azure Monitor agent (each VM's
system-assigned identity is what the agent authenticates with, which the module enables by default),
creates the VM Insights data collection rule pointed at log_analytics_workspace_id (or associates an
existing one passed as data_collection_rule_id), and associates every VM with it. null (the default)
creates nothing.
DESC

  type = object({
    log_analytics_workspace_id = optional(string)
    data_collection_rule_id    = optional(string)
  })
  default = null

  validation {
    condition     = var.vm_insights == null || length([for v in [try(var.vm_insights.log_analytics_workspace_id, null), try(var.vm_insights.data_collection_rule_id, null)] : v if v != null]) == 1
    error_message = "vm_insights must set exactly one of log_analytics_workspace_id (the module creates the VM Insights DCR) or data_collection_rule_id (an existing DCR)."
  }
}

variable "windows_virtual_machines" {
  description = <<DESC
The Windows VMs to create, keyed by VM name. Each VM gets its own NIC (subnet_id is where it lives;
public_ip_address_id is ONLY an input, public IPs live in the public-ip module).

SECURE DEFAULTS: Trusted Launch (secure_boot_enabled and vtpm_enabled true; the image catalog
entries are all Gen2 and Trusted Launch capable), a system-assigned managed identity, managed boot
diagnostics, automatic OS updates, and platform patch assessment. admin_password is required
(Windows has no key-only mode); generate it with random_password and copy it into a key vault with
the keyvault-secret module's write-only handling.

IMAGE SELECTION, exactly one of:
- source_image_simple: a friendly catalog key (WindowsServer2022, WindowsServer2022AzureEdition,
  WindowsServer2025, WindowsServer2025AzureEdition; see the image_catalog_keys output), verified
  Gen2/Trusted Launch marketplace references. The AzureEdition entries are the hotpatching-capable
  ones.
- source_image_reference: { publisher, offer, sku, version (default latest) } for anything else.
- source_image_id: a custom or gallery image id.
Marketplace plan images: set plan { name, product, publisher } and optionally
accept_marketplace_agreement = true to create the azurerm_marketplace_agreement.

NETWORKING per VM: subnet_id (required), private_ip_address (static when set), public_ip_address_id,
accelerated_networking_enabled (default false; not every size supports it), ip_forwarding_enabled,
dns_servers, application_security_group_ids (associations only; ASGs live with the network modules),
nic_name / ipconfig_name overrides.

DISKS: os_disk (caching ReadWrite, StandardSSD_LRS by default, plus size, encryption set, security
encryption, write accelerator, diff_disk_settings) and data_disks keyed by name (size_gb required;
lun auto-assigned by declaration order unless set; storage_account_type, caching, create_option,
encryption set, zone follows the VM).

EVERYTHING ELSE: zone, availability_set_id, virtual_machine_scale_set_id, proximity_placement_group_id,
capacity_reservation_group_id, dedicated_host_id / dedicated_host_group_id, platform_fault_domain,
edge_zone; spot { max_bid_price, eviction_policy }; additional_capabilities (ultra SSD, hibernation);
encryption_at_host_enabled (subscription feature-gated; see resource_provider_feature_registrations
for the often-forgotten registration); identity (SystemAssigned by default, UserAssigned, both as
"SystemAssigned, UserAssigned", or None for no identity at all); patching (patch_mode default
AutomaticByOS, patch_assessment_mode default AutomaticByPlatform, automatic_updates_enabled default
true, hotpatching_enabled for AzureEdition images with AutomaticByPlatform patching, reboot_setting,
bypass flag); timezone; license_type (None by default; "Windows_Server" claims Azure Hybrid
Benefit); user_data / custom_data; computer_name (Windows caps it at 15 characters, so it defaults
to the VM name upper-cased, separators stripped, truncated to 15);
disk_controller_type; extensions_time_budget; gallery_applications; secrets (key vault certificates
with their Windows certificate store); winrm_listeners; additional_unattend_content;
termination_notification; os_image_notification; boot_diagnostics_storage_account_uri (unset =
managed storage); run_command { script | script_uri | command_id, run_as_user, run_as_password };
monitor_agent_enabled (default true, only relevant when vm_insights is set) and per-VM tags.

PROVIDER DISCLAIMERS worth knowing: the OS disk is deleted with the VM by default (configurable via
the provider features block); all arguments including the administrator login and password are
stored in the raw state as plain text (protect the state); unmanaged disks and attaching existing
OS disks are not supported by azurerm_windows_virtual_machine; and public_ip_address outputs may be
unpopulated for Dynamic public IPs.
DESC

  type = map(object({
    size           = string
    admin_username = string
    admin_password = string

    source_image_simple = optional(string)
    source_image_reference = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = optional(string, "latest")
    }))
    source_image_id = optional(string)
    plan = optional(object({
      name      = string
      product   = string
      publisher = string
    }))
    accept_marketplace_agreement = optional(bool, false)

    subnet_id                      = string
    private_ip_address             = optional(string)
    public_ip_address_id           = optional(string)
    accelerated_networking_enabled = optional(bool, false)
    ip_forwarding_enabled          = optional(bool, false)
    dns_servers                    = optional(list(string))
    application_security_group_ids = optional(list(string), [])
    nic_name                       = optional(string)
    ipconfig_name                  = optional(string)

    os_disk = optional(object({
      name                             = optional(string)
      caching                          = optional(string, "ReadWrite")
      storage_account_type             = optional(string, "StandardSSD_LRS")
      disk_size_gb                     = optional(number)
      disk_encryption_set_id           = optional(string)
      secure_vm_disk_encryption_set_id = optional(string)
      security_encryption_type         = optional(string)
      write_accelerator_enabled        = optional(bool, false)
      diff_disk_settings = optional(object({
        option = string
      }))
    }), {})

    data_disks = optional(map(object({
      disk_size_gb           = number
      lun                    = optional(number)
      storage_account_type   = optional(string, "StandardSSD_LRS")
      caching                = optional(string, "ReadWrite")
      create_option          = optional(string, "Empty")
      source_resource_id     = optional(string)
      disk_encryption_set_id = optional(string)
    })), {})

    secure_boot_enabled        = optional(bool, true)
    vtpm_enabled               = optional(bool, true)
    encryption_at_host_enabled = optional(bool)

    identity = optional(object({
      type         = optional(string, "SystemAssigned")
      identity_ids = optional(list(string))
    }), {})

    boot_diagnostics_enabled             = optional(bool, true)
    boot_diagnostics_storage_account_uri = optional(string)

    patch_mode                                             = optional(string, "AutomaticByOS")
    automatic_updates_enabled                              = optional(bool, true)
    hotpatching_enabled                                    = optional(bool, false)
    timezone                                               = optional(string)
    patch_assessment_mode                                  = optional(string, "AutomaticByPlatform")
    bypass_platform_safety_checks_on_user_schedule_enabled = optional(bool, false)
    reboot_setting                                         = optional(string)
    provision_vm_agent                                     = optional(bool, true)
    allow_extension_operations                             = optional(bool, true)
    extensions_time_budget                                 = optional(string)

    zone                          = optional(string)
    availability_set_id           = optional(string)
    virtual_machine_scale_set_id  = optional(string)
    proximity_placement_group_id  = optional(string)
    capacity_reservation_group_id = optional(string)
    dedicated_host_id             = optional(string)
    dedicated_host_group_id       = optional(string)
    platform_fault_domain         = optional(number)
    edge_zone                     = optional(string)

    spot = optional(object({
      max_bid_price   = optional(number, -1)
      eviction_policy = optional(string, "Deallocate")
    }))

    additional_capabilities = optional(object({
      ultra_ssd_enabled   = optional(bool, false)
      hibernation_enabled = optional(bool, false)
    }))

    license_type         = optional(string)
    user_data            = optional(string)
    custom_data          = optional(string)
    computer_name        = optional(string)
    disk_controller_type = optional(string)

    gallery_applications = optional(list(object({
      version_id                                  = string
      automatic_upgrade_enabled                   = optional(bool)
      configuration_blob_uri                      = optional(string)
      order                                       = optional(number)
      tag                                         = optional(string)
      treat_failure_as_deployment_failure_enabled = optional(bool)
    })), [])

    secrets = optional(list(object({
      key_vault_id = string
      certificates = list(object({
        url   = string
        store = optional(string)
      }))
    })), [])

    winrm_listeners = optional(list(object({
      protocol        = string
      certificate_url = optional(string)
    })), [])

    additional_unattend_content = optional(list(object({
      setting = string
      content = string
    })), [])

    termination_notification = optional(object({
      enabled = bool
      timeout = optional(string)
    }))
    os_image_notification_timeout = optional(string)

    run_command = optional(object({
      name            = optional(string)
      script          = optional(string)
      script_uri      = optional(string)
      command_id      = optional(string)
      run_as_user     = optional(string)
      run_as_password = optional(string)
    }))

    monitor_agent_enabled = optional(bool, true)
    tags                  = optional(map(string))
  }))
  default = {}

  validation {
    condition = alltrue([
      for v in values(var.windows_virtual_machines) :
      length([for s in [v.source_image_simple, v.source_image_reference, v.source_image_id] : s if s != null]) == 1
    ])
    error_message = "Each VM must set exactly one of source_image_simple, source_image_reference, or source_image_id."
  }

  validation {
    condition     = alltrue([for v in values(var.windows_virtual_machines) : v.computer_name == null || length(coalesce(v.computer_name, "-")) <= 15])
    error_message = "computer_name is capped at 15 characters on Windows (leave it unset to derive one from the VM name)."
  }

  validation {
    condition     = alltrue(flatten([for v in values(var.windows_virtual_machines) : [for w in v.winrm_listeners : contains(["Http", "Https"], w.protocol)]]))
    error_message = "winrm_listeners protocol must be Http or Https."
  }

  validation {
    condition     = alltrue([for v in values(var.windows_virtual_machines) : contains(["None", "ReadOnly", "ReadWrite"], v.os_disk.caching)])
    error_message = "os_disk.caching must be None, ReadOnly, or ReadWrite."
  }

  validation {
    condition     = alltrue([for v in values(var.windows_virtual_machines) : contains(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned", "None"], v.identity.type)])
    error_message = "identity.type must be SystemAssigned, UserAssigned, \"SystemAssigned, UserAssigned\", or None."
  }



  validation {
    condition = alltrue(flatten([
      for v in values(var.windows_virtual_machines) : [
        for r in [v.run_command] : length([for s in [r.script, r.script_uri, r.command_id] : s if s != null]) == 1 if r != null
      ]
    ]))
    error_message = "run_command must set exactly one of script, script_uri, or command_id."
  }
}
