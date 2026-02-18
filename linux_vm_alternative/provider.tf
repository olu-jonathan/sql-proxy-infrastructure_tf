terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.1"
    }
  }

backend "azurerm"{
  #replace with your own values
  resource_group_name = "SnowFlake_Prod"
  storage_account_name = "poctestingprod"
  container_name = "terraformstorage"
  key = "Snowflake-Sql-Server-Proxy/terraform.tfstate"
}
}

provider "azurerm" {
  features {}
}
