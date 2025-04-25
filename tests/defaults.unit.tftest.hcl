########################################
# 0 –– stub the provider
########################################
mock_provider "azurerm" {}

########################################
# 1 –– prepare shared test inputs
########################################
run "setup" {
  module { source = "./setup-unit-tests" }
}

########################################
# 2 –– default-config VM scenario
########################################
run "vm_default" {
  command = plan # fast & free – no apply needed

  # minimal VM list exercising *default* values
  windows_vms = [
    {
      name           = "vm-basic"
      vm_size        = "Standard_B2ms"
      admin_username = "azureadmin"
      admin_password = "Str0ngP@ssword123!"
      subnet_id      = run.setup.subnet_id
      location       = run.setup.location
      rg_name        = run.setup.rg_name
      tags           = run.setup.tags
    }
  ]

  ######################################
  # 3 –– assertions
  ######################################
  assert {
    condition     = length(azurerm_windows_virtual_machine.this) == 1
    error_message = "VM resource was not created"
  }

  # validate a couple of defaults from the module interface
  assert {
    condition     = azurerm_windows_virtual_machine.this[0].patch_mode == "AutomaticByOS"
    error_message = "Patch mode default was not honoured"
  }

  assert {
    condition     = azurerm_network_interface.nic[0].ip_configuration[0].private_ip_address_allocation == "Dynamic"
    error_message = "NIC should default to dynamic IP allocation"
  }

}
