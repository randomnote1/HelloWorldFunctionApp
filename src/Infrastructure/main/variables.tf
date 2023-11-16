variable "azcloud" {
  type        = string
  default     = "public"
  description = "The Azure cloud where the resources will be deployed."
}

variable "resource_group_location" {
  type        = string
  default     = "eastus2"
  description = "The Azure region where the resource group will be created."
}

variable "application_friendly_name" {
  type        = string
  default     = "Hello World Function App"
  description = "The name of the application."
}

variable "resource_name_prefix" {
  type        = string
  description = "A unique prefix to apply to all the resources in this solution."
}

variable "virtual_network_address_space" {
  type        = list(string)
  description = "Address space of the virtual network."
}

variable "admin_ip_address_ranges" {
  type        = map(any)
  description = "Specify the IP address ranges which are allowed to access all the Azure resources using CIDR notation."
  default     = {}
}
