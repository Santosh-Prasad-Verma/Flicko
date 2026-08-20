variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "southeastasia"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "production"
}

variable "vm_ip" {
  type        = string
  description = "VM IP Address"
  default     = "104.43.114.32"
}

variable "storage_account_name" {
  type        = string
  description = "Existing storage account name"
  default     = "flickostorage2026"
}
