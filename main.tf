terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Définir un groupe de ressources
resource "azurerm_resource_group" "vincent" {
  name     = "vincent-resource-group"
  location = "eastus"
}

# Définir l'IP publique
resource "azurerm_public_ip" "vincent_ip" {
  name                = "vincentPublicIP"
  location            = azurerm_resource_group.vincent.location
  resource_group_name = azurerm_resource_group.vincent.name
  allocation_method   = "Static"

  tags = {
    environment = "Dev"
  }
}

# Créer un réseau virtuel
resource "azurerm_virtual_network" "vincent_vnet" {
  name                = "vincentVNet"
  location            = azurerm_resource_group.vincent.location
  resource_group_name = azurerm_resource_group.vincent.name
  address_space       = ["10.0.0.0/16"]  # Plage d'adresses IP du réseau

  tags = {
    environment = "Dev"
  }
}

# Créer un sous-réseau dans le réseau virtuel
resource "azurerm_subnet" "vincent_subnet" {
  name                 = "vincentSubnet"
  resource_group_name  = azurerm_resource_group.vincent.name
  virtual_network_name = azurerm_virtual_network.vincent_vnet.name
  address_prefixes     = ["10.0.1.0/24"]  # Plage d'adresses IP pour le sous-réseau
}

# Créer une carte réseau (Network Interface Card - NIC)
resource "azurerm_network_interface" "vincent_nic" {
  name                = "vincentNIC"
  location            = azurerm_resource_group.vincent.location
  resource_group_name = azurerm_resource_group.vincent.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vincent_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vincent_ip.id
  }
}

# Créer la clé publique SSH
resource "azurerm_ssh_public_key" "vincent_ssh_key" {
  name                = "vincentSSHKey"
  resource_group_name = azurerm_resource_group.vincent.name
  location            = azurerm_resource_group.vincent.location
  public_key          = file("./id_rsa.pub") # Chemin vers ta clé publique
}

# Créer la machine virtuelle
resource "azurerm_virtual_machine" "vincent_vm" {
  name                  = "VMVincent2"
  location              = azurerm_resource_group.vincent.location
  resource_group_name = azurerm_resource_group.vincent.name
  network_interface_ids = [azurerm_network_interface.vincent_nic.id]
  vm_size               = "Standard_B1ls" #Taille de la machine
  delete_os_disk_on_termination = true #Supprimer le disque à la suppression de la machine
  delete_data_disks_on_termination = true #Supprimer les disques de données à la suppression de la machine

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostnameVincent"
    admin_username = "testadmin"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/testadmin/.ssh/authorized_keys"
      key_data = azurerm_ssh_public_key.vincent_ssh_key.public_key
    }
  }

  tags = {
    environment = "Dev"
  }
}
