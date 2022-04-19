variable "rg_name" {
  description = "The name of the resource group, this module does not create a resource group, it is expecting the value of a resource group already exists"
  type        = string
  validation {
    condition     = length(var.rg_name) > 1 && length(var.rg_name) <= 24
    error_message = "Resource group name is not valid."
  }
}

variable "location" {
  description = "The location for this resource to be put in"
  type        = string
}

variable "vm_amount" {
  description = "A number, with the amount of VMs which is expected to be created"
  type        = number
}

variable "vm_hostname" {
  description = "The hostname of the vm"
  type        = string
}

variable "patch_mode" {
  default     = "Manual"
  description = "The patching mode of the virtual machines being deployed, default is Manual"
  type        = string
}

variable "enable_automatic_updates" {
  default     = false
  description = "Should automatic updates be enabled? Defaults to false"
  type        = string
}

variable "static_private_ip" {
  default     = null
  description = "If you are using a static IP, set it in this variable"
  type        = string
}

variable "public_ip_sku" {
  default     = null
  description = "If you wish to assign a public IP directly to your nic, set this to Standard"
  type        = string
}

variable "pip_name" {
  default     = null
  description = "If you are using a Public IP, set the name in this variable"
  type        = string
}

variable "pip_custom_dns_label" {
  default     = null
  description = "If you are using a public IP and wish to assign a custom DNS label, set here, otherwise, the VM host name will be used"
}

variable "subnet_id" {
  type        = string
  description = "The subnet ID for the NICs which are created with the VMs to be added to"
}

variable "vm_plan" {
  description = "Used for VMs which requires a plan"
  type        = set(string)
  default     = null
}

variable "spot_instance_max_bid_price" {
  default     = null
  description = "The max bid price for a spot instance"
  type        = string
}

variable "spot_instance_eviction_policy" {
  default     = null
  description = "The eviction policy for a spot instance"
  type        = string
}

variable "spot_instance" {
  description = "Whether the VM is a spot instance or not"
  type        = bool
  default     = false
}

variable "timezone" {
  default     = "GMT Standard Time"
  description = "The timezone for your VM to be deployed with"
  type        = string
}

variable "availability_zone" {
  default     = null
  description = "The availability zone for the VMs to be created to"
  type        = string
}

variable "vm_os_disk_size_gb" {
  default     = "127"
  description = "The size of the OS Disk in GiB"
  type        = string
}

variable "admin_password" {
  description = "The admin password to be used on the VMSS that will be deployed. The password must meet the complexity requirements of Azure."
  type        = string
  default     = ""
}

variable "admin_username" {
  description = "The admin username of the VM that will be deployed."
  type        = string
  default     = "LibreDevOpsAdmin"
}

variable "storage_account_type" {
  description = "Defines the type of storage account to be created. Valid options are Standard_LRS, Standard_ZRS, Standard_GRS, Standard_RAGRS, Premium_LRS."
  type        = string
  default     = "Standard_LRS"
}

variable "vm_size" {
  description = "Specifies the size of the virtual machine."
  type        = string
  default     = "Standard_B2ms"
}

variable "vm_os_simple" {
  description = "Specify WindowsServer, to get the latest image version of the specified os.  Do not provide this value if a custom value is used for vm_os_publisher, vm_os_offer, and vm_os_sku."
  type        = string
  default     = ""
}

variable "is_custom_image" {
  description = "Boolean flag to notify when the custom image is used."
  type        = bool
  default     = false
}

variable "asg_name" {
  description = "The name of the application security group to be made"
  type        = string
}

variable "license_type" {
  description = "Specifies the BYOL Type for this Virtual Machine. This is only applicable to Windows Virtual Machines. Possible values are Windows_Client and Windows_Server"
  type        = string
  default     = null
}

variable "vm_os_id" {
  description = "The resource ID of the image that you want to deploy if you are using a custom image.Note, need to provide is_windows_image = true for windows custom images."
  type        = string
  default     = ""
}

variable "vm_os_publisher" {
  description = "The name of the publisher of the image that you want to deploy. This is ignored when vm_os_id or vm_os_simple are provided."
  type        = string
  default     = ""
}

variable "provision_vm_agent" {
  description = "Whether the Azure agent is installed on this VM, default is true"
  type        = bool
  default     = true
}

variable "enable_encryption_at_host" {
  description = "Whether host encryption is enabled"
  type        = bool
  default     = false
}

variable "allow_extension_operations" {
  description = "Whether extensions are allowed to execute on the VM"
  type        = bool
  default     = true
}

variable "vm_os_offer" {
  description = "The name of the offer of the image that you want to deploy. This is ignored when vm_os_id or vm_os_simple are provided."
  type        = string
  default     = ""
}

variable "vm_os_sku" {
  description = "The sku of the image that you want to deploy. This is ignored when vm_os_id or vm_os_simple are provided."
  type        = string
  default     = ""
}

variable "vm_os_version" {
  description = "The version of the image that you want to deploy. This is ignored when vm_os_id or vm_os_simple are provided."
  type        = string
  default     = "latest"
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module."

  default = {
    source = "terraform"
  }
}

variable "allocation_method" {
  description = "Defines how an IP address is assigned. Options are Static or Dynamic."
  type        = string
  default     = "Dynamic"
}

variable "data_disk_size_gb" {
  description = "Storage data disk size size."
  type        = number
  default     = 30
}

variable "enable_accelerated_networking" {
  type        = bool
  description = "(Optional) Enable accelerated networking on Network interface."
  default     = false
}
variable "identity_type" {
  description = "The Managed Service Identity Type of this Virtual Machine."
  type        = string
  default     = ""
}

variable "identity_ids" {
  description = "Specifies a list of user managed identity ids to be assigned to the VM."
  type        = list(string)
  default     = []
}
