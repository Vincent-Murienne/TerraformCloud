from flask import Flask, request, jsonify
import psycopg2
import logging
import re
from azure.storage.blob import BlobServiceClient, generate_blob_sas, BlobSasPermissions
from datetime import datetime, timedelta

# Configurer la journalisation
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

app = Flask(__name__)

def parse_terraform_tfvars(file_path):
    """Parse terraform.tfvars file and return a dictionary of variables"""
    variables = {}
    
    with open(file_path, 'r') as f:
        content = f.read()
        
    # Pattern to match variable assignments including strings, lists, and numbers
    pattern = r'([a-zA-Z0-9_]+)\s*=\s*(?:"([^"]*)"|(\[[^\]]*\])|([a-zA-Z0-9._/+=-]+))'
    matches = re.findall(pattern, content)
    
    for match in matches:
        var_name, string_value, list_value, other_value = match
        
        # Determine which value type was matched
        if string_value:
            variables[var_name] = string_value
        elif list_value:
            # Simple list parsing (for more complex lists, you might need a proper parser)
            # This handles basic list formats like ["10.0.0.0/16"]
            clean_list = list_value.replace('[', '').replace(']', '').replace('"', '')
            list_items = [item.strip() for item in clean_list.split(',')]
            variables[var_name] = list_items
        elif other_value:
            # Try to convert to int if possible, otherwise keep as string
            try:
                if '.' in other_value:
                    variables[var_name] = float(other_value)
                else:
                    variables[var_name] = int(other_value)
            except ValueError:
                variables[var_name] = other_value
                
    return variables

# Charger les variables depuis terraform.tfvars
try:
    variables = parse_terraform_tfvars("./terraform.tfvars")
    logger.info(f"Variables chargées depuis terraform.tfvars: {', '.join(variables.keys())}")
except Exception as e:
    logger.error(f"Erreur lors du chargement des variables: {e}")
    variables = {}

# Récupération des variables
STORAGE_ACCOUNT_NAME = variables.get("storage_account_name", "vincentmstorageacc")
STORAGE_ACCOUNT_KEY = variables.get("storage_account_key", "")
CONTAINER_NAME = variables.get("storage_container_name", "vincentmcontainer")

# Connexion à Azure Blob Storage
logger.info(f"Connexion à Azure Blob Storage: {STORAGE_ACCOUNT_NAME}")
blob_service_client = BlobServiceClient(
    account_url=f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net", 
    credential=STORAGE_ACCOUNT_KEY
)
container_client = blob_service_client.get_container_client(CONTAINER_NAME)

# Connexion à la base de données PostgreSQL
def get_db_connection():
    try:
        server_name = variables.get("postgresql_server_name", "")
        db_name = variables.get("postgresql_db_name", "")
        username = variables.get("postgresql_admin_username", "")
        password = variables.get("postgresql_admin_password", "")
        
        conn = psycopg2.connect(
            host=f"{server_name}.postgres.database.azure.com",
            database=db_name,
            user=f"{username}@{server_name}",
            password=password,
            sslmode="require"
        )
        return conn
    except Exception as e:
        logger.error(f"Erreur de connexion à la base de données: {e}")
        raise

