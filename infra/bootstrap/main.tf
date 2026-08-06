# One-time bootstrap: creates the storage account that holds Terraform remote state.
# Run this once with local state, then configure the backend in envs/dev.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}

variable "location" {
  type        = string
  description = "Azure region for the state resources."
  default     = "centralus"
}

variable "prefix" {
  type        = string
  description = "Short name prefix used for all state resources."
  default     = "cbl"
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-${var.prefix}-tfstate"
  location = var.location
  tags     = { purpose = "terraform-state", project = var.prefix }
}

resource "azurerm_storage_account" "tfstate" {
  name                            = "st${var.prefix}${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # force Entra ID auth - no account keys

  blob_properties {
    versioning_enabled = true
    delete_retention_policy { days = 30 }
  }

  tags = { purpose = "terraform-state", project = var.prefix }
}

resource "azurerm_storage_container" "tfstate" {
  name               = "tfstate"
  storage_account_id = azurerm_storage_account.tfstate.id
}

output "resource_group_name" {
  value = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "container_name" {
  value = azurerm_storage_container.tfstate.name
}

output "backend_snippet" {
  description = "Paste into envs/dev/backend.tf after bootstrap."
  value       = <<-EOT
    terraform {
      backend "azurerm" {
        resource_group_name  = "${azurerm_resource_group.tfstate.name}"
        storage_account_name = "${azurerm_storage_account.tfstate.name}"
        container_name       = "${azurerm_storage_container.tfstate.name}"
        key                  = "dev.terraform.tfstate"
        use_azuread_auth     = true
      }
    }
  EOT
}
