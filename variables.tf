variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Short prefix applied to resource names."
  type        = string
  default     = "hubspoke"
}

variable "environment" {
  description = "Environment tag, for example dev or prod."
  type        = string
  default     = "dev"
}

variable "hub_address_space" {
  description = "Address space for the hub VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "spoke_app_address_space" {
  description = "Address space for the app spoke VNet."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "spoke_data_address_space" {
  description = "Address space for the data spoke VNet."
  type        = list(string)
  default     = ["10.2.0.0/16"]
}

variable "firewall_sku_tier" {
  description = "Azure Firewall tier. Standard fits most lab and mid-size setups."
  type        = string
  default     = "Standard"
}

variable "tags" {
  description = "Extra tags applied to all resources."
  type        = map(string)
  default     = {}
}
