output "resource_group_name" {
  description = "Name of the resource group holding the network."
  value       = azurerm_resource_group.network.name
}

output "hub_vnet_id" {
  description = "Resource ID of the hub VNet."
  value       = azurerm_virtual_network.hub.id
}

output "spoke_app_vnet_id" {
  description = "Resource ID of the app spoke VNet."
  value       = azurerm_virtual_network.spoke_app.id
}

output "spoke_data_vnet_id" {
  description = "Resource ID of the data spoke VNet."
  value       = azurerm_virtual_network.spoke_data.id
}

output "firewall_private_ip" {
  description = "Private IP of the hub firewall. Spoke route tables point here."
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Public IP of the hub firewall."
  value       = azurerm_public_ip.firewall.ip_address
}

output "private_dns_zone_id" {
  description = "Resource ID of the private DNS zone for Blob storage."
  value       = azurerm_private_dns_zone.blob.id
}

output "storage_account_name" {
  description = "Name of the storage account behind the private endpoint."
  value       = azurerm_storage_account.example.name
}
