# ==========================================================
# 1. CONFIGURATION TERRAFORM & PROVIDERS
# ==========================================================
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "local" {
    path = "atelier2.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = "ca5c57dd-3aab-4628-a78c-978830d03bbd"
}

# ==========================================================
# 2. RÉCUPÉRATION DES DONNÉES (DATA)
# ==========================================================
data "azurerm_resource_group" "rg_tp" {
  name = "rg-lpennaneach2023_cours-terraform"
}

output "info_rg" {
  value = {
    location = data.azurerm_resource_group.rg_tp.location
    user_tag = data.azurerm_resource_group.rg_tp.tags["user"]
  }
}

# ==========================================================
# 3. RÉSEAU (VNET, SUBNET, IP PUBLIQUE)
# ==========================================================
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-atelier2"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.rg_tp.location
  resource_group_name = data.azurerm_resource_group.rg_tp.name

  tags = {
    user = data.azurerm_resource_group.rg_tp.tags["user"]
  }
}

resource "azurerm_subnet" "internal" {
  name                 = "snet-internal"
  resource_group_name  = data.azurerm_resource_group.rg_tp.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "pip-vm-linux"
  location            = data.azurerm_resource_group.rg_tp.location
  resource_group_name = data.azurerm_resource_group.rg_tp.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "vm-lucas-${random_string.suffix.result}"

  # CORRECTIF : Ajout du tag exigé par la Policy Azure
  tags = {
    user = data.azurerm_resource_group.rg_tp.tags["user"]
  }
}

# ==========================================================
# 4. SÉCURITÉ (NSG)
# ==========================================================
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-ssh-allow"
  location            = data.azurerm_resource_group.rg_tp.location
  resource_group_name = data.azurerm_resource_group.rg_tp.name

  # CORRECTIF : Ajout du tag exigé par la Policy Azure
  tags = {
    user = data.azurerm_resource_group.rg_tp.tags["user"]
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ==========================================================
# 5. COMPUTE (NIC & VM LINUX)
# ==========================================================
resource "azurerm_network_interface" "nic" {
  name                = "nic-vm-linux"
  location            = data.azurerm_resource_group.rg_tp.location
  resource_group_name = data.azurerm_resource_group.rg_tp.name

  # CORRECTIF : Ajout du tag exigé par la Policy Azure
  tags = {
    user = data.azurerm_resource_group.rg_tp.tags["user"]
  }

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "link" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-linux-tp2"
  resource_group_name = data.azurerm_resource_group.rg_tp.name
  location            = data.azurerm_resource_group.rg_tp.location
  size                = "Standard_B1ls"
  admin_username      = "adminuser"
  computer_name       = "vm-linux-tp2"

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts" # Syntaxe corrigée
    sku       = "server"           # Syntaxe corrigée
    version   = "latest"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("C:/Users/lpennaneach2023/.ssh/id_rsa.pub")
  }

  tags = {
    user = data.azurerm_resource_group.rg_tp.tags["user"]
  }
}

# ==========================================================
# 6. BONUS ET OUTPUTS FINAUX
# ==========================================================
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

output "private_ip_vm" {
  value = azurerm_network_interface.nic.private_ip_address
}

output "ssh_command" {
  description = "Commande pour se connecter à la VM"
  value       = "ssh adminuser@${azurerm_public_ip.pip.fqdn}"
}
