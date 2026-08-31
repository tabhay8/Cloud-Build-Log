variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "naming_prefix" { type = string }
variable "tags" { type = map(string) }

variable "vnet_address_space" {
  type        = list(string)
  description = "VNet CIDR. /16 leaves room for future subnets."
  default     = ["10.10.0.0/16"]
}

variable "aca_subnet_prefix" {
  type        = list(string)
  description = "Container Apps subnet. Workload profiles need /27 minimum; /23 gives scaling headroom and CANNOT be changed after the environment is created."
  default     = ["10.10.0.0/23"]
}

variable "pe_subnet_prefix" {
  type        = list(string)
  description = "Private endpoints subnet. /27 minimum."
  default     = ["10.10.2.0/27"]
}

variable "private_dns_zones" {
  type        = list(string)
  description = "Zones that make private endpoint names resolve to private IPs."
  default = [
    "privatelink.database.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.azurecr.io"
  ]
}

variable "sql_service_tag" {
  type        = string
  description = "Regional SQL service tag, e.g. Sql.CentralUS."
  default     = "Sql.CentralUS"
}

variable "storage_service_tag" {
  type        = string
  description = "Regional Storage service tag, e.g. Storage.CentralUS."
  default     = "Storage.CentralUS"
}