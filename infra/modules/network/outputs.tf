output "vnet_id"                  { value = azurerm_virtual_network.main.id }
output "vnet_name"                { value = azurerm_virtual_network.main.name }
output "aca_subnet_id"            { value = azurerm_subnet.aca.id }
output "private_endpoint_subnet_id" { value = azurerm_subnet.private_endpoints.id }

output "private_dns_zone_ids" {
  description = "Map of zone name to ID, consumed by Phase 4 private endpoints."
  value       = { for k, v in azurerm_private_dns_zone.zones : k => v.id }
}