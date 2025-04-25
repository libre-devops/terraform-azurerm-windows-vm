# tests/setup-unit-tests/main.tf
terraform {
  required_providers {
    random = { source = "hashicorp/random" }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "random_uuid" "subscription_id" {}


locals {
  location  = "uksouth"
  rg_name   = "rg-test-${random_id.suffix.hex}"
  subnet_id = "/subscriptions/${random_uuid.subscription_id.result}/resourceGroups/${local.rg_name}/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/default"
}
