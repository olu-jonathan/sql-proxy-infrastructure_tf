#This configuration provisions and extra vm for high availability. Can be safely removed if not needed.

# Second Network Interface for HA
resource "azurerm_network_interface" "sql_proxy_ha" {
  name                = local.nic_ha_name
  location            = local.location
  resource_group_name = local.resource_group_name
  ip_forwarding_enabled = true
 
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.existing.id
    private_ip_address_allocation = "Dynamic"
  }
}
 
# Associate SAME NSG with HA NIC
resource "azurerm_network_interface_security_group_association" "sql_proxy_ha" {
  network_interface_id      = azurerm_network_interface.sql_proxy_ha.id
  network_security_group_id = azurerm_network_security_group.sql_proxy.id
}
 
# Second Virtual Machine for HA
resource "azurerm_linux_virtual_machine" "sql_proxy_ha" {
  name                = local.vm_ha_name
  location            = local.location
  resource_group_name = local.resource_group_name
  size                = "Standard_D2s_v3"
  zone                = "3"  # Different availability zone
  admin_username                  = "azureuser"
  admin_password                  = var.admin_password
  disable_password_authentication = false
 
  network_interface_ids = [
    azurerm_network_interface.sql_proxy_ha.id,
  ]
 
  os_disk {
    name                 = local.vm_ha_disk_name
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
 
# Custom Script Extension for HA VM
resource "azurerm_virtual_machine_extension" "haproxy_setup_ha" {
  name                 = "haproxy-setup-ha"
  virtual_machine_id   = azurerm_linux_virtual_machine.sql_proxy_ha.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"
 
  settings = jsonencode({
    script = base64encode(file("${path.module}/setup-haproxy.sh"))
  })
 
  depends_on = [
    azurerm_linux_virtual_machine.sql_proxy_ha
  ]
}
 
# Associate HA NIC with Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "sql_proxy_ha" {
  network_interface_id    = azurerm_network_interface.sql_proxy_ha.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.sql_proxy.id
}