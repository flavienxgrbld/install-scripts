#!/usr/bin/env bash

# Script d'installation de Mattermost sur tous les OS supportés

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/install_common.sh"

ensure_root
detect_os
detect_package_manager

info "Détection de l'OS : ${OS_NAME} ${OS_VERSION_ID}"
if ! is_debian_family && ! is_redhat_family && ! is_suse_family && ! is_pacman_family; then
    error_exit "Ce script prend en charge Debian/Ubuntu/Raspbian, RHEL/CentOS/Oracle/Alma/Rocky/AmazonLinux, SUSE et Arch Linux"
fi

# Variables de configuration
MATTERMOST_VERSION="latest"
MATTERMOST_USER="mattermost"
MATTERMOST_HOME="/opt/mattermost"
MATTERMOST_DATA_DIR="/opt/mattermost/data"
MATTERMOST_DB_NAME="mattermost"
MATTERMOST_DB_USER="mattermost"

echo "=== Mise à jour du système ==="
pkg_update
pkg_upgrade

# Installation de la base de données
echo "=== Installation de PostgreSQL ==="
case "$PKG_MANAGER" in
    apt)
        pkg_install postgresql postgresql-contrib
        ;;
    dnf|yum)
        pkg_install postgresql-server postgresql-contrib
        postgresql-setup initdb 2>/dev/null || postgresql-setup --initdb
        ;;
    zypper)
        pkg_install postgresql-server postgresql-contrib
        ;;
    pacman)
        pkg_install postgresql
        sudo -u postgres initdb -D /var/lib/postgres/data
        ;;
esac

# Démarrage et activation de PostgreSQL
systemctl enable postgresql
systemctl start postgresql

# Installation de Nginx
echo "=== Installation de Nginx ==="
install_webserver "nginx"

# Création de l'utilisateur Mattermost
echo "=== Création de l'utilisateur Mattermost ==="
if ! id "$MATTERMOST_USER" >/dev/null 2>&1; then
    useradd -r -s /bin/bash -m -d "$MATTERMOST_HOME" -c "Mattermost Service" "$MATTERMOST_USER"
fi

# Configuration de la base de données PostgreSQL
echo "=== Configuration de PostgreSQL ==="
read -sp "Entrez le mot de passe pour l'utilisateur Mattermost (DB): " MATTERMOST_DB_PASS
echo

# Création de l'utilisateur et de la base de données PostgreSQL
sudo -u postgres psql <<EOSQL
CREATE DATABASE ${MATTERMOST_DB_NAME};
CREATE USER ${MATTERMOST_DB_USER} WITH PASSWORD '${MATTERMOST_DB_PASS}';
GRANT ALL PRIVILEGES ON DATABASE ${MATTERMOST_DB_NAME} TO ${MATTERMOST_DB_USER};
EOSQL

echo "✓ Base de données Mattermost créée"

# Téléchargement de Mattermost
echo "=== Téléchargement de Mattermost ==="
cd /tmp

# Détection de l'architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        MATTERMOST_ARCH="x86_64"
        ;;
    aarch64|arm64)
        MATTERMOST_ARCH="arm64"
        ;;
    *)
        error_exit "Architecture $ARCH non supportée par Mattermost"
        ;;
esac

