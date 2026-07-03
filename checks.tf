# check blocks run after every plan and apply and warn (without blocking) on configuration that would
# quietly weaken the module's posture.

# The module does nothing without at least one VM.
check "creates_at_least_one_vm" {
  assert {
    condition     = length(var.windows_virtual_machines) > 0
    error_message = "No VMs would be created: set windows_virtual_machines."
  }
}

# Hotpatching only works on the AzureEdition images with platform-orchestrated patching; a silent
# mismatch fails at the API, so surface it early.
check "hotpatching_prerequisites" {
  assert {
    condition = alltrue([
      for k, v in var.windows_virtual_machines : !v.hotpatching_enabled || (
        v.patch_mode == "AutomaticByPlatform" &&
        (v.source_image_simple == null || contains(local.hotpatch_capable_keys, coalesce(v.source_image_simple, "-")))
      )
    ])
    error_message = "These VMs enable hotpatching without its prerequisites (an AzureEdition image plus patch_mode = AutomaticByPlatform): ${join(", ", sort([for k, v in var.windows_virtual_machines : k if v.hotpatching_enabled && !(v.patch_mode == "AutomaticByPlatform" && (v.source_image_simple == null || contains(local.hotpatch_capable_keys, coalesce(v.source_image_simple, "-"))))]))}."
  }
}

# Turning Trusted Launch off should be equally visible.
check "trusted_launch_optouts_are_visible" {
  assert {
    condition     = alltrue([for k, v in var.windows_virtual_machines : v.secure_boot_enabled && v.vtpm_enabled])
    error_message = "These VMs disable secure boot or vTPM (Trusted Launch): ${join(", ", sort([for k, v in var.windows_virtual_machines : k if !(v.secure_boot_enabled && v.vtpm_enabled)]))}. Gen1 or unsupported images sometimes require it, but the default posture is Trusted Launch on."
  }
}

# A NIC with a public IP attached deserves a second look (a bastion is usually the better door).
check "public_ps_are_visible" {
  assert {
    condition     = alltrue([for k, v in var.windows_virtual_machines : v.public_ip_address_id == null])
    error_message = "These VMs attach a public IP to their NIC: ${join(", ", sort([for k, v in var.windows_virtual_machines : k if v.public_ip_address_id != null]))}. Prefer a bastion (the bastion module's Developer SKU is free) unless direct exposure is deliberate."
  }
}
