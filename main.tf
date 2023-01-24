# Create a Windows VM 

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.40.0"
    }
  }
}

provider "azurerm" {
  features {}
}

#
# - Create a Resource Group
#

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags
}

#
# - Create a Virtual Network
#

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = [var.vnet_address_range]
  tags                = var.tags
}

#
# - Create a Subnet inside the virtual network
#

resource "azurerm_subnet" "web" {
  name                 = "${var.prefix}-web-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_address_range]
}


#
# - Create a Subnet for the Bastion Host
#

resource "azurerm_subnet" "bastion" {
  name                 = var.bastion_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.bastion_subnet_address_range]
}


#
# - Create a Bastion Host
#

resource "azurerm_bastion_host" "bastion-host" {
  name                = "${var.prefix}-bastion-host"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}



#
# - Create a Network Security Group
#

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-web-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags

  security_rule {
    name                       = "Allow_HTTPS_Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = 443
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"

  }


  security_rule {
    name                       = "Allow_GatewayManager_Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = 443
    destination_port_range     = "*"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"

  }

  security_rule {
    name                       = "Allow_BastionCommunication"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_ranges         = [8080, 5701]
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"

  }


  security_rule {
    name                       = "Allow_SshRdpOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_ranges         = [22, 3389]
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"

  }

  security_rule {
    name                       = "Allow_AzureCloudOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = 443
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "AZureCloud"

  }


  security_rule {
    name                       = "Allow_BastionHostCommunication"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_ranges         = [8080, 5701]
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"

  }

  security_rule {
    name                       = "Allow_GetSessionInformation"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = 80
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"

  }
}


#
# - Subnet-NSG Association
#

resource "azurerm_subnet_network_security_group_association" "subnet-nsg" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


#
# - Public IP For The Bastion Host
#

resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}-bastion-public-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = var.allocation_method[0]
  sku                 = "Standard"
  tags                = var.tags
}

#
# - Create a Network Interface Card for Virtual Machine
#

resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-winvm-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
  ip_configuration {
    name                          = "${var.prefix}-nic-ipconfig"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = var.allocation_method[1]
  }
}


#
# - Create a Windows 10 Virtual Machine
#

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "${var.prefix}-winvm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = var.virtual_machine_size
  computer_name         = var.computer_name
  admin_username        = var.admin_username
  admin_password        = var.admin_password

  os_disk {
    name                 = "${var.prefix}-winvm-os-disk"
    caching              = var.os_disk_caching
    storage_account_type = var.os_disk_storage_account_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
    version   = var.vm_image_version
  }

  tags = var.tags

}