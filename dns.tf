# Private DNS so spoke workloads resolve PaaS endpoints to private IPs.
# The example below uses Blob storage, but the same pattern applies to
# Key Vault, SQL, ACR, and any other privatelink service.
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  name                  = "hub-link"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke_app" {
  name                  = "spoke-app-link"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.spoke_app.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke_data" {
  name                  = "spoke-data-link"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.spoke_data.id
}

resource "azurerm_storage_account" "example" {
  name                     = "${var.prefix}${var.environment}example"
  resource_group_name      = azurerm_resource_group.network.name
  location                 = azurerm_resource_group.network.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  # Public access stays off. The only path in is the private endpoint.
  public_network_access_enabled = false
  tags                          = local.common_tags
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "${var.prefix}-${var.environment}-st-pe"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  subnet_id           = one([for s in azurerm_virtual_network.spoke_app.subnet : s.id if s.name == "snet-workload"])
  tags                = local.common_tags

  private_service_connection {
    name                           = "blob-connection"
    private_connection_resource_id = azurerm_storage_account.example.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}
