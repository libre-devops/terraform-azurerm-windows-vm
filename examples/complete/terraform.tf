terraform {
  # 1.11 floor: the composed keyvault-secret module uses write-only arguments and ephemeral values.
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.23.0, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7.0, < 4.0.0"
    }
  }

  backend "azurerm" {}
}
