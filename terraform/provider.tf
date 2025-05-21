provider "azurerm" {
  features {}
  subscription_id = local.subscription_id
}

provider "archive" {}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">=2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">=3.0.0"
    }
  }
}