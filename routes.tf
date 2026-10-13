# Spoke route tables force all outbound traffic through the hub firewall.
# Nothing in a spoke talks to the internet directly.
resource "azurerm_route_table" "spoke_app" {
  name                = "${var.prefix}-${var.environment}-spoke-app-rt"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.common_tags

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_route_table" "spoke_data" {
  name                = "${var.prefix}-${var.environment}-spoke-data-rt"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.common_tags

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "spoke_app" {
  subnet_id      = one([for s in azurerm_virtual_network.spoke_app.subnet : s.id if s.name == "snet-workload"])
  route_table_id = azurerm_route_table.spoke_app.id
}

resource "azurerm_subnet_route_table_association" "spoke_data" {
  subnet_id      = one([for s in azurerm_virtual_network.spoke_data.subnet : s.id if s.name == "snet-workload"])
  route_table_id = azurerm_route_table.spoke_data.id
}
