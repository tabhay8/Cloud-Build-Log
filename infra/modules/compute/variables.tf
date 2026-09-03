variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

variable "acr_name" {
  type        = string
  description = "Globally unique, alphanumeric only"
}
variable "container_app_environment_name" { type = string }
variable "api_app_name" { type = string }
variable "migration_job_name" { type = string }

variable "api_identity_name" {
  type    = string
  default = "id-cbl-dev-cus-api"
}
variable "migration_identity_name" {
  type    = string
  default = "id-cbl-dev-cus-migrate"
}

variable "infrastructure_subnet_id" {
  type        = string
  description = "snet-aca, delegated to Microsoft.App/environments"
}
variable "log_analytics_workspace_id" { type = string }
variable "application_insights_connection_string" {
  type      = string
  default   = null
  sensitive = true
}

variable "sql_server_fqdn" { type = string }
variable "sql_database_name" { type = string }

# Both images must exist in the registry before the app and job are created.
# The quickstart default only exists so the bootstrap apply cannot fail on a
# missing image.
variable "api_image" {
  type    = string
  description = "Fully qualified API container image including tag."
}
variable "migration_image" {
  type    = string
  description = "Fully qualified migration container image including tag."
}

variable "cors_allowed_origins" { type = list(string) }

variable "api_target_port" {
  type    = number
  default = 3000
}
variable "api_liveness_path" {
  type        = string
  default     = "/health"
  description = "Process is alive. Must not touch SQL."
}
variable "api_readiness_path" {
  type        = string
  default     = "/ready"
  description = "Replica can serve traffic, i.e. the SQL ping succeeds."
}

variable "api_min_replicas" {
  type        = number
  default     = 1
  description = "One, deliberately. Scale to zero plus a 60-minute SQL auto-pause makes every cold visit look broken."
}
variable "api_max_replicas" {
  type    = number
  default = 3
}