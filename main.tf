# Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
#use_cli = alltrue(true)
  features {}
}

# Resource Group
resource "azurerm_resource_group" "proxy_rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "proxy_vnet" {
  name                = var.vnet_name
  location            = azurerm_resource_group.proxy_rg.location
  resource_group_name = azurerm_resource_group.proxy_rg.name
  address_space       = ["10.0.0.0/16"]
}

# Gateway Subnet (required exact name)
resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.proxy_rg.name
  virtual_network_name = azurerm_virtual_network.proxy_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# VM Subnet
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.proxy_rg.name
  virtual_network_name = azurerm_virtual_network.proxy_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Private Link NAT Subnet
resource "azurerm_subnet" "privatelink_nat_subnet" {
  name                 = "privatelink-nat-subnet"
  resource_group_name  = azurerm_resource_group.proxy_rg.name
  virtual_network_name = azurerm_virtual_network.proxy_vnet.name
  address_prefixes     = ["10.0.3.0/24"]

  # Disable private link service network policies
  private_link_service_network_policies_enabled = false
}

/////////////////////////////////////////////////////////


# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway_ip" {
  name                = "vpn-gateway-ip"
  location            = azurerm_resource_group.proxy_rg.location
  resource_group_name = azurerm_resource_group.proxy_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# VPN Gateway --- May take about 20 minutes to create.
resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = var.vpn_gateway_name
  location            = azurerm_resource_group.proxy_rg.location
  resource_group_name = azurerm_resource_group.proxy_rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }

  vpn_client_configuration {
    address_space = ["172.16.0.0/24"]
    
    vpn_client_protocols = ["OpenVPN", "IkeV2"]

    root_certificate {
      name = "P2SRootCert"
      
      # Get this from your exported P2SRootCert.cer file (base64 content without headers)
      public_cert_data = var.vpn_root_certificate_data
    }
  }
}



# Network Security Group for Proxy VM
resource "azurerm_network_security_group" "proxy_nsg" {
  name                = "sql-proxy-nsg"
  location            = azurerm_resource_group.proxy_rg.location
  resource_group_name = azurerm_resource_group.proxy_rg.name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSQL"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 1200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

# Public IP for Proxy VM
resource "azurerm_public_ip" "proxy_vm_ip" {
  name                = "sql-proxy-vm-ip"
  location            = azurerm_resource_group.proxy_rg.location
  resource_group_name = azurerm_resource_group.proxy_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}


# Network Interface for Proxy VM
resource "azurerm_network_interface" "proxy_nic" {
  name                = "sql-proxy-nic"
  location            = azurerm_resource_group.proxy_rg.location
  resource_group_name = azurerm_resource_group.proxy_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.proxy_vm_ip.id
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "proxy_nsg_association" {
  network_interface_id      = azurerm_network_interface.proxy_nic.id
  network_security_group_id = azurerm_network_security_group.proxy_nsg.id
}

# Proxy Virtual Machine
resource "azurerm_windows_virtual_machine" "proxy_vm" {
  name                = var.proxy_vm_name
  location            = azurerm_resource_group.proxy_rg.location
  resource_group_name = azurerm_resource_group.proxy_rg.name
  size                = "Standard_B2s"
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password

  network_interface_ids = [
    azurerm_network_interface.proxy_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
  vm_agent_platform_updates_enabled                      = true

  # Custom script to configure port forwarding
  # Note: This runs once at creation. You may need to manually configure after
}



# VM Extension to configure port forwarding
# Enable IP forwarding
#    Set-NetIPInterface -InterfaceAlias "Ethernet" -Forwarding Enabled

# Add port forwarding rule
#   netsh interface portproxy add v4tov4 listenport=1433 listenaddress=0.0.0.0 connectport=1433 connectaddress=172.16.201.2

# Verify the rule
#  netsh interface portproxy show all

# Add firewall rules on the VM to allow inbound traffic
# New-NetFirewallRule -DisplayName 'SQL Proxy Inbound' -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow



# Internal Load Balancer
resource "azurerm_lb" "internal_lb" {
  name                = var.load_balancer_name
  location            = azurerm_resource_group.proxy_rg.location
  resource_group_name = azurerm_resource_group.proxy_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "sql-frontend"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.100"
  }
}

# Load Balancer Backend Pool
resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name            = "sql-backend-pool"
  loadbalancer_id = azurerm_lb.internal_lb.id
}

# Associate VM NIC with Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "backend_association" {
  network_interface_id    = azurerm_network_interface.proxy_nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}

# Health Probe
resource "azurerm_lb_probe" "sql_health_probe" {
  name            = "sql-health-probe"
  loadbalancer_id = azurerm_lb.internal_lb.id
  protocol        = "Tcp"
  port            = 1433
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Load Balancing Rule
resource "azurerm_lb_rule" "sql_lb_rule" {
  name                           = "sql-lb-rule"
  loadbalancer_id                = azurerm_lb.internal_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 1433
  backend_port                   = 1433
  frontend_ip_configuration_name = "sql-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_pool.id]
  probe_id                       = azurerm_lb_probe.sql_health_probe.id
  enable_tcp_reset               = true
  idle_timeout_in_minutes        = 4
  #tcp_reset_enabled = true
}

/*
Run from a machine in the network to test connectivity:

Test-NetConnection -ComputerName 10.0.2.100 -Port 1433
 
sqlcmd -S tcp:10.0.2.100,1433 -U friend_user -P YourPassword -Q "SELECT @@VERSION" -C
*/ 



# Private Link Service
resource "azurerm_private_link_service" "sql_pls" {
  name                = var.private_link_service_name
  location            = azurerm_resource_group.proxy_rg.location
  resource_group_name = azurerm_resource_group.proxy_rg.name

  nat_ip_configuration {
    name      = "primary"
    primary   = true
    subnet_id = azurerm_subnet.privatelink_nat_subnet.id
  }

  load_balancer_frontend_ip_configuration_ids = [
    azurerm_lb.internal_lb.frontend_ip_configuration[0].id
  ]

  auto_approval_subscription_ids = []
  visibility_subscription_ids    = []
}



