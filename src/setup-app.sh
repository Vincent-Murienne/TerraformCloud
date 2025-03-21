#!/bin/bash

# Mettre à jour les paquets et installer les dépendances
apt-get update -y
apt-get install -y python3 python3-pip postgresql-client libpq-dev

# Installer les modules Python nécessaires
pip3 install flask psycopg2-binary azure-storage-blob

# Créer le répertoire de l'application Flask
mkdir -p /opt/flaskapp
cp /tmp/app.py /opt/flaskapp/

# Créer un service systemd pour l'application Flask
cat > /etc/systemd/system/flask-app.service << EOF
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
EOF

# Activer et démarrer le service
systemctl daemon-reload
systemctl enable flask-app.service
systemctl start flask-app.service

# Vérifier le statut du service
systemctl status flask-app.service

# Créer un fichier de log
touch /var/log/flaskapp.log
chmod 666 /var/log/flaskapp.log

echo "Installation de l'application Flask terminée"