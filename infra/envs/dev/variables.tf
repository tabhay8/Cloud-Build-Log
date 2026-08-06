variable "project" {
  type        = string
  description = "Project name used in resource naming."
  default     = "cbl"
}

variable "environment" {
  type        = string
  description = "Environment short name."
  default     = "dev"
}

variable "location" {
  type        = string
  description = "Azure region."
  default     = "centralus"
}

variable "sql_admin_object_id" {
  type        = string
  description = "Entra ID object ID that becomes the Azure SQL admin. No password is ever stored."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default = {
    managedBy = "terraform"
    workload  = "cloud-build-log"
  }
}
