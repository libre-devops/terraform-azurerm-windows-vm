output "location" {
  value = local.location
}

output "rg_name" {
  value = local.rg_name
}

output "subnet_id" {
  value = local.subnet_id
}

output "tags" {
  value = {
    environment = "test"
  }
}

output "vm_name" {
  value = local.vm_name
}