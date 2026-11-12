# The image catalog: friendly keys for the marketplace images people actually mean, replacing the old
# external "SKU calculator" modules with one structured, in-module map. Every reference was verified
# against the live marketplace (az vm image show) on 2026-07-03: all are Gen2 (hyperVGeneration V2)
# and Trusted Launch capable, which matters because the module defaults secure boot and vTPM on.
# None carry a marketplace plan. Hotpatching support follows the provider's sku allow-list: for
# Server 2022 only the -hotpatch and -core AzureEdition skus qualify (not the plain azure-edition),
# while 2025-datacenter-azure-edition qualifies directly.
#
# The Windows 11 entries were verified the same way on 2026-11-12: the MicrosoftWindowsDesktop
# windows-11 offer, Gen2, Trusted Launch capable, no plan. They carry license_type = "Windows_Client",
# the multi-tenant hosting rights attestation Microsoft requires for Windows client OS on Azure
# (eligible per-user Windows or Microsoft 365 E3/E5, A3/A5 or Business Premium licensing); an
# explicit license_type on the VM wins. Keys pin the feature update, as the Server keys pin the year,
# because changing an image reference replaces the VM. Only in-support releases are carried: 25H2
# Pro and Enterprise, and 24H2 Enterprise (24H2 Pro left support in October 2026). Azure guest
# patching does not support desktop images, so these VMs patch through Windows Update
# (AutomaticByOS) with patch_assessment_mode resolved to ImageDefault (see locals.tf).
#
# Discover the keys with the image_catalog_keys output; pick one with source_image_simple.
# source_image_reference and source_image_id remain first-class for anything the catalog does not
# carry.
locals {
  image_catalog = {
    WindowsServer2022 = {
      publisher    = "MicrosoftWindowsServer"
      offer        = "WindowsServer"
      sku          = "2022-datacenter-g2"
      plan         = null
      license_type = null
    }
    WindowsServer2022AzureEdition = {
      publisher    = "MicrosoftWindowsServer"
      offer        = "WindowsServer"
      sku          = "2022-datacenter-azure-edition"
      plan         = null
      license_type = null
    }
    WindowsServer2025 = {
      publisher    = "MicrosoftWindowsServer"
      offer        = "WindowsServer"
      sku          = "2025-datacenter-g2"
      plan         = null
      license_type = null
    }
    WindowsServer2025AzureEdition = {
      publisher    = "MicrosoftWindowsServer"
      offer        = "WindowsServer"
      sku          = "2025-datacenter-azure-edition"
      plan         = null
      license_type = null
    }
    Windows11Pro25H2 = {
      publisher    = "MicrosoftWindowsDesktop"
      offer        = "windows-11"
      sku          = "win11-25h2-pro"
      plan         = null
      license_type = "Windows_Client"
    }
    Windows11Enterprise25H2 = {
      publisher    = "MicrosoftWindowsDesktop"
      offer        = "windows-11"
      sku          = "win11-25h2-ent"
      plan         = null
      license_type = "Windows_Client"
    }
    Windows11Enterprise24H2 = {
      publisher    = "MicrosoftWindowsDesktop"
      offer        = "windows-11"
      sku          = "win11-24h2-ent"
      plan         = null
      license_type = "Windows_Client"
    }
  }

  # Catalog keys whose images support hotpatching, per the provider's sku allow-list.
  hotpatch_capable_keys = ["WindowsServer2025AzureEdition"]
}
