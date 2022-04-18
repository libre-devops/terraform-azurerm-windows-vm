## Info

This module follows the KISS design pattern compared to other modules in the market.  It does not try to do anything crazy and consider availability sets, scale sets etc, this will create you a VM based on some parameters you give it, nothing more, nothing less


```hcl
module "win_vm" {
  source = "github.com/libre-devops/terraform-azurerm-windows-vm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location

  vm_amount          = "2"
  vm_hostname        = "vm${var.short}${var.loc}${terraform.workspace}"
  vm_size            = "Standard_B2ms"
  vm_os_simple       = "WindowsServer2019"
  vm_os_disk_size_gb = "127"

  admin_username = "LibreDevOpsAdmin"
  admin_password = data.azurerm_key_vault_secret.mgmt_local_admin_pwd.value

  subnet_id            = element(values(module.network.subnets_ids), 0)
  availability_zone    = "alternate" // When more than 1 VMs is made, it puts them in different availability zones
  storage_account_type = "Standard_LRS"
  identity_type        = "SystemAssigned"

  tags = module.rg.rg_tags
}
```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_os_calculator"></a> [os\_calculator](#module\_os\_calculator) | registry.terraform.io/libre-devops/win-os-sku-calculator/azurerm | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_network_interface.nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_windows_virtual_machine.windows_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | The admin password to be used on the VMSS that will be deployed. The password must meet the complexity requirements of Azure. | `string` | `""` | no |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | The admin username of the VM that will be deployed. | `string` | `"azureuser"` | no |
| <a name="input_allocation_method"></a> [allocation\_method](#input\_allocation\_method) | Defines how an IP address is assigned. Options are Static or Dynamic. | `string` | `"Dynamic"` | no |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | The availability zone for the VMs to be created to | `any` | `null` | no |
| <a name="input_boot_diagnostics"></a> [boot\_diagnostics](#input\_boot\_diagnostics) | (Optional) Enable or Disable boot diagnostics. | `bool` | `false` | no |
| <a name="input_boot_diagnostics_sa_type"></a> [boot\_diagnostics\_sa\_type](#input\_boot\_diagnostics\_sa\_type) | (Optional) Storage account type for boot diagnostics. | `string` | `"Standard_LRS"` | no |
| <a name="input_custom_data"></a> [custom\_data](#input\_custom\_data) | The custom data to supply to the machine. This can be used as a cloud-init for Linux systems. | `string` | `""` | no |
| <a name="input_data_disk_size_gb"></a> [data\_disk\_size\_gb](#input\_data\_disk\_size\_gb) | Storage data disk size size. | `number` | `30` | no |
| <a name="input_delete_data_disks_on_termination"></a> [delete\_data\_disks\_on\_termination](#input\_delete\_data\_disks\_on\_termination) | Delete data disks when machine is terminated. | `bool` | `false` | no |
| <a name="input_delete_os_disk_on_termination"></a> [delete\_os\_disk\_on\_termination](#input\_delete\_os\_disk\_on\_termination) | Delete datadisk when machine is terminated. | `bool` | `false` | no |
| <a name="input_enable_accelerated_networking"></a> [enable\_accelerated\_networking](#input\_enable\_accelerated\_networking) | (Optional) Enable accelerated networking on Network interface. | `bool` | `false` | no |
| <a name="input_enable_automatic_updates"></a> [enable\_automatic\_updates](#input\_enable\_automatic\_updates) | Should automatic updates be enabled? Defaults to false | `bool` | `false` | no |
| <a name="input_extra_disks"></a> [extra\_disks](#input\_extra\_disks) | (Optional) List of extra data disks attached to each virtual machine. | <pre>list(object({<br>    name = string<br>    size = number<br>  }))</pre> | `[]` | no |
| <a name="input_identity_ids"></a> [identity\_ids](#input\_identity\_ids) | Specifies a list of user managed identity ids to be assigned to the VM. | `list(string)` | `[]` | no |
| <a name="input_identity_type"></a> [identity\_type](#input\_identity\_type) | The Managed Service Identity Type of this Virtual Machine. | `string` | `""` | no |
| <a name="input_is_custom_image"></a> [is\_custom\_image](#input\_is\_custom\_image) | Boolean flag to notify when the custom image is used. | `bool` | `false` | no |
| <a name="input_license_type"></a> [license\_type](#input\_license\_type) | Specifies the BYOL Type for this Virtual Machine. This is only applicable to Windows Virtual Machines. Possible values are Windows\_Client and Windows\_Server | `string` | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | The location for this resource to be put in | `string` | n/a | yes |
| <a name="input_os_profile_secrets"></a> [os\_profile\_secrets](#input\_os\_profile\_secrets) | Specifies a list of certificates to be installed on the VM, each list item is a map with the keys source\_vault\_id, certificate\_url and certificate\_store. | `list(map(string))` | `[]` | no |
| <a name="input_patch_mode"></a> [patch\_mode](#input\_patch\_mode) | The patching mode of the virtual machines being deployed, default is Manual | `string` | `"Manual"` | no |
| <a name="input_public_ip_dns"></a> [public\_ip\_dns](#input\_public\_ip\_dns) | Optional globally unique per datacenter region domain name label to apply to each public ip address. e.g. thisvar.varlocation.cloudapp.azure.com where you specify only thisvar here. This is an array of names which will pair up sequentially to the number of public ips defined in var.nb\_public\_ip. One name or empty string is required for every public ip. If no public ip is desired, then set this to an array with a single empty string. | `list(string)` | <pre>[<br>  null<br>]</pre> | no |
| <a name="input_remote_port"></a> [remote\_port](#input\_remote\_port) | Remote tcp port to be used for access to the vms created via the nsg applied to the nics. | `string` | `""` | no |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | The name of the resource group, this module does not create a resource group, it is expecting the value of a resource group already exists | `string` | n/a | yes |
| <a name="input_storage_account_type"></a> [storage\_account\_type](#input\_storage\_account\_type) | Defines the type of storage account to be created. Valid options are Standard\_LRS, Standard\_ZRS, Standard\_GRS, Standard\_RAGRS, Premium\_LRS. | `string` | `"Standard_LRS"` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | The subnet ID for the NICs which are created with the VMs to be added to | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of the tags to use on the resources that are deployed with this module. | `map(string)` | <pre>{<br>  "source": "terraform"<br>}</pre> | no |
| <a name="input_timezone"></a> [timezone](#input\_timezone) | The timezone for your VM to be deployed with | `string` | `"GMT Standard Time"` | no |
| <a name="input_vm_amount"></a> [vm\_amount](#input\_vm\_amount) | A number, with the amount of VMs which is expected to be created | `number` | n/a | yes |
| <a name="input_vm_hostname"></a> [vm\_hostname](#input\_vm\_hostname) | The hostname of the vm | `string` | n/a | yes |
| <a name="input_vm_os_disk_size_gb"></a> [vm\_os\_disk\_size\_gb](#input\_vm\_os\_disk\_size\_gb) | The size of the OS Disk in GiB | `string` | `"127"` | no |
| <a name="input_vm_os_id"></a> [vm\_os\_id](#input\_vm\_os\_id) | The resource ID of the image that you want to deploy if you are using a custom image.Note, need to provide is\_windows\_image = true for windows custom images. | `string` | `""` | no |
| <a name="input_vm_os_offer"></a> [vm\_os\_offer](#input\_vm\_os\_offer) | The name of the offer of the image that you want to deploy. This is ignored when vm\_os\_id or vm\_os\_simple are provided. | `string` | `""` | no |
| <a name="input_vm_os_publisher"></a> [vm\_os\_publisher](#input\_vm\_os\_publisher) | The name of the publisher of the image that you want to deploy. This is ignored when vm\_os\_id or vm\_os\_simple are provided. | `string` | `""` | no |
| <a name="input_vm_os_simple"></a> [vm\_os\_simple](#input\_vm\_os\_simple) | Specify WindowsServer, to get the latest image version of the specified os.  Do not provide this value if a custom value is used for vm\_os\_publisher, vm\_os\_offer, and vm\_os\_sku. | `string` | `""` | no |
| <a name="input_vm_os_sku"></a> [vm\_os\_sku](#input\_vm\_os\_sku) | The sku of the image that you want to deploy. This is ignored when vm\_os\_id or vm\_os\_simple are provided. | `string` | `""` | no |
| <a name="input_vm_os_version"></a> [vm\_os\_version](#input\_vm\_os\_version) | The version of the image that you want to deploy. This is ignored when vm\_os\_id or vm\_os\_simple are provided. | `string` | `"latest"` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Specifies the size of the virtual machine. | `string` | `"Standard_D2s_v3"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_nic_id"></a> [nic\_id](#output\_nic\_id) | The ID of the nics |
| <a name="output_nic_ip_config_name"></a> [nic\_ip\_config\_name](#output\_nic\_ip\_config\_name) | The name of the IP Configurations |
| <a name="output_nic_ip_private_ip"></a> [nic\_ip\_private\_ip](#output\_nic\_ip\_private\_ip) | The private IP assigned to the NIC |
| <a name="output_vm_amount"></a> [vm\_amount](#output\_vm\_amount) | The amount of VMs passed to the vm\_amount variable |
| <a name="output_vm_identity"></a> [vm\_identity](#output\_vm\_identity) | map with key `Virtual Machine Id`, value `list of identity` created for the Virtual Machine. |
