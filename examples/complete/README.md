<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

The Windows "secure VM estate in a pinch" build, end to end: tags, resource group, vnet with an NSG
admitting RDP only from inside the vnet, forward AND reverse private DNS zones auto-registering every
VM, a free Developer bastion as the only door (no public IPs anywhere), a generated admin password
whose retrievable copy lives in a key vault (written write-only), Log Analytics with VM Insights
wired to every VM through their system identities, and two hardened VMs exercising the full surface:
a hotpatch-enabled AzureEdition image with platform patching, a timezone, data disks (auto LUNs) and
a PowerShell run command, plus an explicit image reference with spot pricing, a zone, a static
private IP, accelerated networking, Azure Hybrid Benefit, and a Premium OS disk. The disposable
example vault opts out of the keyvault module's firewall default so the runner can reach the data
plane. Run it with `just e2e complete`, which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
# The Windows twin of the "secure VM estate in a pinch" build: tags -> rg -> vnet with an NSG
# admitting RDP only from inside the vnet -> private DNS (forward and reverse, auto-registered) -> a
# free Developer bastion as the only door -> a vault holding the generated admin password (written
# write-only) -> Log Analytics with VM Insights -> hardened VMs.
locals {
  location  = lookup(var.regions, var.loc, "uksouth")
  rg_name   = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  vnet_name = "vnet-${var.short}-${var.loc}-${terraform.workspace}-002"
  nsg_name  = "nsg-${var.short}-${var.loc}-${terraform.workspace}-002"
  kv_name   = "kv-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name  = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
  bas_name  = "bas-${var.short}-${var.loc}-${terraform.workspace}-002"
  vm_app    = "vm-${var.short}-app-${var.loc}-${terraform.workspace}-002"
  vm_worker = "vm-${var.short}-wkr-${var.loc}-${terraform.workspace}-002"
}

data "azurerm_client_config" "current" {}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-windows-vm" }
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

# The VM subnet's NSG: the module's secure defaults with RDP admitted only from inside the vnet,
# which is where the bastion lives.
module "nsg" {
  source  = "libre-devops/nsg/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  name = local.nsg_name

  security_rules = {
    allow-vnet-rdp-inbound = {
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      description                = "RDP from inside the vnet only (the bastion's path)."
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
  }

  subnet_associations = {
    "snet-app-${local.vnet_name}" = module.network.subnet_ids["snet-app-${local.vnet_name}"]
  }
}

# Forward and reverse private DNS, auto-registering every VM in the vnet.
module "private_dns" {
  source  = "libre-devops/private-dns-zone/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  tags              = module.tags.tags

  private_dns_zones = {
    "corp.internal" = {
      # Same key as the default link below, so this REPLACES it for corp.internal (a zone may hold
      # only one link per vnet, and only one zone per vnet may auto-register).
      vnet_links = {
        vnet-link = {
          virtual_network_id   = module.network.vnet_id
          registration_enabled = true
        }
      }
    }
  }

  reverse_dns_zone_cidrs = ["10.0.0.0/16"]

  # Resolution-only links for every zone (the reverse zones included).
  default_vnet_links = {
    vnet-link = {
      virtual_network_id = module.network.vnet_id
    }
  }
}

# The door: a free Developer bastion attached to the vnet. No public IPs on any NIC. Serialized
# after the DNS links: a Developer bastion requires the vnet in a Succeeded state, and concurrent
# vnet-link updates can hold it in Updating.
module "bastion" {
  source  = "libre-devops/bastion/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  bastion_hosts = {
    (local.bas_name) = {
      virtual_network_id = module.network.vnet_id
    }
  }

  depends_on = [module.private_dns]
}

# The generated admin password. The provider stores VM credentials in the raw state as plain text
# either way (see the disclaimers); the vault copy below is the retrievable, write-only-stored copy
# an operator actually uses.
resource "random_password" "admin" {
  length  = 24
  special = true
}

# The vault the password lands in. The keyvault module firewalls vaults by default; this DISPOSABLE
# example vault opts out so the CI runner can reach the data plane (for a real firewalled vault,
# allow-list your egress IP or use the terraform-azure action's key vault dance inputs).
module "keyvault" {
  source  = "libre-devops/keyvault/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  key_vaults = {
    (local.kv_name) = {
      rbac_authorization_enabled = false
      purge_protection_enabled   = false
      # The keyvault module firewalls vaults by default; this DISPOSABLE example vault opts out so
      # the CI runner can reach the data plane. Allow is the expressible opt-out (an explicit null
      # would be replaced by the secure default via optional()).
      network_acls = { default_action = "Allow" }
      access_policies = [
        {
          object_id          = data.azurerm_client_config.current.object_id
          secret_permissions = ["Get", "List", "Set", "Delete", "Recover", "Purge"]
        }
      ]
    }
  }
}

# The password's vault copy, written through value_wo (never stored in the secret resource's state).
module "keyvault_secret" {
  source  = "libre-devops/keyvault-secret/azurerm"
  version = "~> 4.0"

  key_vault_id = module.keyvault.ids[local.kv_name]
  tags         = module.tags.tags

  secret_values = {
    "${local.vm_app}-admin-password" = random_password.admin.result
  }

