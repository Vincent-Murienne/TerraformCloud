#!/bin/bash

# Mettre à jour les paquets et installer les dépendances
echo "Mise à jour des paquets et installation des dépendances..."
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip postgresql-client libpq-dev

# Installer le client PostgreSQL (au cas où il n'est pas déjà installé)
echo "Installation de postgresql-client..."
sudo apt install -y postgresql-client

# Installer les modules Python nécessaires
echo "Installation des modules Python..."
sudo pip3 install psycopg2-binary flask azure-storage-blob

# Créer le répertoire de l'application Flask
echo "Création du répertoire /opt/flaskapp..."
sudo mkdir -p /opt/flaskapp

# Copier l'application Flask dans le répertoire
if [ -f "/tmp/app.py" ]; then
    echo "Copie de app.py dans /opt/flaskapp..."
    sudo cp /tmp/app.py /opt/flaskapp/
else
    echo "Erreur : Le fichier /tmp/app.py n'existe pas."
    exit 1
fi

# Copier le fichier terraform.tfvars
if [ -f "/tmp/terraform.tfvars" ]; then
    echo "Copie de terraform.tfvars dans /opt/flaskapp..."
    sudo cp /tmp/terraform.tfvars /opt/flaskapp/
else
    echo "Attention : Le fichier /tmp/terraform.tfvars n'existe pas."
fi

# Vérifier que le fichier app.py est présent
if [ ! -f "/opt/flaskapp/app.py" ]; then
    echo "Erreur : Le fichier /opt/flaskapp/app.py n'a pas été copié correctement."
    exit 1
fi

# Créer un service systemd pour l'application Flask
echo "Création du service systemd..."
sudo bash -c 'cat > /etc/systemd/system/flask-app.service << EOF
[Unit]
Description=Flask Application Service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/flaskapp
ExecStart=/usr/bin/python3 /opt/flaskapp/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

# Recharger systemd pour prendre en compte le nouveau service
echo "Rechargement de systemd..."
sudo systemctl daemon-reload

# Activer et démarrer le service
echo "Activation et démarrage du service flask-app..."
sudo systemctl enable flask-app.service
sudo systemctl start flask-app.service

# Vérifier le statut du service
echo "Vérification du statut du service..."
sudo systemctl status flask-app.service

# Créer un fichier de log
echo "Création du fichier de log /var/log/flaskapp.log..."
sudo touch /var/log/flaskapp.log
sudo chmod 666 /var/log/flaskapp.log

echo "Installation de l'application Flask terminée avec succès."