terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
    }

    azurerm = {
      source = "hashicorp/azurerm"
    }
  }

  backend "local" {
    path = "../../../build/terraform.tfstate"
  }
}
