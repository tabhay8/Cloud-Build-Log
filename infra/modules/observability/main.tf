resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.naming_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags
}

# Workspace-based App Insights. The classic standalone type is retired -
# workspace_id is what makes it workspace-based.
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.naming_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}