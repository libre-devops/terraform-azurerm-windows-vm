# Plan-time tests for the module. The azurerm provider is mocked, so no credentials, no features
# block, and no cloud calls are needed:
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {
  # Downstream resources parse these ids, so the mocks must be real-shaped.
  mock_resource "azurerm_network_interface" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.Network/networkInterfaces/nic-mock"
    }
  }
  mock_resource "azurerm_windows_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.Compute/virtualMachines/vm-mock"
    }
  }
  mock_resource "azurerm_managed_disk" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.Compute/disks/disk-mock"
    }
  }
  mock_resource "azurerm_monitor_data_collection_rule" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.Insights/dataCollectionRules/dcr-mock"
    }
  }
}

variables {
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
  location          = "uksouth"
  tags              = { Environment = "tst" }
}

# The secure defaults: Trusted Launch, system identity, managed boot diagnostics, automatic updates,
# the catalog resolving to a verified reference, and the 15-character computer name derivation.
run "secure_defaults_with_catalog" {
  command = apply

  variables {
    windows_virtual_machines = {
      "vm-ldo-app-uks-tst-001" = {
        size                = "Standard_D2lds_v6"
        admin_username      = "azureadmin"
        admin_password      = "CorrectHorseBatteryStaple1!"
        source_image_simple = "WindowsServer2022AzureEdition"
        subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.Network/virtualNetworks/vnet-t/subnets/snet-app"
      }
    }
  }

  assert {
    condition     = azurerm_windows_virtual_machine.this["vm-ldo-app-uks-tst-001"].secure_boot_enabled == true && azurerm_windows_virtual_machine.this["vm-ldo-app-uks-tst-001"].vtpm_enabled == true
    error_message = "Trusted Launch should be the default."
  }

  assert {
    condition     = azurerm_windows_virtual_machine.this["vm-ldo-app-uks-tst-001"].identity[0].type == "SystemAssigned"
    error_message = "A system-assigned identity should be the default."
  }

  assert {
    condition     = azurerm_windows_virtual_machine.this["vm-ldo-app-uks-tst-001"].automatic_updates_enabled == true
    error_message = "Automatic updates should be the default."
  }

  assert {
    condition     = azurerm_windows_virtual_machine.this["vm-ldo-app-uks-tst-001"].computer_name == "VMLDOAPPUKSTST0"
    error_message = "The computer name should derive from the VM name: upper case, separators stripped, 15 characters."
  }

  assert {
    condition     = azurerm_windows_virtual_machine.this["vm-ldo-app-uks-tst-001"].source_image_reference[0].sku == "2022-datacenter-azure-edition"
    error_message = "The catalog should resolve to the verified AzureEdition reference."
  }

  assert {
    condition     = length(azurerm_windows_virtual_machine.this["vm-ldo-app-uks-tst-001"].boot_diagnostics) == 1
    error_message = "Managed boot diagnostics should be on by default."
  }
}

# An unknown catalog key fails the plan with the key list.
run "rejects_unknown_catalog_key" {
  command = plan

  variables {
    windows_virtual_machines = {
      "vm-bad" = {
        size                = "Standard_D2lds_v6"
        admin_username      = "azureadmin"
        admin_password      = "CorrectHorseBatteryStaple1!"
        source_image_simple = "WindowsME"
        subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-t/providers/Microsoft.Network/virtualNetworks/vnet-t/subnets/snet"
      }
    }
  }

  expect_failures = [azurerm_windows_virtual_machine.this]
}

# An over-long explicit computer name is rejected by variable validation.
run "rejects_long_computer_name" {
  command = plan

  variables {
    windows_virtual_machines = {
      "vm-bad" = {
        size                = "Standard_D2lds_v6"
        admin_username      = "azureadmin"
        admin_password      = "CorrectHorseBatteryStaple1!"
        source_image_simple = "WindowsServer2022"
        computer_name       = "THISNAMEISWAYTOOLONG"
        subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-t/providers/Microsoft.Network/virtualNetworks/vnet-t/subnets/snet"
      }
    }
  }

  expect_failures = [var.windows_virtual_machines]
}

# Hotpatching without its prerequisites trips the advisory check.
run "flags_hotpatching_without_prereqs" {
  command = plan

  variables {
    windows_virtual_machines = {
      "vm-hp" = {
        size                = "Standard_D2lds_v6"
        admin_username      = "azureadmin"
        admin_password      = "CorrectHorseBatteryStaple1!"
        source_image_simple = "WindowsServer2022"
        hotpatching_enabled = true
        subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-t/providers/Microsoft.Network/virtualNetworks/vnet-t/subnets/snet"
      }
    }
  }

  expect_failures = [check.hotpatching_prerequisites]
}