# Fonction pour initialiser la base de données
def initialize_database():
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # Créer la table file_metadata si elle n'existe pas
        cur.execute("""
            CREATE TABLE IF NOT EXISTS file_metadata (
                id SERIAL PRIMARY KEY,
                filename VARCHAR(255) NOT NULL,
                filesize BIGINT NOT NULL,
                filetype VARCHAR(50) NOT NULL,
                upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)

        # Créer la table test_table si elle n'existe pas
        cur.execute("""
            CREATE TABLE IF NOT EXISTS test_table (
                id SERIAL PRIMARY KEY,
                name VARCHAR(50)
            );
        """)

        conn.commit()
        cur.close()
        conn.close()
        logger.info("Base de données initialisée avec succès.")
    except Exception as e:
        logger.error(f"Erreur lors de l'initialisation de la base de données: {e}")

# Appeler la fonction d'initialisation au démarrage de l'application
initialize_database()

# Générer une URL pour download un fichier
def generate_sas_url(blob_name):
    sas_token = generate_blob_sas(
        account_name=STORAGE_ACCOUNT_NAME,
        container_name=CONTAINER_NAME,
        blob_name=blob_name,
        account_key=STORAGE_ACCOUNT_KEY,
        permission=BlobSasPermissions(read=True),
        expiry=datetime.utcnow() + timedelta(hours=1)
    )
    return f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net/{CONTAINER_NAME}/{blob_name}?{sas_token}"

# Route pour télécharger un fichier via une URL SAS
@app.route('/download/<filename>', methods=['GET'])
def download_file(filename):
    try:
        sas_url = generate_sas_url(filename)
        return jsonify({"url": sas_url}), 200
    except Exception as e:
        logger.error(f"Erreur lors de la génération de l'URL SAS: {e}")
        return jsonify({"error": str(e)}), 500

# Route pour lister les fichiers présent dans le stockage cloud
@app.route('/files', methods=['GET'])
def list_files():
    try:
        blobs = container_client.list_blobs()
        files = [blob.name for blob in blobs]
        return jsonify({"files": files}), 200
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des fichiers: {e}")
        return jsonify({"error": str(e)}), 500

# Route pour téléverser un fichier dans le stockage cloud
@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({"error": "Aucun fichier fourni"}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "Nom de fichier vide"}), 400

    try:
        # Téléverser le fichier dans Azure Blob Storage
        blob_client = container_client.get_blob_client(file.filename)
        blob_client.upload_blob(file)

        # Enregistrer les métadonnées dans la base de données
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            'INSERT INTO file_metadata (filename, filesize, filetype) VALUES (%s, %s, %s) RETURNING id',
            (file.filename, file.content_length, file.content_type)
        )
        file_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"message": f"Fichier {file.filename} téléversé avec succès", "file_id": file_id}), 200
    except Exception as e:
        logger.error(f"Erreur lors du téléversement du fichier: {e}")
        return jsonify({"error": str(e)}), 500

# Route pour supprimer un fichier présent dans le stockage cloud
@app.route('/delete/<filename>', methods=['DELETE'])
def delete_file(filename):
    try:
        blob_client = container_client.get_blob_client(filename)
        blob_client.delete_blob()

        # Supprimer les métadonnées du fichier de la base de données
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('DELETE FROM file_metadata WHERE filename = %s', (filename,))
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"message": f"Fichier {filename} supprimé avec succès"}), 200
    except Exception as e:
        logger.error(f"Erreur lors de la suppression du fichier: {e}")
        return jsonify({"error": str(e)}), 500
    

## --------------------------------------------------------------------------------

## CRUD Base de données

# Route pour lire les metadonnées persistées (grâce à la route /upload)
@app.route('/file_metadata')
def file_metada():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT * FROM file_metadata')
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return str(rows)
    except Exception as e:
        logger.error(f"Erreur lors de l'exécution de la requête: {e}")
        return "Une erreur s'est produite", 500

# Route principale
@app.route('/')
def hello_world():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT * FROM test_table')
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return str(rows)
    except Exception as e:
        logger.error(f"Erreur lors de l'exécution de la requête: {e}")
        return "Une erreur s'est produite", 500

# Route pour lire un enregistrement spécifique
@app.route('/read/<int:id>', methods=['GET'])
def read_record(id):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT * FROM test_table WHERE id = %s', (id,))
        record = cur.fetchone()
        cur.close()
        conn.close()

        if record:
            return jsonify({"id": record[0], "name": record[1]}), 200
        else:
            return jsonify({"error": "Enregistrement non trouvé"}), 404
    except Exception as e:
        logger.error(f"Erreur lors de la lecture de l'enregistrement: {e}")
        return jsonify({"error": str(e)}), 500
    
# Route pour créer un enregistrement dans la table test_table
@app.route('/create', methods=['POST'])
def create_record():
    data = request.json
    name = data.get('name')

    if not name:
        return jsonify({"error": "Le champ 'name' est requis"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('INSERT INTO test_table (name) VALUES (%s) RETURNING id', (name,))
        record_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"message": "Enregistrement créé", "id": record_id}), 201
    except Exception as e:
        logger.error(f"Erreur lors de la création de l'enregistrement: {e}")
        return jsonify({"error": str(e)}), 500

# Route pour mettre à jour un enregistrement
@app.route('/update/<int:id>', methods=['PUT'])
def update_record(id):
    data = request.json
    name = data.get('name')

    if not name:
        return jsonify({"error": "Le champ 'name' est requis"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('UPDATE test_table SET name = %s WHERE id = %s', (name, id))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"message": "Enregistrement mis à jour"}), 200
    except Exception as e:
        logger.error(f"Erreur lors de la mise à jour de l'enregistrement: {e}")
        return jsonify({"error": str(e)}), 500

# Route pour supprimer un enregistrement
@app.route('/delete_record/<int:id>', methods=['DELETE'])
def delete_record(id):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('DELETE FROM test_table WHERE id = %s', (id,))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"message": "Enregistrement supprimé"}), 200
    except Exception as e:
        logger.error(f"Erreur lors de la suppression de l'enregistrement: {e}")
        return jsonify({"error": str(e)}), 500

# Fonction principale
def main():
    logger.info(f"Application démarrée")
    logger.info(f"Utilisation du compte de stockage: {STORAGE_ACCOUNT_NAME}")
    logger.info(f"Utilisation du conteneur: {CONTAINER_NAME}")
    
    # Test de la connexion à la base de données
    try:
        conn = get_db_connection()
        logger.info("Connexion à la base de données réussie")
        conn.close()
    except Exception as e:
        logger.error(f"Échec de la connexion à la base de données: {e}")
    
    app.run(host='0.0.0.0', port=5000, debug=True)

if __name__ == "__main__":
    main()