# Azure SQL Proxy Infrastructure - Terraform

This Terraform configuration deploys a complete SQL proxy infrastructure in Azure with HAProxy load balancing.

## Architecture

- **VM**: Ubuntu 24.04 LTS with HAProxy installed
- **Public IP**: For external access
- **Network Security Group**: Allows SSH (22), your SQL ports (4001 - 4009), and Azure Load Balancer traffic
- **Internal Load Balancer**: Distributes traffic to the proxy VM
- **Private Link Service**: Enables private endpoint connectivity
- **HAProxy**: Proxies SQL traffic to backend server at 10.1.2.93:4001
- **Auto-Update**: VM Run Command automatically updates HAProxy config without SSH or downtime

## Prerequisites

- Azure CLI installed and authenticated
- Terraform >= 1.0
- Existing resources in Azure:
  - Resource Group: `Your_rg_group`
  - Virtual Network: `your-vnet`
  - Subnet: `default`

## Files

- `main.tf`: Main Terraform configuration
- `variables.tf`: Variable definitions
- `outputs.tf`: Output values
- `setup-haproxy.sh`: HAProxy installation script (runs automatically via VM extension)
- `terraform.tfvars`: Variables file

## Usage

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Configure Variables

**Important**: Add `terraform.tfvars` to `.gitignore` to avoid committing secrets.

Alternatively, set the password via environment variable:

```bash
export TF_VAR_admin_password='........'
```

### 3. Review the Plan and apply.

```bash
terraform plan
terraform apply
```


## Accessing the VM

```bash
# Get the public IP or use private IP if within VNET.
PUBLIC_IP=$(terraform output -raw public_ip_address)

# SSH to the VM
ssh azureuser@$PUBLIC_IP
```

## Monitoring HAProxy

### Check HAProxy Status

```bash
ssh azureuser@<public-ip>
sudo systemctl status haproxy
```

### View HAProxy Logs

```bash
sudo journalctl -u haproxy -f
```


## Testing the Proxy

From within your Azure network:

```bash
# Test connection to load balancer
telnet 10.135.3.15 4001

# Or use netcat
nc -zv 10.135.3.15 4001

#check how traffic flows
sudo tail -f /var/log/haproxy.log
```


### If HAProxy Didn't Install

The Custom Script Extension runs automatically after VM creation. If it failed:

```bash
# Check extension logs on the VM
sudo cat /var/log/azure/custom-script/handler.log

# Manually run the setup script
sudo bash /var/lib/waagent/custom-script/download/0/setup-haproxy.sh
```

Or re-run the extension:

```bash
# Force re-run via Terraform
terraform taint azurerm_virtual_machine_extension.haproxy_setup
terraform apply
```


## Enable Change Tracking on SQL Server

alter database Demo
set change_tracking = on
(change_retention = 2 days, AUTO_CLEANUP = ON);

alter table Demo.dbo.DimProduct
enable change_tracking;

select * from sys.change_tracking_tables;

## Azure CLI commands.
The infrastructure can also be created by using the following AZ commands as a baseline.

az network vnet update --resource-group rg-networks-prod-westus3-01 --name vnet-yours --address-prefixes 10.135.3.0/24 10.135.4.0/24
 
### Private Link Service subnet

az network vnet subnet create --resource-group snowflake_prod --vnet-name vnet-yours --name privatelink-subnet --address-prefix 10.135.4.0/27 --private-link-service-network-policies Disabled --route-table rt-datagovernance-prod-westus3-default-01
 
### VM subnet (optional)

az network vnet subnet create --resource-group snowflake_prod --vnet-name vnet-yours --name vm-proxy-subnet --address-prefix 10.135.4.32/27 --route-table rt-datagovernance-prod-westus3-default-01
 
az network public-ip create --resource-group snowflake_prod --name sql-proxy-pip --sku Standard --allocation-method Static --location westus3
 
az network nsg create --resource-group snowflake_prod --name sql-proxy-nsg --location westus3
 
az network nsg rule create --resource-group snowflake_prod --nsg-name sql-proxy-nsg --name Allow-SSH --priority 1000 --direction Inbound --access Allow --protocol Tcp --destination-port-ranges 22
 
az network nsg rule create --resource-group snowflake_prod --nsg-name sql-proxy-nsg  --name Allow-SQL --priority 1010 --direction Inbound --access Allow --protocol Tcp --destination-port-ranges 4001
 
az network nsg rule create --resource-group snowflake_prod --nsg-name sql-proxy-nsg --name Allow-ALB --priority 1020 --direction Inbound --access Allow --protocol Tcp --destination-port-ranges '*' --source-address-prefixes AzureLoadBalancer
 
az network nic create --resource-group snowflake_prod --name sql-proxy-nic --vnet-name vnet-yours --subnet default --network-security-group sql-proxy-nsg --public-ip-address sql-proxy-pip --ip-forwarding true --location westus3
 
az vm create --resource-group snowflake_prod --name snowsql-proxy-vm --location westus3 --zone 1 --size Standard_D2s_v3 --image Canonical:ubuntu-24_04-lts:server:latest --os-disk-name snowsql_proxy_vm_disk_467989a77a584dc588437a083d03655f --os-disk-size-gb 30 --os-disk-caching ReadWrite --storage-sku Premium_LRS --admin-username azureuser --authentication-type password --admin-password 'Yourp@ssword' --nics sql-proxy-nic --security-type TrustedLaunch  --patch-mode ImageDefault                                                               
 
az network lb create --resource-group snowflake_prod --name sql-proxy-lb --sku Standard --frontend-ip-name sql-proxy-lb-fe --vnet-name vnet-yours --subnet default --private-ip-address 10.135.3.15 --location westus3
 
az network lb probe create --resource-group snowflake_prod --lb-name sql-proxy-lb --name sql-proxy-health-probe --protocol tcp --port 4001
 
az network lb address-pool create --resource-group snowflake_prod --lb-name sql-proxy-lb --name sql-proxy-bepool
 
az network lb rule create --resource-group snowflake_prod --lb-name sql-proxy-lb --name sql-proxy-lb-rule --protocol Tcp --frontend-port 4001 --backend-port 4001 --frontend-ip-name sql-proxy-lb-fe --backend-pool-name sql-proxy-bepool --probe-name sql-proxy-health-probe
 
az network nic ip-config address-pool add --address-pool sql-proxy-bepool --ip-config-name ipconfig1 --nic-name sql-proxy-nic --resource-group snowflake_prod --lb-name sql-proxy-lb
 
az network private-link-service create --name sql-proxy-pls --resource-group snowflake_prod --vnet-name vnet-yours --subnet default --lb-name sql-proxy-lb --lb-frontend-ip-configs sql-proxy-lb-fe --location westus3
 