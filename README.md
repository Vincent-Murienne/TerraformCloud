# TerraformCloud

## ✨ Déploiement Automatisé d'une Infrastructure Cloud avec Terraform
Ce projet automatise le déploiement d'une infrastructure sur **Azure** en utilisant **Terraform**. L'infrastructure inclut :
- Une **VM** hébergeant une application **Flask**
- Un **stockage cloud** pour les fichiers statiques
- Une **base de données PostgreSQL**

---

## 🔧 Prérequis
Avant de commencer, installez les outils suivants :
- **Terraform**
- **Azure CLI**
- **Git**
- Un **compte Azure** avec les permissions nécessaires

---

## 📚 Structure du Projet
```
.
├── main.tf                  # Ressources Terraform
├── provider.tf              # Configuration du provider Azure
├── variables.tf             # Variables Terraform
├── outputs.tf               # Sorties Terraform (IP publique, etc.)
├── terraform.tfvars         # Valeurs sensibles des variables
├── setup-app.sh             # Script de provisioning de la VM
├── app.py                   # Code de l'application Flask
├── README.md                # Ce fichier
└── rapport.md               # Rapport du projet
```

---

## ⭐ Installation & Utilisation
1. **Cloner le dépôt**
   ```sh
   git clone https://github.com/Vincent-Murienne/TerraformCloud
   cd TerraformCloud
   ```
2. **Configurer Azure CLI**
   ```sh
   az login
   az account set --subscription "VOTRE_ID_ABONNEMENT"
   ```
3. **Initialiser Terraform**
   ```sh
   terraform init
   ```
4. **Générer une paire de clés SSH**
   ```sh
   ssh-keygen -t rsa -b 4096 -f <votre_repertoire>\id_rsa "" (Pour la config de base, les clés doivent être générées à la racine du projet)
   ```
5. **Visualiser l'infrastructure**
   ```sh
   terraform plan
   ```
6. **Déployer l'infrastructure**
   ```sh
   terraform apply
   ```
7. **Accéder à l'application**
   - IP publique affichée dans les outputs Terraform
   - Accès : `http://<IP_PUBLIQUE>:5000`
8. **Gérer l'infrastructure**
   ```sh
   terraform refresh  # Mise à jour des ressources
   terraform destroy  # Suppression des ressources
   ```

---

## 📝 Ressources Créées
- **VM Azure** : Héberge Flask
- **Stockage Azure (Blob Storage)** : Fichiers statiques
- **Base de données PostgreSQL** : Données de l'application
- **Réseau et Sécurité** : NSG, VNet, sous-réseau

---

## 🔠 Variables Terraform
Les variables sont définies dans `variables.tf` et leurs valeurs dans `terraform.tfvars`.
**Exemples :**
```hcl
variable "resource_group_name" { default = "MonGroupe" }
variable "location" { default = "West Europe" }
variable "vm_size" { default = "Standard_B1s" }
```

---

## 🚀 Provisioning de la VM
Le script `setup-app.sh` configure la VM :
- Installation de **Python** et des dépendances Flask
- Configuration et démarrage de l'application Flask

---

## 🛠️ Gestion & Maintenance
- **Connexion SSH**
  ```sh
  ssh <user_name>@<ip_address>
  ```
  *Si besoin :*
  ```sh
  ssh -i <chemin_absolu_public_key> <user_name>@<ip_address>
  ```
- **Connexion à PostgreSQL**
  ```sh
  psql "host=<host>-postgresql-server.postgres.database.azure.com dbname=<db_name> user=<user_name>@<ressource>-postgresql-server password=<password> sslmode=require"
  ```
- **Gestion du back-end Flask**
  ```sh
  pkill -f "python3 app.py" # Arrêter le back
  sudo systemctl daemon-reload # Reload Daemon
  sudo systemctl restart flask-app.service # Restart le service
  ps aux | grep app.py  # Voir l'état du serveur
  sudo systemctl status flask-app.service # Voir l'état du service
  sudo journalctl -u flask-app.service # Voir les logs
  nohup python3 /opt/flaskapp/app.py > /var/log/flaskapp.log 2>&1 &

  ```

---

## ✅ TODOs
✉️ **Avant d'exécuter le projet, modifiez :**
- Renommer `terraform.tfvars.test` en `terraform.tfvars`
- Adapter les variables avec vos informations

---

## 💻 API CRUD Test
**Création des tables PostgreSQL :**
```sql
CREATE TABLE test_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50)
);
CREATE TABLE file_metadata (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    filesize BIGINT NOT NULL,
    filetype VARCHAR(50) NOT NULL,
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```
**Tests API avec `curl` :**
```sh
# Récupérer la liste des fichiers
curl http://<IP_PUBLIQUE>:5000/files

# Télécharger un fichier
curl http://<IP_PUBLIQUE>:5000/download/<filename> --output fichier_telecharge.txt

# Upload d'un fichier
curl -X POST -F "file=@<chemin/vers/fichier.txt>" http://<IP_PUBLIQUE>:5000/upload

# Supprimer un fichier
curl -X DELETE http://<IP_PUBLIQUE>:5000/delete/<filename>
```

---

## 🎨 Conclusion
Ce projet vous permet de déployer une infrastructure cloud **complète et automatisée** avec Terraform, Azure et Flask.

**💙 Bon déploiement !**

