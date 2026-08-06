# Central naming so every resource follows one convention.

variable "project" { type = string }
variable "environment" { type = string }
variable "location" { type = string }

locals {
  location_short = {
    centralus     = "cus"
    eastus        = "eus"
    eastus2       = "eus2"
    westus2       = "wus2"
    westeurope    = "weu"
    canadacentral = "cac"
  }
  loc    = lookup(local.location_short, var.location, substr(var.location, 0, 3))
  prefix = "${var.project}-${var.environment}-${local.loc}"
  compact = replace("${var.project}${var.environment}${local.loc}", "-", "")
}

output "prefix" { value = local.prefix }
output "resource_group" { value = "rg-${local.prefix}" }
output "vnet" { value = "vnet-${local.prefix}" }
output "log_analytics" { value = "log-${local.prefix}" }
output "app_insights" { value = "appi-${local.prefix}" }
output "key_vault" { value = substr("kv-${local.compact}", 0, 24) }
output "container_registry" { value = substr("cr${local.compact}", 0, 50) }
output "container_app_env" { value = "cae-${local.prefix}" }
output "container_app" { value = "ca-${local.prefix}-api" }
output "sql_server" { value = "sql-${local.prefix}" }
output "sql_database" { value = "sqldb-${local.prefix}" }
