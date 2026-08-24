output "acr_name" { value = azurerm_container_registry.this.name }
output "acr_login_server" { value = azurerm_container_registry.this.login_server }

output "api_url" {
  value       = "https://${azurerm_container_app.api.ingress[0].fqdn}"
  description = "Phase 6 points API_BASE here"
}

output "api_identity_client_id" {
  value       = azurerm_user_assigned_identity.api.client_id
  description = "Becomes the SID inside the database"
}
output "api_identity_name" { value = azurerm_user_assigned_identity.api.name }

output "migration_identity_principal_id" {
  value       = azurerm_user_assigned_identity.migration.principal_id
  description = "Add this to sg-cbl-sql-admins"
}
output "migration_identity_name" { value = azurerm_user_assigned_identity.migration.name }
output "migration_job_name" { value = azurerm_container_app_job.migration.name }