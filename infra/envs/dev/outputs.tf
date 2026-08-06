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