locals {
  common_tags = merge(var.tags, {
    environment = var.environment
    project     = "hub-spoke-network"
  })
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "network" {
  name     = "${var.prefix}-${var.environment}-network-rg"
  location = var.location
  tags     = local.common_tags
}

# Hub VNet: holds the firewall and the shared services.
resource "azurerm_virtual_network" "hub" {
  name                = "${var.prefix}-${var.environment}-hub-vnet"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = var.hub_address_space
  tags                = local.common_tags

  subnet {
    # The firewall subnet name is reserved by Azure and must match exactly.
    name           = "AzureFirewallSubnet"
    address_prefix = "10.0.0.0/26"
  }

  subnet {
    name           = "snet-management"
    address_prefix = "10.0.1.0/24"
  }
}

resource "azurerm_public_ip" "firewall" {
  name                = "${var.prefix}-${var.environment}-fw-pip"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_firewall_policy" "hub" {
  name                = "${var.prefix}-${var.environment}-fw-policy"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  sku                 = var.firewall_sku_tier
  tags                = local.common_tags
}

resource "azurerm_firewall_policy_rule_collection_group" "spoke_egress" {
  name               = "spoke-egress"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 100

  network_rule_collection {
    name     = "allow-dns-and-https"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-dns"
      protocols             = ["UDP"]
      source_addresses      = concat(var.spoke_app_address_space, var.spoke_data_address_space)
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }

    rule {
      name                  = "allow-https"
      protocols             = ["TCP"]
      source_addresses      = concat(var.spoke_app_address_space, var.spoke_data_address_space)
      destination_addresses = ["*"]
      destination_ports     = ["443"]
    }
  }
}

resource "azurerm_firewall" "hub" {
  name                = "${var.prefix}-${var.environment}-hub-fw"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  tags                = local.common_tags

  ip_configuration {
    name = "fw-ipconfig"
    subnet_id = one([
      for s in azurerm_virtual_network.hub.subnet : s.id
      if s.name == "AzureFirewallSubnet"
    ])
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.spoke_egress]
}

# Spoke VNets: app and data. Workloads live here, never in the hub.
resource "azurerm_virtual_network" "spoke_app" {
  name                = "${var.prefix}-${var.environment}-spoke-app-vnet"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = var.spoke_app_address_space
  tags                = local.common_tags

  subnet {
    name           = "snet-workload"
    address_prefix = "10.1.0.0/24"
  }
}

resource "azurerm_virtual_network" "spoke_data" {
  name                = "${var.prefix}-${var.environment}-spoke-data-vnet"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = var.spoke_data_address_space
  tags                = local.common_tags

  subnet {
    name           = "snet-workload"
    address_prefix = "10.2.0.0/24"
  }
}

resource "azurerm_network_security_group" "spoke_app" {
  name                = "${var.prefix}-${var.environment}-spoke-app-nsg"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.common_tags

  security_rule {
    name                       = "allow-https-from-hub"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.hub_address_space[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "spoke_data" {
  name                = "${var.prefix}-${var.environment}-spoke-data-nsg"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.common_tags

  security_rule {
    name                       = "allow-https-from-hub"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.hub_address_space[0]
    destination_address_prefix = "*"
  }
}

# Peering is created in both directions. The hub side allows forwarded
# traffic so spoke-to-spoke traffic can flow through the firewall.
resource "azurerm_virtual_network_peering" "hub_to_app" {
  name                      = "hub-to-spoke-app"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_app.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "app_to_hub" {
  name                      = "spoke-app-to-hub"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.spoke_app.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "hub_to_data" {
  name                      = "hub-to-spoke-data"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_data.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "data_to_hub" {
  name                      = "spoke-data-to-hub"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.spoke_data.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}
