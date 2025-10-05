variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region (must match existing resources)"
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group containing the VNet/NSG"
  type        = string
}

variable "vnet_name" {
  description = "Existing virtual network name"
  type        = string
}

variable "subnet_name" {
  description = "Existing subnet name for the VMs (default if not overridden per-VM)"
  type        = string
}

variable "nsg_name" {
  description = "Existing NSG name to associate at NIC level (optional if NSG is on subnet)"
  type        = string
  default     = null
}

variable "admin_username" {
  description = "Local admin username for Windows"
  type        = string
}

variable "admin_password" {
  description = "Local admin password for Windows"
  type        = string
  sensitive   = true
}

variable "vm_specs" {
  description = <<EOT
Map of VMs to create. Key is a unique VM name; value object:
  - size               : VM size (e.g. Standard_D4s_v5)
  - subnet_name        : (optional) override default subnet_name
  - private_ip         : (optional) static IP; leave null for dynamic
  - zone               : (optional) AZ as string "1" | "2" | "3"
  - os_disk_size_gb    : (optional) OS disk size; default 127
  - data_disks         : (optional) list of objects [{size_gb=..., lun=..., sku="Premium_LRS"|...}]
EOT
  type = map(object({
    size            = string
    subnet_name     = optional(string)
    private_ip      = optional(string)
    zone            = optional(string)
    os_disk_size_gb = optional(number, 127)
    data_disks = optional(list(object({
      size_gb = number
      lun     = number
      sku     = optional(string, "Premium_LRS")
    })), [])
  }))
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
