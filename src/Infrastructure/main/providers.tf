terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
    }

    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azuread" {
  environment = var.azcloud
}

provider "azurerm" {
  features {}
  environment                = var.azcloud
  skip_provider_registration = true
  storage_use_azuread        = true
}
