# The naming module has no output for the job, and container_app already carries
# the -api suffix, so the job name is derived rather than hand-written.
locals {
  migration_job_name = replace(module.naming.container_app, "-api", "-migrate")
}

module "compute" {
  source = "../../modules/compute"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  acr_name                       = module.naming.container_registry
  container_app_environment_name = module.naming.container_app_env
  api_app_name                   = module.naming.container_app
  migration_job_name             = local.migration_job_name

  infrastructure_subnet_id               = module.network.aca_subnet_id
  log_analytics_workspace_id             = module.observability.log_analytics_workspace_id
  application_insights_connection_string = module.observability.app_insights_connection_string

  sql_server_fqdn   = module.data.sql_server_fqdn
  sql_database_name = module.data.sql_database_name

  api_image       = var.api_image
  migration_image = var.migration_image

  cors_allowed_origins = var.cors_allowed_origins
}

variable "api_image" {
  type    = string
  default = "mcr.microsoft.com/k8se/quickstart:latest"
}
variable "migration_image" {
  type    = string
  default = "mcr.microsoft.com/k8se/quickstart:latest"
}
variable "cors_allowed_origins" {
  type = list(string)
  default = [
    "https://cloudbuild.domaincheck.store",
    "https://red-rock-0f96aa510.7.azurestaticapps.net",
  ]
}
variable "sql_admin_group_object_id" {
  type        = string
  description = "Object id of sg-cbl-sql-admins"
}

output "acr_login_server" { value = module.compute.acr_login_server }
output "api_url" { value = module.compute.api_url }
output "migration_job_name" { value = module.compute.migration_job_name }
output "migration_identity_principal_id" { value = module.compute.migration_identity_principal_id }