variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "naming_prefix"       { type = string }
variable "tags"                { type = map(string) }

variable "private_endpoint_subnet_id" {
  type        = string
  description = "snet-pe from the network module."
}

variable "private_dns_zone_ids" {
  type        = map(string)
  description = "Zone name to ID map from the network module."
}

variable "sql_admin_object_id" {
  type        = string
  description = "Entra ID object ID of the SQL administrator. No password is used."
}

variable "sql_admin_login" {
  type        = string
  description = "Display name for the Entra admin. Cosmetic."
  default     = "sql-admin"
}

variable "client_ip_address" {
  type        = string
  description = "Your public IP, allowed through the firewall while public access is on."
  default     = ""
}

variable "public_access_enabled" {
  type        = bool
  description = "Keep TRUE until the schema is loaded, then flip to FALSE. Once false, only the VNet can reach SQL and Key Vault."
  default     = true
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Blocks permanent deletion for 90 days. Recommended in production, awkward in a lab."
  default     = false
}
variable "sql_admin_group_object_id" {
  type        = string
  description = "Object id of sg-cbl-sql-admins"
}