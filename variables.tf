variable "location" {
  type        = string
  description = "The region to place the resources"
}

variable "rg_name" {
  type        = string
  description = "The resource group name to place the scale sets in"
}

variable "tags" {
  type        = map(string)
  description = "Tags to be applied to the resource"
}

variable "windows_vms" {
  description = "List of VM configurations."
  type = list(object({
    accept_plan = optional(bool, false)
    additional_unattend_content = optional(list(object({
      content = string
      setting = string
    })))
    admin_password                       = string
    admin_username                       = string
    allocation_method                    = optional(string, "Static")
    allow_extension_operations           = optional(bool, true)
    asg_id                               = optional(string, null)
    asg_name                             = optional(string, null)
    availability_set_id                  = optional(string)
    availability_zone                    = optional(string, "random")
    boot_diagnostics_storage_account_uri = optional(string, null)
    secrets = optional(list(object({
      key_vault_id = string
      certificates = list(object({
        store = string
        url   = string
      }))
    })))
    computer_name                 = optional(string)
    create_asg                    = optional(bool, true)
    custom_data                   = optional(string)
    custom_source_image_id        = optional(string, null)
    enable_accelerated_networking = optional(bool, false)
    enable_automatic_updates      = optional(bool, true)
    enable_encryption_at_host     = optional(bool, false)
    identity_ids                  = optional(list(string))
    identity_type                 = optional(string)
    license_type                  = optional(string)
    name                          = string
    nic_ipconfig_name             = optional(string)
    nic_name                      = optional(string, null)
    os_disk = object({
      caching      = optional(string, "ReadWrite")
      os_disk_type = optional(string, "StandardSSD_LRS")
      diff_disk_settings = optional(object({
        option = string
      }))
      disk_encryption_set_id           = optional(string, null)
      disk_size_gb                     = optional(number, "127")
      name                             = optional(string, null)
      secure_vm_disk_encryption_set_id = optional(string, null)
      security_encryption_type         = optional(string, null)
      write_accelerator_enabled        = optional(bool, false)
    })
    patch_mode                    = optional(string, "AutomaticByOS")
    pip_custom_dns_label          = optional(string)
    pip_name                      = optional(string)
    provision_vm_agent            = optional(bool, true)
    public_ip_sku                 = optional(string, null)
    source_image_reference        = optional(map(string))
    spot_instance                 = optional(bool, false)
    spot_instance_eviction_policy = optional(string)
    spot_instance_max_bid_price   = optional(string)
    static_private_ip             = optional(string)
    subnet_id                     = string
    termination_notification = optional(object({
      enabled = bool
      timeout = optional(string)
    }))
    run_vm_command = optional(object({
      extension_name  = optional(string)
      inline          = optional(string)
      script_file     = optional(string)
      script_uri      = optional(string)
      run_as_user     = optional(string)
      run_as_password = optional(string)
    }))
    timezone                     = optional(string)
    ultra_ssd_enabled            = optional(bool, false)
    use_custom_image             = optional(bool, false)
    use_custom_image_with_plan   = optional(bool, false)
    use_simple_image             = optional(bool, true)
    use_simple_image_with_plan   = optional(bool, false)
    user_data                    = optional(string, null)
    virtual_machine_scale_set_id = optional(string, null)
    vm_os_id                     = optional(string, "")
    vm_os_offer                  = optional(string)
    vm_os_publisher              = optional(string)
    vm_os_simple                 = optional(string)
    vm_os_sku                    = optional(string)
    vm_os_version                = optional(string)
    vm_size                      = string
    vtpm_enabled                 = optional(bool, false)
    winrm_listener = optional(list(object({
      protocol        = string
      certificate_url = optional(string)
    })))
  }))
  default = []
}
