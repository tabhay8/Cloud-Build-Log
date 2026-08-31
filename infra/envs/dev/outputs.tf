output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "naming_prefix" {
  value = module.naming.prefix
}

output "static_web_app_default_hostname" {
  value = azurerm_static_web_app.site.default_host_name
}

output "static_web_app_api_key" {
  value     = azurerm_static_web_app.site.api_key
  sensitive = true
}

output "vnet_name" { value = module.network.vnet_name }
output "aca_subnet_id" { value = module.network.aca_subnet_id }


output "log_analytics_workspace_name" {
  value = module.observability.log_analytics_workspace_name
}