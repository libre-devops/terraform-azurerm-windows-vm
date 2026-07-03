locals {
  location  = lookup(var.regions, var.loc, "uksouth")
  rg_name   = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
  vnet_name = "vnet-${var.short}-${var.loc}-${terraform.workspace}-001"
  vm_name   = "vm-app-${var.short}-${var.loc}-${terraform.workspace}-001"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "network" {
  source  = "libre-devops/network/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  vnet_name     = local.vnet_name
  address_space = ["10.0.0.0/16"]
  subnets = {
    "snet-app-${local.vnet_name}" = { address_prefixes = ["10.0.1.0/24"] }
  }
}

# Windows requires a password; generated here (state stores it in plain text, per the provider's
# disclaimer; the complete example shows vaulting it write-only alongside).
resource "random_password" "admin" {
  length  = 24
  special = true
}

# Minimal call: one VM with the secure defaults (Trusted Launch, system identity, managed boot
# diagnostics, automatic updates) from a friendly catalog image. No public IP: that is an input, and
# the bastion module is the intended door.
module "windows_vm" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  windows_virtual_machines = {
    (local.vm_name) = {
      size                = "Standard_D2lds_v6"
      admin_username      = "azureadmin"
      admin_password      = random_password.admin.result
      source_image_simple = "WindowsServer2022AzureEdition"
      subnet_id           = module.network.subnet_ids["snet-app-${local.vnet_name}"]
    }
  }
}
