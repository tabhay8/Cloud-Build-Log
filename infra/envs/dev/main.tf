# Phase 0-1 scope: a clean resource group and naming foundation only.
# Later phases add network, observability, data, and container hosting modules.
#
# SECRETS POLICY: no credentials in code, tfvars, or state.
#   - Azure SQL uses Entra ID / managed identity, not a stored password.
#   - Any unavoidable secret lives in Key Vault and is referenced, never written.

module "naming" {
  source      = "../../modules/naming"
  project     = var.project
  environment = var.environment
  location    = var.location
}

resource "azurerm_resource_group" "main" {
  name     = module.naming.resource_group
  location = var.location
  tags     = merge(var.tags, { environment = var.environment })
}

resource "azurerm_static_web_app" "site" {
  name                = "stapp-${module.naming.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku_tier            = "Free"
  sku_size            = "Free"
  tags                = merge(var.tags, { environment = var.environment })

  lifecycle {
    ignore_changes = [repository_branch, repository_url]
  }
}

module "network" {
  source              = "../../modules/network"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  naming_prefix       = module.naming.prefix
  tags                = merge(var.tags, { environment = var.environment })
}

module "observability" {
  source              = "../../modules/observability"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  naming_prefix       = module.naming.prefix
  tags                = merge(var.tags, { environment = var.environment })
}