variable "admin_password" {
  description = "Administrator password for the VM"
  type        = string
  sensitive   = true
}


variable "azure_tags" {
  type        = map(any)
  default = {
    createdBy = "Your name"
  }
}