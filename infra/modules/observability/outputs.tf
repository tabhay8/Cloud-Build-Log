output "log_analytics_workspace_id" {
  description = "Consumed by the Container Apps environment in Phase 5."
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.main.name
}

output "app_insights_connection_string" {
  description = "Injected into the API as APPLICATIONINSIGHTS_CONNECTION_STRING."
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "app_insights_id" {
  value = azurerm_application_insights.main.id
}