if [ "$MATTERMOST_VERSION" = "latest" ]; then
    # Récupération de la dernière version
    MATTERMOST_VERSION=$(curl -s https://api.github.com/repos/mattermost/mattermost-server/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
fi

MATTERMOST_URL="https://releases.mattermost.com/${MATTERMOST_VERSION}/mattermost-${MATTERMOST_VERSION}-linux-${MATTERMOST_ARCH}.tar.gz"

echo "Téléchargement de Mattermost ${MATTERMOST_VERSION} pour ${MATTERMOST_ARCH}..."
wget "$MATTERMOST_URL" -O mattermost.tar.gz

# Extraction et installation
echo "Extraction et installation de Mattermost..."
tar -xzf mattermost.tar.gz
rm mattermost.tar.gz

if [ -d "$MATTERMOST_HOME" ]; then
    mv "$MATTERMOST_HOME" "${MATTERMOST_HOME}.bak.$(date +%Y%m%d_%H%M%S)"
fi

mv mattermost "$MATTERMOST_HOME"
chown -R "$MATTERMOST_USER:$MATTERMOST_USER" "$MATTERMOST_HOME"

# Configuration de Mattermost
echo "=== Configuration de Mattermost ==="
cat > "$MATTERMOST_HOME/config/config.json" <<EOF
{
    "ServiceSettings": {
        "SiteURL": "http://localhost",
        "ListenAddress": ":8065",
        "ConnectionSecurity": "",
        "TLSCertFile": "",
        "TLSKeyFile": ""
    },
    "TeamSettings": {
        "SiteName": "Mattermost",
        "MaxUsersPerTeam": 50,
        "EnableTeamCreation": true,
        "EnableUserCreation": true,
        "EnableOpenServer": true
    },
    "SqlSettings": {
        "DriverName": "postgres",
        "DataSource": "postgres://${MATTERMOST_DB_USER}:${MATTERMOST_DB_PASS}@localhost:5432/${MATTERMOST_DB_NAME}?sslmode=disable&connect_timeout=10",
        "DataSourceReplicas": [],
        "MaxIdleConns": 20,
        "ConnMaxLifetimeMilliseconds": 3600000,
        "MaxOpenConns": 300
    },
    "LogSettings": {
        "EnableConsole": true,
        "ConsoleLevel": "INFO",
        "EnableFile": true,
        "FileLevel": "INFO",
        "FileLocation": "logs/mattermost.log"
    },
    "FileSettings": {
        "MaxFileSize": 52428800,
        "DriverName": "local",
        "Directory": "./data/"
    },
    "EmailSettings": {
        "EnableSignUpWithEmail": true,
        "EnableSignInWithEmail": true,
        "EnableSignInWithUsername": true,
        "SendEmailNotifications": false,
        "RequireEmailVerification": false,
        "FeedbackName": "",
        "FeedbackEmail": "",
        "SMTPUsername": "",
        "SMTPPassword": "",
        "SMTPServer": "",
        "SMTPPort": "",
        "ConnectionSecurity": "",
        "InviteSalt": "$(openssl rand -base64 32)",
        "PasswordResetSalt": "$(openssl rand -base64 32)"
    },
    "PrivacySettings": {
        "ShowEmailAddress": true,
        "ShowFullName": true
    },
    "SupportSettings": {
        "TermsOfServiceLink": "",
        "PrivacyPolicyLink": "",
        "AboutLink": "",
        "HelpLink": "",
        "ReportAProblemLink": "",
        "SupportEmail": ""
    }
}
EOF

chown "$MATTERMOST_USER:$MATTERMOST_USER" "$MATTERMOST_HOME/config/config.json"

# Création du service systemd
echo "=== Création du service systemd ==="
cat > /etc/systemd/system/mattermost.service <<EOF
[Unit]
Description=Mattermost
After=network.target
After=postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=${MATTERMOST_USER}
Group=${MATTERMOST_USER}
WorkingDirectory=${MATTERMOST_HOME}
ExecStart=${MATTERMOST_HOME}/bin/mattermost
Restart=always
RestartSec=10
LimitNOFILE=49152

[Install]
WantedBy=multi-user.target
EOF

# Rechargement systemd et activation du service
systemctl daemon-reload
systemctl enable mattermost
systemctl start mattermost

# Attente du démarrage
echo "=== Démarrage de Mattermost ==="
sleep 10

# Vérification du statut
if systemctl is-active --quiet mattermost; then
    echo "✓ Mattermost démarré avec succès"
else
    echo "⚠️ Mattermost n'a pas démarré correctement. Vérifiez les logs avec : journalctl -u mattermost"
fi

# Configuration de Nginx
echo "=== Configuration de Nginx ==="
cat > /etc/nginx/sites-available/mattermost <<EOF
upstream mattermost_backend {
    server localhost:8065;
    keepalive 32;
}

server {
    listen 80;
    server_name localhost;

    location / {
        client_max_body_size 50M;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Frame-Options SAMEORIGIN;
        proxy_pass http://mattermost_backend;
    }
}
EOF

# Activation du site Nginx
ln -sf /etc/nginx/sites-available/mattermost /etc/nginx/sites-enabled/mattermost
rm -f /etc/nginx/sites-enabled/default

# Test de la configuration Nginx
nginx -t

# Redémarrage de Nginx
systemctl restart nginx

# Configuration du firewall (si ufw est installé)
if command -v ufw >/dev/null 2>&1; then
    echo "=== Configuration du firewall ==="
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
fi

echo
echo "============================================"
echo "🎉 MATTERMOST INSTALLÉ AVEC SUCCÈS"
echo "============================================"
echo "URL d'accès : http://votre-serveur"
echo "Utilisateur par défaut : (aucun - inscription ouverte)"
echo
echo "Configuration :"
echo "  - Utilisateur système : ${MATTERMOST_USER}"
echo "  - Répertoire d'installation : ${MATTERMOST_HOME}"
echo "  - Base de données : PostgreSQL (${MATTERMOST_DB_NAME})"
echo "  - Port : 8065 (interne), 80 (Nginx)"
echo
echo "Actions recommandées :"
echo "  1. Configurer HTTPS (Let's Encrypt recommandé)"
echo "  2. Configurer SMTP pour les notifications email"
echo "  3. Créer un utilisateur administrateur"
echo "  4. Configurer les sauvegardes automatiques"
echo "  5. Personnaliser les paramètres de sécurité"
echo
echo "Commandes utiles :"
echo "  - Statut : systemctl status mattermost"
echo "  - Logs : journalctl -u mattermost -f"
echo "  - Redémarrage : systemctl restart mattermost"
echo "============================================"