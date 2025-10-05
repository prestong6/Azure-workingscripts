# --- Data lookups for existing infra ---
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Default subnet (used if per-VM override not set)
data "azurerm_subnet" "default" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

# Optional existing NSG (for NIC-level association)
data "azurerm_network_security_group" "nsg" {
  count               = var.nsg_name == null ? 0 : 1
  name                = var.nsg_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# If a VM specifies an alternate subnet, look it up
# Build a set of all subnets referenced (default + any per-VM overrides)
locals {
  all_subnet_names = toset(compact(
    concat([var.subnet_name], [for k, v in var.vm_specs : try(v.subnet_name, null)])
  ))
}

data "azurerm_subnet" "subnet_map" {
  for_each             = { for s in local.all_subnet_names : s => s }
  name                 = each.value
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

# --- NICs ---
resource "azurerm_network_interface" "nic" {
  for_each            = var.vm_specs
  name                = "${each.key}-nic01"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = try(each.value.private_ip, null) == null ? "Dynamic" : "Static"
    private_ip_address            = try(each.value.private_ip, null)
    subnet_id                     = data.azurerm_subnet.subnet_map[try(each.value.subnet_name, var.subnet_name)].id
  }
}

# Optional NIC-NSG association (use only if subnet does NOT already enforce NSG)
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  for_each                  = var.nsg_name == null ? {} : azurerm_network_interface.nic
  network_interface_id      = each.value.id
  network_security_group_id = data.azurerm_network_security_group.nsg[0].id
}

# --- Windows VMs ---
resource "azurerm_windows_virtual_machine" "vm" {
  for_each            = var.vm_specs
  name                = each.key
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  size                = each.value.size
  zone                = try(each.value.zone, null)

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [azurerm_network_interface.nic[each.key].id]

  # OS Disk
  os_disk {
    name                 = "${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = try(each.value.os_disk_size_gb, 127)
  }

  # Source image: Windows Server 2019 Datacenter (latest)
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  # Managed boot diagnostics (no storage account required)
  boot_diagnostics {}

  # Enable encryption at host where supported (optional; safe default off)
  encryption_at_host_enabled = false

  # Timeouts (helpful for large batches)
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  tags = var.tags
}

# Optional data disks per VM
resource "azurerm_managed_disk" "data" {
  for_each            = { for pair in flatten([
                           for vm_name, spec in var.vm_specs :
                           [for d in try(spec.data_disks, []) :
                             { key = "${vm_name}-${d.lun}", vm = vm_name, size = d.size_gb, sku = try(d.sku, "Premium_LRS"), lun = d.lun }
                           ]
                         ]) : pair.key => pair }
  name                 = "${each.key}-md"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  storage_account_type = each.value.sku
  create_option        = "Empty"
  disk_size_gb         = each.value.size
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach" {
  for_each           = azurerm_managed_disk.data
  managed_disk_id    = each.value.id
  virtual_machine_id = azurerm_windows_virtual_machine.vm[split("-", each.key)[0]].id
  lun                = each.value.lun
  caching            = "ReadOnly"
}
