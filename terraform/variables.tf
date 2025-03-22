# Variables générales
variable "resource_group_name" {
    description = "Nom du groupe de ressources Azure"
    type        = string
    default     = "vincentm-resource-group"
}   

variable "location" {
    description = "Région Azure où les ressources seront déployées"
    type        = string
    default     = "eastus"
}

variable "environment" {
    description = "Environnement (Dev, Test, Prod)"
    type        = string
    default     = "Dev"
}

# Variables pour la machine virtuelle
variable "vm_name" {
    description = "Nom de la machine virtuelle"
    type        = string
    default     = "VMvincentm"
}

variable "vm_size" {
    description = "Taille de la machine virtuelle"
    type        = string
    default     = "Standard_B1ls"
}

variable "admin_username" {
    description = "Nom d'utilisateur administrateur pour la VM"
    type        = string
    default     = "testadmin"
}

variable "ssh_key_path" {
    description = "Chemin vers la clé SSH publique"
    type        = string
    default     = "../id_rsa.pub"
}

# Variables pour le réseau
variable "vnet_address_space" {
    description = "Espace d'adressage du réseau virtuel"
    type        = list(string)
    default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefix" {
    description = "Préfixe d'adressage du sous-réseau"
    type        = list(string)
    default     = ["10.0.1.0/24"]
}

# Variables pour le stockage
variable "storage_account_name" {
    description = "Nom du compte de stockage Azure"
    type        = string
    default     = "vincentmstorageacc"
}

variable "storage_account_key" {
    description = "Clé d'accès du compte de stockage Azure"
    type        = string
    sensitive   = true
    # Ne pas définir de valeur par défaut pour les variables sensibles
}

variable "storage_container_name" {
    description = "Nom du conteneur de stockage"
    type        = string
    default     = "vincentmcontainer"
}

variable "storage_account_tier" {
    description = "Tier du compte de stockage"
    type        = string
    default     = "Standard"
}

variable "storage_replication_type" {
    description = "Type de réplication du stockage"
    type        = string
    default     = "LRS"
}

# Variables pour PostgreSQL
variable "postgresql_server_name" {
    description = "Nom du serveur PostgreSQL"
    type        = string
    default     = "vincentm-postgresql-server"
}

variable "postgresql_sku" {
    description = "SKU du serveur PostgreSQL"
    type        = string
    default     = "B_Gen5_1"
}

variable "postgresql_storage_mb" {
    description = "Stockage du serveur PostgreSQL en MB"
    type        = number
    default     = 5120
}

variable "postgresql_version" {
    description = "Version de PostgreSQL"
    type        = string
    default     = "11"
}

variable "postgresql_db_name" {
    description = "Nom de la base de données PostgreSQL"
    type        = string
    default     = "vincentmdb"
}

variable "postgresql_admin_username" {
    description = "Nom d'utilisateur administrateur PostgreSQL"
    type        = string
    default     = "psqladmin"
}

variable "postgresql_admin_password" {
    description = "Mot de passe administrateur PostgreSQL"
    type        = string
    sensitive   = true
    # Ne pas définir de valeur par défaut pour les variables sensibles
}