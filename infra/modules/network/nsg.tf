# NSGs exist so the governance policy doesn't deploy its own unpredictably.
# Names match the policy's convention exactly so it sees these as compliant.
#
# These are ALLOW rules with no catch-all deny, so they do not currently
# restrict traffic - default rules still permit VNet-to-VNet and all outbound.
# They document the egress this workload actually needs. Adding a low-priority
# deny turns this into a real boundary; do that only after confirming every
# Container Apps dependency is covered.

resource "azurerm_network_security_group" "aca" {
  name                = "vnet-${var.naming_prefix}-snet-aca-nsg-${var.location}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_rule" "aca_out" {
  for_each = {
    entra    = { priority = 100, tag = "AzureActiveDirectory", ports = ["443"] }
    acr      = { priority = 110, tag = "AzureContainerRegistry", ports = ["443"] }
    mcr      = { priority = 120, tag = "MicrosoftContainerRegistry", ports = ["443"] }
    sql      = { priority = 130, tag = var.sql_service_tag, ports = ["1433"] }
    monitor  = { priority = 140, tag = "AzureMonitor", ports = ["443"] }
    storage  = { priority = 150, tag = var.storage_service_tag, ports = ["443"] }
    keyvault = { priority = 160, tag = "AzureKeyVault", ports = ["443"] }
  }

  name                        = "Allow-${each.key}-Outbound"
  priority                    = each.value.priority
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = each.value.ports
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = each.value.tag
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aca.name
}

# Azure platform DNS. Container Apps breaks without it.
resource "azurerm_network_security_rule" "aca_dns" {
  name                        = "Allow-AzureDNS-Outbound"
  priority                    = 170
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aca.name
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "vnet-${var.naming_prefix}-snet-pe-nsg-${var.location}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Private endpoints are inbound-only; the subnet already has
# default_outbound_access_enabled = false.
resource "azurerm_network_security_rule" "pe_in" {
  for_each = {
    sql = { priority = 100, ports = ["1433"] }
    tls = { priority = 110, ports = ["443"] }
  }

  name                        = "Allow-Vnet-${each.key}-Inbound"
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = each.value.ports
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private_endpoints.name
}

resource "azurerm_subnet_network_security_group_association" "aca" {
  subnet_id                 = azurerm_subnet.aca.id
  network_security_group_id = azurerm_network_security_group.aca.id
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}