data "azurerm_client_config" "current" {}

# ---------- Azure SQL ----------

resource "azurerm_mssql_server" "main" {
  name                          = "sql-${var.naming_prefix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = var.public_access_enabled
  tags                          = var.tags
  identity {
    type = "SystemAssigned"
  }

  express_vulnerability_assessment_enabled = true

  # Entra ID only - there is no SQL login or password to leak.
  azuread_administrator {
    login_username              = "sg-cbl-sql-admins"
    object_id                   = var.sql_admin_group_object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = true
  }
  # azuread_administrator {
  #   login_username              = var.sql_admin_login
  #   object_id                   = var.sql_admin_object_id
  #   tenant_id                   = data.azurerm_client_config.current.tenant_id
  #   azuread_authentication_only = true
  # }
  
}

# Temporary: lets you load the schema from your machine.
# Disappears automatically once public_access_enabled goes false.
resource "azurerm_mssql_firewall_rule" "client" {
  count            = var.public_access_enabled && var.client_ip_address != "" ? 1 : 0
  name             = "allow-client-ip"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = var.client_ip_address
  end_ip_address   = var.client_ip_address
}

# Serverless: auto-pauses when idle, so an unused lab costs almost nothing.
# The tradeoff is a cold-start delay on the first query after a pause.
resource "azurerm_mssql_database" "main" {
  name                        = "sqldb-${var.naming_prefix}"
  server_id                   = azurerm_mssql_server.main.id
  sku_name                    = "GP_S_Gen5_2"
  min_capacity                = 0.5
  auto_pause_delay_in_minutes = 60
  max_size_gb                 = 32
  zone_redundant              = false
  storage_account_type        = "Local"
  tags                        = var.tags
}

# ---------- Key Vault ----------

resource "azurerm_key_vault" "main" {
  name                          = substr("kv-${replace(var.naming_prefix, "-", "")}", 0, 24)
  resource_group_name           = var.resource_group_name
  location                      = var.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  public_network_access_enabled = var.public_access_enabled

  # RBAC instead of access policies - the current model, and it uses the
  # same role assignments as the rest of Azure.
  rbac_authorization_enabled = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = var.purge_protection_enabled

  network_acls {
    default_action = var.public_access_enabled ? "Allow" : "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.public_access_enabled && var.client_ip_address != "" ? [var.client_ip_address] : []
  }

  tags = var.tags
}

# You need this role to write secrets. Without it the next resource fails 403.
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---------- Private endpoints ----------

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${var.naming_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  # This writes the A record into your Phase 2 DNS zone automatically.
  # Skip it and you would be creating DNS records by hand.
  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_ids["privatelink.database.windows.net"]]
  }
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${var.naming_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_ids["privatelink.vaultcore.azure.net"]]
  }
}