  secrets = {
    "${local.vm_app}-admin-password" = { content_type = "text/plain" }
  }
}

# Observability: Log Analytics backing VM Insights for every VM below.
module "log_analytics" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = { (local.law_name) = {} }
}

# The VMs: secure defaults throughout (Trusted Launch, system identities, managed boot diagnostics,
# automatic updates), VM Insights wired via the module, and the full per-VM surface exercised across
# the pair.
module "windows_vm" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  vm_insights = {
    log_analytics_workspace_id = module.log_analytics.workspace_ids[local.law_name]
  }

  windows_virtual_machines = {
    # The app VM: hotpatch-capable AzureEdition image with platform patching, a timezone, data disks
    # with auto LUNs, and a PowerShell run command proving the box is alive.
    (local.vm_app) = {
      size                = "Standard_D2lds_v6"
      admin_username      = "azureadmin"
      admin_password      = random_password.admin.result
      source_image_simple = "WindowsServer2025AzureEdition"
      subnet_id           = module.network.subnet_ids["snet-app-${local.vnet_name}"]

      patch_mode          = "AutomaticByPlatform"
      hotpatching_enabled = true
      timezone            = "GMT Standard Time"

      data_disks = {
        "datadisk01-${local.vm_app}" = { disk_size_gb = 32 }
        "datadisk02-${local.vm_app}" = { disk_size_gb = 64, storage_account_type = "Premium_LRS", caching = "ReadOnly" }
      }

      run_command = {
        script = "Write-Output \"provisioned $env:COMPUTERNAME at $((Get-Date).ToUniversalTime().ToString('o'))\""
      }

      tags = { Component = "app" }
    }

    # The worker: explicit image reference, spot pricing, a static private IP, a zone, and Azure
    # Hybrid Benefit licensing.
    (local.vm_worker) = {
      size           = "Standard_D2lds_v6"
      admin_username = "azureadmin"
      admin_password = random_password.admin.result
      source_image_reference = {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2025-datacenter-g2"
      }
      subnet_id          = module.network.subnet_ids["snet-app-${local.vnet_name}"]
      private_ip_address = "10.0.1.10"
      zone               = "1"
      spot               = { eviction_policy = "Deallocate" }
      license_type       = "Windows_Server"
      # No explicit disk_size_gb: Windows Server images are 127 GB and Azure rejects smaller disks.
      os_disk = {
        storage_account_type = "Premium_LRS"
      }
      accelerated_networking_enabled = true
      tags                           = { Component = "worker" }
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.23.0, < 5.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.7.0, < 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.23.0, < 5.0.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.7.0, < 4.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bastion"></a> [bastion](#module\_bastion) | libre-devops/bastion/azurerm | ~> 4.0 |
| <a name="module_keyvault"></a> [keyvault](#module\_keyvault) | libre-devops/keyvault/azurerm | ~> 4.0 |
| <a name="module_keyvault_secret"></a> [keyvault\_secret](#module\_keyvault\_secret) | libre-devops/keyvault-secret/azurerm | ~> 4.0 |
| <a name="module_log_analytics"></a> [log\_analytics](#module\_log\_analytics) | libre-devops/log-analytics-workspace/azurerm | ~> 4.0 |
| <a name="module_network"></a> [network](#module\_network) | libre-devops/network/azurerm | ~> 4.0 |
| <a name="module_nsg"></a> [nsg](#module\_nsg) | libre-devops/nsg/azurerm | ~> 4.0 |
| <a name="module_private_dns"></a> [private\_dns](#module\_private\_dns) | libre-devops/private-dns-zone/azurerm | ~> 4.0 |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |
| <a name="module_windows_vm"></a> [windows\_vm](#module\_windows\_vm) | ../../ | n/a |

## Resources

| Name | Type |
|------|------|
| [random_password.admin](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_password_secret_ids"></a> [admin\_password\_secret\_ids](#output\_admin\_password\_secret\_ids) | The vaulted admin password (write-only secret) an operator retrieves. |
| <a name="output_bastion_dns_names"></a> [bastion\_dns\_names](#output\_bastion\_dns\_names) | The bastion's DNS name (the door to the VMs). |
| <a name="output_data_collection_rule_id"></a> [data\_collection\_rule\_id](#output\_data\_collection\_rule\_id) | The VM Insights DCR the VMs are associated with. |
| <a name="output_data_disk_ids"></a> [data\_disk\_ids](#output\_data\_disk\_ids) | Map of vm\|disk to managed disk id. |
| <a name="output_identity_principal_ids"></a> [identity\_principal\_ids](#output\_identity\_principal\_ids) | Map of VM name to system identity principal id (RBAC targets). |
| <a name="output_ids"></a> [ids](#output\_ids) | Map of VM name to resource id. |
| <a name="output_ids_zipmap"></a> [ids\_zipmap](#output\_ids\_zipmap) | Map of VM name to { name, id }. |
| <a name="output_private_ip_addresses"></a> [private\_ip\_addresses](#output\_private\_ip\_addresses) | Map of VM name to private IP (resolvable via the private DNS zones). |
<!-- END_TF_DOCS -->
