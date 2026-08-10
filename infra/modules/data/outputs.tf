output "sql_server_name"           { value = azurerm_mssql_server.main.name }
output "sql_server_fqdn"           { value = azurerm_mssql_server.main.fully_qualified_domain_name }
output "sql_database_name"         { value = azurerm_mssql_database.main.name }
output "key_vault_id"              { value = azurerm_key_vault.main.id }
output "key_vault_name"            { value = azurerm_key_vault.main.name }