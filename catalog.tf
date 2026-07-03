# The image catalog: friendly keys for the marketplace images people actually mean, replacing the old
# external "SKU calculator" modules with one structured, in-module map. Every reference was verified
# against the live marketplace (az vm image show) on 2026-07-03: all are Gen2 (hyperVGeneration V2)
# and Trusted Launch capable, which matters because the module defaults secure boot and vTPM on.
# None carry a marketplace plan. The AzureEdition entries are the hotpatching-capable ones.
#
# Discover the keys with the image_catalog_keys output; pick one with source_image_simple.
# source_image_reference and source_image_id remain first-class for anything the catalog does not
# carry.
locals {
  image_catalog = {
    WindowsServer2022 = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-g2"
      plan      = null
    }
    WindowsServer2022AzureEdition = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      plan      = null
    }
    WindowsServer2025 = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2025-datacenter-g2"
      plan      = null
    }
    WindowsServer2025AzureEdition = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2025-datacenter-azure-edition"
      plan      = null
    }
  }

  # Catalog keys whose images support hotpatching (the azure-edition SKUs).
  hotpatch_capable_keys = ["WindowsServer2022AzureEdition", "WindowsServer2025AzureEdition"]
}
