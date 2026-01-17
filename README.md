# SQL Server Private Link Infrastructure

This Terraform configuration creates the complete Azure infrastructure for exposing on-premises SQL Server via Azure Private Link.

## Architecture
![spcs azure](https://github.com/user-attachments/assets/2e8a00b8-fa45-458e-b352-3f366996d241)


## Prerequisites

1. **Terraform installed** (version >= 1.0)
2. **Azure CLI installed** and logged in (`az login`)
3. **VPN Root Certificate** created and exported
4. **On Prem SQL Server** on with TCP/IP enabled on port 1433

## File Structure

- `main.tf` - Main infrastructure configuration
- `variables.tf` - Variable definitions

## Getting Your VPN Certificate Data

1. Open your exported `P2SRootCert.cer` file in Notepad
2. Copy everything between `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----`
3. Remove all line breaks to create one continuous string
4. Paste into `terraform.tfvars` as `vpn_root_certificate_data`

## Usage

### Initial Deployment
```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration (takes 30-45 minutes due to VPN Gateway)
terraform apply
```


## Post-Deployment Manual Steps

After Terraform completes, you need to:

### 1. Configure Port Forwarding on Proxy VM

RDP to the proxy VM and run the command shown in the `port_forwarding_command` output:
```powershell

# Enable IP forwarding
    Set-NetIPInterface -InterfaceAlias "Ethernet" -Forwarding Enabled

# Add port forwarding rule
   netsh interface portproxy add v4tov4 listenport=1433 listenaddress=0.0.0.0 connectport=1433 connectaddress=172.16.201.2

# Verify the rule
  netsh interface portproxy show all

# Add firewall rules on the VM to allow inbound traffic
 New-NetFirewallRule -DisplayName 'SQL Proxy Inbound' -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow

```

### 2. Download and Install VPN Client

1. Go to VPN Gateway in Azure Portal
2. Click "Point-to-site configuration"
3. Download VPN client
4. Install Azure VPN Client
5. Import the configuration
6. Connect

### 3. Configure Snowflake


### 4. Approve Private Endpoint Connection

After Snowflake provisions the endpoint:
1. Go to Private Link Service in Azure Portal
2. Approve the pending connection


## Important Notes

- VPN Gateway takes 15-25 minutes to deploy
- The Private Link Service alias will be different each time
- Update Snowflake configuration with the new alias after each deployment


## Troubleshooting

If connections fail:
1. Check VPN is connected (`ipconfig` should show 172.16.201.x)
2. Verify port forwarding on VM
3. Check Health probes
4. Check Load Balancer health probe status
5. Review NSG rules
6. Check firewall logs on VM
