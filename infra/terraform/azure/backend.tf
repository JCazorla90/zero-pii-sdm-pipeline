terraform {
  required_version = "= 1.10.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.10"
    }
  }

  backend "azurerm" {
    use_azuread_auth = true
  }
}
