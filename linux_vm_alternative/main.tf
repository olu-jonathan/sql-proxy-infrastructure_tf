locals {
  # Common settings
  location            = "westus3"
  resource_group_name = "Snowflake-Sql-Server-Proxy"
  # Resource names
  public_ip_name      = "sql-proxy-pip"
  nsg_name            = "sql-proxy-nsg"
  nic_name            = "sql-proxy-nic"
  nic_ha_name         = "sql-proxy-nic_ha"
  vm_name             = "snowsql-proxy-vm"
  vm_ha_name          = "snowsql-proxy-vm-ha"
  vm_disk_name        = "snowsql_proxy_vm_disk"
  vm_ha_disk_name     = "snowsql_proxy_vm_ha_disk"
  lb_name             = "sql-proxy-lb"
  lb_frontend_name    = "sql-proxy-lb-fe"
  lb_backend_pool     = "sql-proxy-bepool"
  pls_name            = "sql-proxy-privateLinkS"
  
  # Network settings
  admin_username      = "azureuser"
  tcp_ports = {

    sql_server   = { port = 1433, priority = 100 }
    sql_server1   = { port = 4001, priority = 101 }
    sql_server2   = { port = 4002, priority = 102 }
    sql_server3   = { port = 4003, priority = 103 }
    sql_server4   = { port = 4004, priority = 104 }
    sql_server5   = { port = 4005, priority = 105 }
    sql_server6   = { port = 4006, priority = 106 }
    sql_server7   = { port = 4007, priority = 107 }
    sql_server8   = { port = 4008, priority = 108 }
    sql_server9   = { port = 4009, priority = 109 }
  }


}

#It is assumed you already have a VNET and SUBNET created, if not you can uncomment line 54-50
# # Data sources for existing resources - VNET and SUBNET, Replace as needed
data "azurerm_virtual_network" "existing" {
  name                = "vnet-myhub-prod"
  resource_group_name = "snowflake_prod"
}

data "azurerm_subnet" "existing" {
  name                 = "default"
  virtual_network_name = data.azurerm_virtual_network.existing.name
  resource_group_name  = data.azurerm_virtual_network.existing.resource_group_name
}


/////////////////////CREATING RESOURCES ////////////////////////////

#Create resource group if needed, enable if needed, uses name on line 4
# resource "azurerm_resource_group" "sql_proxy" {
#   name = local.resource_group_name
#   location = local.location
#   tags = var.azure_tags
# }


# Public IP
resource "azurerm_public_ip" "sql_proxy" {
  name                = local.public_ip_name
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = var.azure_tags
}

# Network Security Group
resource "azurerm_network_security_group" "sql_proxy" {
  name                = local.nsg_name
  location            = local.location
  resource_group_name = local.resource_group_name
  tags = var.azure_tags

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-ALB"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

#Allowing other ports to the sql servers. 
resource "azurerm_network_security_rule" "allow_tcp_ports" {
  resource_group_name = local.resource_group_name
  network_security_group_name = azurerm_network_security_group.sql_proxy.name


  for_each = local.tcp_ports
 
  name                        = "allow-tcp-${each.value.port}"
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value.port
  source_address_prefix       = "*"
  destination_address_prefix  = "*"


}



# Network Interface
resource "azurerm_network_interface" "sql_proxy" {
  name                = local.nic_name
  location            = local.location
  resource_group_name = local.resource_group_name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.existing.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.sql_proxy.id
  }
  tags = var.azure_tags
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "sql_proxy" {
  network_interface_id      = azurerm_network_interface.sql_proxy.id
  network_security_group_id = azurerm_network_security_group.sql_proxy.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "sql_proxy" {
  name                = local.vm_name
  location            = local.location
  resource_group_name = local.resource_group_name
  size                = "Standard_D2s_v3"
  zone                = "1"
  tags = var.azure_tags
  
  admin_username                  = "azureuser"
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.sql_proxy.id,
  ]

  os_disk {
    name                 = local.vm_disk_name
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  patch_mode = "ImageDefault"
}


# Custom Script Extension to install and configure HAProxy
resource "azurerm_virtual_machine_extension" "haproxy_setup" {
  name                 = "haproxy-setup"
  virtual_machine_id   = azurerm_linux_virtual_machine.sql_proxy.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    script = base64encode(file("${path.module}/setup-haproxy.sh"))
  })

  depends_on = [
    azurerm_linux_virtual_machine.sql_proxy
  ]
}


# Load Balancer
resource "azurerm_lb" "sql_proxy" {
  name                = local.lb_name
  location            = local.location
  resource_group_name = local.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "sql-proxy-lb-fe"
    subnet_id                     = data.azurerm_subnet.existing.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = var.azure_tags
}


# Backend Address Pool
resource "azurerm_lb_backend_address_pool" "sql_proxy" {
  loadbalancer_id = azurerm_lb.sql_proxy.id
  name            = local.lb_backend_pool
}



resource "azurerm_lb_probe" "sql_proxy" {
  for_each = local.tcp_ports
 
  name            = "probe-${each.value.port}"
  loadbalancer_id = azurerm_lb.sql_proxy.id
  protocol        = "Tcp"
  port            = each.value.port
}



resource "azurerm_lb_rule" "sql_proxy" {
  for_each = local.tcp_ports
 
  name                           = "lb-rule-${each.value.port}"
  loadbalancer_id                = azurerm_lb.sql_proxy.id
  protocol                       = "Tcp"
  frontend_port                  = each.value.port
  backend_port                   = each.value.port
  frontend_ip_configuration_name = "sql-proxy-lb-fe"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.sql_proxy.id]
  probe_id                       = azurerm_lb_probe.sql_proxy[each.key].id
}
 



# Associate NIC with Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "sql_proxy" {
  network_interface_id    = azurerm_network_interface.sql_proxy.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.sql_proxy.id
}

# Private Link Service
resource "azurerm_private_link_service" "sql_proxy" {
  name                = local.pls_name
  location            = local.location
  resource_group_name = local.resource_group_name

  nat_ip_configuration {
    name      = "primary"
    primary   = true
    subnet_id = data.azurerm_subnet.existing.id
  }

  load_balancer_frontend_ip_configuration_ids = [
    azurerm_lb.sql_proxy.frontend_ip_configuration[0].id,
  ]
}
