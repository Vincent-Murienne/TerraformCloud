# TerraformCloud

## Déploiement Automatisé d’une Infrastructure Cloud avec Terraform
## Ce projet vise à automatiser le déploiement d'une infrastructure cloud complète sur Azure en utilisant Terraform. 
## L'infrastructure inclut une machine virtuelle (VM) hébergeant une application Flask, un stockage cloud pour les fichiers statiques, et une base de données PostgreSQL. 
## Le processus est entièrement automatisé via Terraform, y compris la configuration de la VM et le déploiement de l'application.


# Prérequis
Avant de commencer, assurez-vous d'avoir les outils suivants installés :
    - Terraform
    - Azure CLI 
    - Git 
    - Un compte Azure avec les permissions nécessaires pour créer des ressources.

# Structure du Projet
Le projet est organisé comme suit :

.
├── main.tf                  # Fichier principal Terraform pour les ressources
├── provider.tf              # Configuration du provider Azure
├── variables.tf             # Déclaration des variables Terraform
├── outputs.tf               # Sorties Terraform (IP publique, etc.)
├── terraform.tfvars         # Valeurs des variables sensibles
├── setup-app.sh             # Script de provisioning pour la VM
├── app.py                   # Code de l'application Flask
├── README.md                # Ce fichier
└── rapport.md               # Rapport détaillé du projet

## Installation et Utilisation

# Cloner le dépôt :
    - git clone https://github.com/Vincent-Murienne/TerraformCloud
    - cd TerraformCloud

# Configurer Azure CLI :
    - az login
    - az account set --subscription "VOTRE_ID_ABONNEMENT"

# Initialiser Terraform :
    - terraform init

# Visualiser l'infrastructure :
    - terraform plan

# Déployer l'infrastructure :
    - terraform apply

# Refresh :
    - terraform refresh

# Supprimer l'infrastructure :
    - terraform destroy


## Accéder à l'application :
L'IP publique de la VM sera affichée dans les outputs Terraform.
Accédez à l'application Flask via http://<IP_PUBLIQUE>:5000.

## Déploiement de l'Infrastructure

# Ressources Créées
    - Machine Virtuelle (VM) : Héberge l'application Flask.
    - Stockage Azure (Blob Storage) : Pour stocker les fichiers statiques.
    - Base de Données PostgreSQL : Pour stocker les données de l'application.
    - Réseau et Sécurité : Groupe de sécurité réseau (NSG), réseau virtuel (VNet), et sous-réseau.

# Variables Terraform
Les variables sont définies dans variables.tf et leurs valeurs dans terraform.tfvars. Exemples :
    - resource_group_name : Nom du groupe de ressources Azure.
    - location : Région Azure (ex: West Europe).
    - vm_size : Taille de la VM (ex: Standard_B1s).

# Provisioning de la VM
Le script setup-app.sh est utilisé pour configurer la VM après son déploiement. Il effectue les tâches suivantes :
    - Installation de Python et des dépendances Flask.
    - Configuration de l'application Flask en tant que service.
    - Démarrage de l'application.


# Déploiement du Backend
L'application Flask est déployée sur la VM via les provisioners Terraform. 
Le fichier app.py contient le code de l'application, et le script setup-app.sh installe et démarre l'application.

# Résultat Final
Une fois le déploiement terminé, vous devriez avoir :
    - Une VM fonctionnelle avec l'application Flask accessible via l'IP publique.
    - Un stockage Azure configuré pour stocker les fichiers statiques.
    - Une base de données PostgreSQL opérationnelle.


# TODOS :
Après récupération du projet, veuillez modifier :
    - Le nom du fichier terraform.tfvars.test -> terraform.tfvars 
    - Les valeurs des variables par vos informations

Script test pour la vérification du bon fonctionnement du CRUD
CREATE TABLE test_table (id SERIAL PRIMARY KEY, name VARCHAR(50));

Script création de la table file_metadata (table qui récupère tous les fichiers uploadé dans le stockage cloud)

CREATE TABLE file_metadata (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    filesize BIGINT NOT NULL,
    filetype VARCHAR(50) NOT NULL,
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

Exécuter les requêtes API soit via Postman ou commandes CMD :
Dans le cmd :
    - curl http://<votre-ip-publique>:5000/files #GET : Récupère l'ensemble des fichiers présent dans le stockage cloud
    - curl http://<votre-ip-publique>:5000/download/<filename> --output fichier_telecharge.txt  #GET : Permet de télécharger localement un fichier présent dans le stockage cloud
    - curl -X POST -F "file=@/chemin/vers/fichier.txt" http://<votre-ip-publique>:5000/upload  #POST : Upload d'un fichier ---> Dans le stockage cloud
    - curl -X DELETE http://<votre-ip-publique>:5000/delete/<filename> # DELETE : Permet de supprimer uin fichier du stockage cloud

Se connecter à la VM par ssh :
    - ssh <user_name>@<ip_address>
    
En cas de problème de connexion à la VM, vous pouvez vous connecter grâce à cette commande :
    - ssh -i <chemin_absolu_public_key> <user_name>@<ip_adress>

Connexion à la BDD :
    - psql "host=<host_name>-postgresql-server.postgres.database.azure.com dbname=<db_name> user=<user_name>@<ressource_name_postgre>-postgresql-server password=<password> sslmode=require"

Arrêter et redémarrer le back-end flask :
	pkill -f "python3 app.py"
	nohup python3 /opt/flaskapp/app.py > /var/log/flaskapp.log 2>&1 &

	Voir l'état du server : ps aux | grep app.py

En cas de problème d'installation automatique des dépendances, voir le script "setup-app.sh" et exécuter manuellement les dépendances manquantes.