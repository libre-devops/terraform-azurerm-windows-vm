locals {
  rg      = provider::azurerm::parse_resource_id(var.resource_group_id)
  rg_name = local.rg.resource_group_name

  # Catalog resolution: a missing key falls back to a placeholder so expansion never errors
  # mid-expression, and the VM resource's precondition fails the plan with the valid key list.
  catalog_fallback = { publisher = "(unknown)", offer = "(unknown)", sku = "(unknown)", plan = null, license_type = null }

  resolved_image_reference = {
    for k, v in var.windows_virtual_machines : k => (
      v.source_image_simple != null
      ? {
        publisher = lookup(local.image_catalog, coalesce(v.source_image_simple, "-"), local.catalog_fallback).publisher
        offer     = lookup(local.image_catalog, coalesce(v.source_image_simple, "-"), local.catalog_fallback).offer
        sku       = lookup(local.image_catalog, coalesce(v.source_image_simple, "-"), local.catalog_fallback).sku
        version   = "latest"
      }
      : v.source_image_reference
    ) if v.source_image_id == null
  }

  # Effective marketplace plan: an explicit plan wins, otherwise a plan carried by the catalog entry
  # flows automatically (none of the current Windows entries carry one).
  resolved_plan = {
    for k, v in var.windows_virtual_machines : k => (
      v.plan != null ? v.plan : (
        v.source_image_simple != null
        ? lookup(local.image_catalog, coalesce(v.source_image_simple, "-"), local.catalog_fallback).plan
        : null
      )
    )
  }

  # Effective license_type: an explicit value wins, otherwise the catalog entry's flows automatically
  # (Windows_Client on the Windows 11 entries, null on the Server ones).
  resolved_license_type = {
    for k, v in var.windows_virtual_machines : k => (
      v.license_type != null ? v.license_type : (
        v.source_image_simple != null
        ? lookup(local.image_catalog, coalesce(v.source_image_simple, "-"), local.catalog_fallback).license_type
        : null
      )
    )
  }

  # VMs on a Windows client (desktop) marketplace image, whether from the catalog or an explicit
  # source_image_reference. Custom images (source_image_id) cannot be inspected at plan time.
  client_os_vms = sort([for k, v in local.resolved_image_reference : k if lower(v.publisher) == "microsoftwindowsdesktop"])

  # Effective patch assessment mode: an explicit value wins, otherwise AutomaticByPlatform (Azure
  # Update Manager periodic assessment) on Server and ImageDefault on Windows client images, because
  # Azure guest patching rejects AutomaticByPlatform for desktop images with a 400 ("The selected VM
  # image is not supported for VM Guest patch operations"), verified live on 2026-11-12.
  resolved_patch_assessment_mode = {
    for k, v in var.windows_virtual_machines : k => coalesce(
      v.patch_assessment_mode,
      contains(local.client_os_vms, k) ? "ImageDefault" : "AutomaticByPlatform"
    )
  }

  # Windows caps computer names at 15 characters, so the default derives from the VM name: upper
  # case, separators stripped, truncated.
  computer_names = {
    for k, v in var.windows_virtual_machines : k => coalesce(
      v.computer_name,
      substr(upper(replace(replace(replace(k, "-", ""), "_", ""), " ", "")), 0, 15)
    )
  }

  # Data disks flattened to one instance per (vm, disk), keyed "vm|disk". LUNs are auto-assigned by
  # declaration order (sorted disk names) unless set explicitly; keys derive from input map keys only,
  # so they stay known at plan time.
  data_disks = {
    for item in flatten([
      for vm_key, vm in var.windows_virtual_machines : [
        for idx, disk_name in sort(keys(vm.data_disks)) : {
          key      = "${vm_key}|${disk_name}"
          vm_key   = vm_key
          name     = disk_name
          auto_lun = idx
          disk     = vm.data_disks[disk_name]
        }
      ]
    ]) : item.key => item
  }

  # ASG associations flattened to one instance per (vm, asg index): principals are ids that may be
  # computed, so the key uses the index, never the id.
  asg_associations = {
    for item in flatten([
      for vm_key, vm in var.windows_virtual_machines : [
        for idx, asg_id in vm.application_security_group_ids : {
          key    = "${vm_key}|asg${idx}"
          vm_key = vm_key
          asg_id = asg_id
        }
      ]
    ]) : item.key => item
  }

  # Marketplace agreements are per (publisher, product, plan), deduplicated across VMs, covering both
  # explicit plans and catalog-carried ones.
  marketplace_agreements = {
    for item in distinct([
      for vm_key, vm in var.windows_virtual_machines : {
        publisher = local.resolved_plan[vm_key].publisher
        offer     = local.resolved_plan[vm_key].product
        plan      = local.resolved_plan[vm_key].name
      } if local.resolved_plan[vm_key] != null && vm.accept_marketplace_agreement
    ]) : "${item.publisher}|${item.offer}|${item.plan}" => item
  }

  # VMs with a run command configured.
  run_commands = { for k, v in var.windows_virtual_machines : k => v.run_command if v.run_command != null }

  # VM Insights wiring: the agent goes on every VM that has not opted out; associations follow.
  vm_insights_enabled = var.vm_insights != null
  monitored_vms       = local.vm_insights_enabled ? { for k, v in var.windows_virtual_machines : k => v if v.monitor_agent_enabled && v.identity.type != "None" } : {}
  create_dcr          = local.vm_insights_enabled && try(var.vm_insights.data_collection_rule_id, null) == null

  # The created DCR's name carries the OS, so a windows-vm and a linux-vm call in one resource group
  # no longer collide on dcr-vminsights-<rg> (a 409 Conflict). Two calls of the same OS in one group
  # need distinct data_collection_rule_name values, or share one DCR through data_collection_rule_id.
  dcr_name = coalesce(try(var.vm_insights.data_collection_rule_name, null), "dcr-vminsights-windows-${local.rg_name}")

  effective_dcr_id = local.create_dcr ? azurerm_monitor_data_collection_rule.vm_insights[0].id : try(var.vm_insights.data_collection_rule_id, null)
}
