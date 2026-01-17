variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "sql-proxy-rg"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "centralus"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "sql-proxy-vnet"
}

variable "vpn_gateway_name" {
  description = "Name of the VPN gateway"
  type        = string
  default     = "sql-vpn-gateway"
}

variable "proxy_vm_name" {
  description = "Name of the proxy VM"
  type        = string
  default     = "sql-proxy-vm"
}

variable "load_balancer_name" {
  description = "Name of the internal load balancer"
  type        = string
  default     = "sql-internal-lb"
}

variable "private_link_service_name" {
  description = "Name of the private link service"
  type        = string
  default     = "sql-private-link-service"
}

variable "vm_admin_username" {
  description = "Admin username for the proxy VM"
  type        = string
  default     = "seunjonathan"
}

variable "vm_admin_password" {
  description = "Admin password for the proxy VM"
  type        = string
  sensitive   = true
  default     = "Gre@tness123"
}

variable "vpn_root_certificate_data" {
  description = "Base64 encoded root certificate data for VPN (without BEGIN/END headers)"
  type        = string
  sensitive   = true

#update with your real value
  default     = "MIIC5zCCAc+gAwIBAgIQSyVtkdK4kLdKVeoizIjWbzANBgkq......................"
}

variable "laptop_vpn_ip" {
  description = "Your laptop's VPN IP address for port forwarding"
  type        = string
  default     = "172.16.0.2"
}