# Hotpatching with the AzureEdition image and platform patching passes cleanly.
run "hotpatching_with_prereqs" {
  command = apply

  variables {
    windows_virtual_machines = {
      "vm-hp" = {
        size                = "Standard_D2lds_v6"
        admin_username      = "azureadmin"
        admin_password      = "CorrectHorseBatteryStaple1!"
        source_image_simple = "WindowsServer2025AzureEdition"
        hotpatching_enabled = true
        patch_mode          = "AutomaticByPlatform"
        timezone            = "GMT Standard Time"
        subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-t/providers/Microsoft.Network/virtualNetworks/vnet-t/subnets/snet"
      }
    }
  }

  assert {
    condition     = azurerm_windows_virtual_machine.this["vm-hp"].hotpatching_enabled == true && azurerm_windows_virtual_machine.this["vm-hp"].timezone == "GMT Standard Time"
    error_message = "Hotpatching and timezone should pass through."
  }
}

# Data disks: auto-assigned LUNs follow sorted declaration order; explicit LUNs win.
run "data_disks" {
  command = apply

  variables {
    windows_virtual_machines = {
      "vm-data" = {
        size                = "Standard_D2lds_v6"
        admin_username      = "azureadmin"
        admin_password      = "CorrectHorseBatteryStaple1!"
        source_image_simple = "WindowsServer2022"
        subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-t/providers/Microsoft.Network/virtualNetworks/vnet-t/subnets/snet"
        data_disks = {
          "disk-b" = { disk_size_gb = 64 }
          "disk-a" = { disk_size_gb = 32 }
          "disk-z" = { disk_size_gb = 16, lun = 9 }
        }
      }
    }
  }

  assert {
    condition     = azurerm_virtual_machine_data_disk_attachment.data["vm-data|disk-a"].lun == 0 && azurerm_virtual_machine_data_disk_attachment.data["vm-data|disk-b"].lun == 1 && azurerm_virtual_machine_data_disk_attachment.data["vm-data|disk-z"].lun == 9
    error_message = "Auto LUNs should follow sorted disk-name order; explicit LUNs win."
  }
}

# VM Insights: the WINDOWS monitor agent lands on every VM (with per-VM opt-out), the DCR is created,
# and the association points at it.
run "vm_insights" {
  command = apply

  variables {
    vm_insights = {
      log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-t/providers/Microsoft.OperationalInsights/workspaces/log-t"
    }
    windows_virtual_machines = {
      "vm-mon" = {
        size                = "Standard_D2lds_v6"
        admin_username      = "azureadmin"
        admin_password      = "CorrectHorseBatteryStaple1!"
        source_image_simple = "WindowsServer2022"
        subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-t/providers/Microsoft.Network/virtualNetworks/vnet-t/subnets/snet"
      }
      "vm-optout" = {
        size                  = "Standard_D2lds_v6"
        admin_username        = "azureadmin"
        admin_password        = "CorrectHorseBatteryStaple1!"
        source_image_simple   = "WindowsServer2022"
        monitor_agent_enabled = false
        subnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-t/providers/Microsoft.Network/virtualNetworks/vnet-t/subnets/snet"
      }
    }
  }

  assert {
    condition     = azurerm_virtual_machine_extension.monitor_agent["vm-mon"].type == "AzureMonitorWindowsAgent"
    error_message = "The WINDOWS monitor agent should be installed."
  }

  assert {
    condition     = length(azurerm_virtual_machine_extension.monitor_agent) == 1 && length(azurerm_monitor_data_collection_rule.vm_insights) == 1
    error_message = "The agent should respect the opt-out and the DCR should be created."
  }
}

# Identity None omits the block; the public IP posture check still fires (input only).
run "identity_none_and_public_ip_flagged" {
  command = plan

  variables {
    windows_virtual_machines = {
      "vm-exposed" = {
        size                 = "Standard_D2lds_v6"
        admin_username       = "azureadmin"
        admin_password       = "CorrectHorseBatteryStaple1!"
        source_image_simple  = "WindowsServer2022"
        identity             = { type = "None" }
        public_ip_address_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-t/providers/Microsoft.Network/publicIPAddresses/pip-t"
        subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-t/providers/Microsoft.Network/virtualNetworks/vnet-t/subnets/snet"
      }
    }
  }

  expect_failures = [check.public_ps_are_visible]
}
