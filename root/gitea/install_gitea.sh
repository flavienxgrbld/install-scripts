#!/usr/bin/env bash

# Script d'installation de Gitea sur tous les OS supportés

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
GITEA_VERSION="latest"
GITEA_USER="git"
GITEA_HOME="/home/${GITEA_USER}"
GITEA_INSTALL_DIR="/opt/gitea"
GITEA_DATA_DIR="/var/lib/gitea"
GITEA_CONFIG_DIR="/etc/gitea"
GITEA_LOG_DIR="/var/log/gitea"
GITEA_DB_NAME="gitea"
GITEA_DB_USER="gitea"

echo "=== Mise à jour du système ==="
pkg_update
pkg_upgrade

# Installation de Git
echo "=== Installation de Git ==="
pkg_install git

# Installation de SQLite (option par défaut)
echo "=== Installation de SQLite ==="
pkg_install sqlite3

# Création de l'utilisateur Gitea
echo "=== Création de l'utilisateur Gitea ==="
if ! id "$GITEA_USER" >/dev/null 2>&1; then
    useradd -r -s /bin/bash -m -d "$GITEA_HOME" -c "Gitea Service" "$GITEA_USER"
fi

# Création des répertoires
echo "=== Création des répertoires ==="
mkdir -p "$GITEA_INSTALL_DIR"
mkdir -p "$GITEA_DATA_DIR"
mkdir -p "$GITEA_CONFIG_DIR"
mkdir -p "$GITEA_LOG_DIR"

chown -R "$GITEA_USER:$GITEA_USER" "$GITEA_HOME"
chown -R "$GITEA_USER:$GITEA_USER" "$GITEA_DATA_DIR"
chown -R "$GITEA_USER:$GITEA_USER" "$GITEA_CONFIG_DIR"
chown -R "$GITEA_USER:$GITEA_USER" "$GITEA_LOG_DIR"

# Téléchargement de Gitea
echo "=== Téléchargement de Gitea ==="
cd /tmp

# Détection de l'architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        GITEA_ARCH="linux-amd64"
        ;;
    aarch64|arm64)
        GITEA_ARCH="linux-arm64"
        ;;
    armv7l|armv7)
        GITEA_ARCH="linux-arm-7"
        ;;
    *)
        error_exit "Architecture $ARCH non supportée par Gitea"
        ;;
esac

if [ "$GITEA_VERSION" = "latest" ]; then
    # Récupération de la dernière version
    GITEA_VERSION=$(curl -s https://api.github.com/repos/go-gitea/gitea/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
fi

GITEA_URL="https://dl.gitea.com/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-${GITEA_ARCH}.xz"

echo "Téléchargement de Gitea ${GITEA_VERSION} pour ${GITEA_ARCH}..."
wget "$GITEA_URL" -O gitea.xz

# Extraction
echo "Extraction de Gitea..."
xz -d gitea.xz
chmod +x gitea

# Installation
echo "Installation de Gitea..."
mv gitea "$GITEA_INSTALL_DIR/gitea"
chown "$GITEA_USER:$GITEA_USER" "$GITEA_INSTALL_DIR/gitea"

# Création du fichier de configuration
echo "=== Configuration de Gitea ==="
cat > "$GITEA_CONFIG_DIR/app.ini" <<EOF
APP_NAME = Gitea: Git with a cup of tea
RUN_MODE = prod

[server]
HTTP_PORT = 3000
ROOT_URL = http://localhost:3000/
DISABLE_SSH = false
SSH_PORT = 22
LFS_START_SERVER = true
DOMAIN = localhost
LFS_JWT_SECRET = $(gitea generate secret JWT)

[database]
DB_TYPE = sqlite3
PATH = ${GITEA_DATA_DIR}/gitea.db

[repository]
ROOT = ${GITEA_DATA_DIR}/git/repositories

[log]
MODE = file
LEVEL = info
ROOT_PATH = ${GITEA_LOG_DIR}

[security]
SECRET_KEY = $(gitea generate secret SECRET_KEY)
INTERNAL_TOKEN = $(gitea generate secret INTERNAL_TOKEN)

[service]
DISABLE_REGISTRATION = false
ALLOW_ONLY_EXTERNAL_REGISTRATION = false

[session]
PROVIDER = file
EOF

chown "$GITEA_USER:$GITEA_USER" "$GITEA_CONFIG_DIR/app.ini"

# Création du service systemd
echo "=== Création du service systemd ==="
cat > /etc/systemd/system/gitea.service <<EOF
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target
Requires=network.target

[Service]
Type=simple
User=${GITEA_USER}
Group=${GITEA_USER}
WorkingDirectory=${GITEA_DATA_DIR}
ExecStart=${GITEA_INSTALL_DIR}/gitea web --config ${GITEA_CONFIG_DIR}/app.ini
Restart=always
RestartSec=2s
Environment=USER=${GITEA_USER} HOME=${GITEA_HOME} GITEA_WORK_DIR=${GITEA_DATA_DIR}

[Install]
WantedBy=multi-user.target
EOF

# Rechargement systemd et activation du service
systemctl daemon-reload
systemctl enable gitea
systemctl start gitea

# Attente du démarrage
echo "=== Démarrage de Gitea ==="
sleep 5

# Vérification du statut
if systemctl is-active --quiet gitea; then
    echo "✓ Gitea démarré avec succès"
else
    echo "⚠️ Gitea n'a pas démarré correctement. Vérifiez les logs avec : journalctl -u gitea"
fi

# Configuration du firewall (si ufw est installé)
if command -v ufw >/dev/null 2>&1; then
    echo "=== Configuration du firewall ==="
    ufw allow 3000/tcp
    ufw --force enable
fi

# Configuration de SSH pour Git
echo "=== Configuration SSH pour Git ==="
mkdir -p "$GITEA_HOME/.ssh"
chown -R "$GITEA_USER:$GITEA_USER" "$GITEA_HOME/.ssh"

echo
echo "============================================"
echo "🎉 GITEA INSTALLÉ AVEC SUCCÈS"
echo "============================================"
echo "URL d'accès : http://votre-serveur:3000"
echo "Utilisateur par défaut : (aucun - inscription ouverte)"
echo
echo "Configuration :"
echo "  - Utilisateur système : ${GITEA_USER}"
echo "  - Répertoire d'installation : ${GITEA_INSTALL_DIR}"
echo "  - Répertoire de données : ${GITEA_DATA_DIR}"
echo "  - Fichier de configuration : ${GITEA_CONFIG_DIR}/app.ini"
echo "  - Logs : ${GITEA_LOG_DIR}"
echo
echo "Actions recommandées :"
echo "  1. Configurer un reverse proxy (Nginx/Apache) pour HTTPS"
echo "  2. Configurer un nom de domaine"
echo "  3. Configurer les sauvegardes automatiques"
echo "  4. Configurer SMTP pour les notifications"
echo "  5. Créer un utilisateur administrateur"
echo
echo "Commandes utiles :"
echo "  - Statut : systemctl status gitea"
echo "  - Logs : journalctl -u gitea -f"
echo "  - Redémarrage : systemctl restart gitea"
echo "============================================"