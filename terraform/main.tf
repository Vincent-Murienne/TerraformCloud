# Définir un groupe de ressources
resource "azurerm_resource_group" "vincentm" {
  name     = var.resource_group_name
  location = var.location
}

# Définir l'IP publique
resource "azurerm_public_ip" "vincentm_ip" {
  name                = "vincentmPublicIP"
  location            = azurerm_resource_group.vincentm.location
  resource_group_name = azurerm_resource_group.vincentm.name
  allocation_method   = "Static"

  tags = {
    environment = var.environment
  }
}

# Créer un réseau virtuel
resource "azurerm_virtual_network" "vincentm_vnet" {
  name                = "vincentmVNet"
  location            = azurerm_resource_group.vincentm.location
  resource_group_name = azurerm_resource_group.vincentm.name
  address_space       = var.vnet_address_space

  tags = {
    environment = var.environment
  }
}

# Créer un sous-réseau dans le réseau virtuel
resource "azurerm_subnet" "vincentm_subnet" {
  name                 = "vincentmSubnet"
  resource_group_name  = azurerm_resource_group.vincentm.name
  virtual_network_name = azurerm_virtual_network.vincentm_vnet.name
  address_prefixes     = var.subnet_address_prefix
}

# Créer une carte réseau (Network Interface Card - NIC)
resource "azurerm_network_interface" "vincentm_nic" {
  name                = "vincentmNIC"
  location            = azurerm_resource_group.vincentm.location
  resource_group_name = azurerm_resource_group.vincentm.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vincentm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vincentm_ip.id
  }
}

# Créer un groupe de sécurité réseau
resource "azurerm_network_security_group" "vincentm_nsg" {
  name                = "vincentmNSG"
  location            = azurerm_resource_group.vincentm.location
  resource_group_name = azurerm_resource_group.vincentm.name

  # Règle pour autoriser SSH
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

  # Règle pour autoriser HTTP (Flask)
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
  }
}

# Associer le NSG à la carte réseau
resource "azurerm_network_interface_security_group_association" "vincentm_nsg_association" {
  network_interface_id      = azurerm_network_interface.vincentm_nic.id
  network_security_group_id = azurerm_network_security_group.vincentm_nsg.id
}

# Créer la clé publique SSH
resource "azurerm_ssh_public_key" "vincentm_ssh_key" {
  name                = "vincentmSSHKey"
  resource_group_name = azurerm_resource_group.vincentm.name
  location            = azurerm_resource_group.vincentm.location
  public_key          = file(var.ssh_key_path)
}

# Créer la machine virtuelle
resource "azurerm_virtual_machine" "vincentm_vm" {
  name                  = var.vm_name
  location              = azurerm_resource_group.vincentm.location
  resource_group_name   = azurerm_resource_group.vincentm.name
  network_interface_ids = [azurerm_network_interface.vincentm_nic.id]
  vm_size               = var.vm_size
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

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
    computer_name  = "hostnamevincentm"
    admin_username = var.admin_username
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = azurerm_ssh_public_key.vincentm_ssh_key.public_key
    }
  }

  # Provisioner pour configurer la VM
  provisioner "file" {
    source      = "../src/app.py"  # Fichier local contenant l'application Flask
    destination = "/tmp/app.py"

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file("../id_rsa")  # Clé privée correspondant à la clé publique
      host        = azurerm_public_ip.vincentm_ip.ip_address
    }
  }

  provisioner "file" {
    source      = "../src/setup-app.sh"  # Script pour configurer l'application
    destination = "/tmp/setup-app.sh"

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file("../id_rsa")
      host        = azurerm_public_ip.vincentm_ip.ip_address
    }
  }

  provisioner "file" {
    source      = "./terraform.tfvars"  # Chemin relatif depuis le répertoire Terraform
    destination = "/tmp/terraform.tfvars"
    
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file("../id_rsa")
      host        = azurerm_public_ip.vincentm_ip.ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y dos2unix",
      "dos2unix /tmp/setup-app.sh",
      "chmod +x /tmp/setup-app.sh",
      "sudo /tmp/setup-app.sh"
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file("../id_rsa")
      host        = azurerm_public_ip.vincentm_ip.ip_address
    }
  }

  tags = {
    environment = var.environment
  }

  # Dépendances pour s'assurer que les ressources associées sont créées avant la VM
  depends_on = [
    azurerm_network_interface_security_group_association.vincentm_nsg_association,
    azurerm_postgresql_server.vincentm_postgresql,
    azurerm_storage_account.vincentm_storage
  ]
}

# Créer un compte de stockage Azure
resource "azurerm_storage_account" "vincentm_storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.vincentm.name
  location                 = azurerm_resource_group.vincentm.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type

  tags = {
    environment = var.environment
  }
}

# Créer un conteneur de stockage
resource "azurerm_storage_container" "vincentm_container" {
  name                  = var.storage_container_name
  storage_account_name  = azurerm_storage_account.vincentm_storage.name
  container_access_type = "private"
}

# Créer un blob de stockage
resource "azurerm_storage_blob" "vincentm_blob" {
  name                   = "example.txt"
  storage_account_name   = azurerm_storage_account.vincentm_storage.name
  storage_container_name = azurerm_storage_container.vincentm_container.name
  type                   = "Block"
  source                 = "../src/example.txt"
}

# Créer un serveur PostgreSQL
resource "azurerm_postgresql_server" "vincentm_postgresql" {
  name                = var.postgresql_server_name
  location            = azurerm_resource_group.vincentm.location
  resource_group_name = azurerm_resource_group.vincentm.name

  sku_name = var.postgresql_sku

  storage_mb                   = var.postgresql_storage_mb
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  administrator_login          = var.postgresql_admin_username
  administrator_login_password = var.postgresql_admin_password

  version                      = var.postgresql_version
  ssl_enforcement_enabled      = true
}

# Créer une base de données PostgreSQL
resource "azurerm_postgresql_database" "vincentm_postgresql_db" {
  name                = var.postgresql_db_name
  resource_group_name = azurerm_resource_group.vincentm.name
  server_name         = azurerm_postgresql_server.vincentm_postgresql.name
  charset             = "UTF8"
  collation           = "en_US.UTF8"
}

# Configurer une règle de pare-feu pour autoriser l'accès à la base de données
resource "azurerm_postgresql_firewall_rule" "vincentm_postgresql_firewall" {
  name                = "allow-all-ips"
  resource_group_name = azurerm_resource_group.vincentm.name
  server_name         = azurerm_postgresql_server.vincentm_postgresql.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}