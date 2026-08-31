variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "naming_prefix" { type = string }
variable "tags" { type = map(string) }

variable "retention_in_days" {
  type        = number
  description = "Log retention. 30 days is the free floor; longer costs more."
  default     = 30
}

variable "daily_quota_gb" {
  type        = number
  description = "Ingestion cap in GB/day. -1 means unlimited. A low cap prevents a runaway logging bug from generating a large bill."
  default     = 1
}