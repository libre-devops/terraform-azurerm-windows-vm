########################################
# 0 –– stub the provider
########################################
mock_provider "azurerm" {}

########################################
# 1 –– prepare shared test inputs
########################################
run "setup" {
  module {
    # path is relative to the *repo root* where you run terraform commands
    source = "./tests/setup-unit-tests"
  }
}

########################################
# 2 –– default-config VM scenario
########################################
run "vm_default" {
  command = plan

  # real module under test – repo root
  module {
    source = "./" # one level up from tests/, NOT "../../"
  }

  variables {
    location = run.setup.location
    rg_name  = run.setup.rg_name
    tags     = run.setup.tags

    windows_vms = [
      {
        name           = run.setup.vm_name
        timezone       = "UTC"
        vm_os_simple   = "WindowsServer2025Gen2"
        vm_size        = "Standard_B2ms"
        admin_username = "azureadmin"
        admin_password = "Str0ngP@ssword123!"
        subnet_id      = run.setup.subnet_id
        os_disk = {
          disk_size_gb = 128
        }
      }
    ]
  }

  ######################################
  # 3 –– assertions
  ######################################
  assert {
    condition     = length(azurerm_windows_virtual_machine.this) == 1
    error_message = "VM resource was not created"
  }
}
