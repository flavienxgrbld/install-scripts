#!/usr/bin/env bash

# Script d'installation de Grafana sur tous les OS supportés

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
GRAFANA_VERSION="latest"
GRAFANA_USER="grafana"
GRAFANA_HOME="/usr/share/grafana"
GRAFANA_DATA_DIR="/var/lib/grafana"
GRAFANA_LOG_DIR="/var/log/grafana"

echo "=== Mise à jour du système ==="
pkg_update
pkg_upgrade

# Installation des dépendances
echo "=== Installation des dépendances ==="
pkg_install wget curl gnupg2 software-properties-common apt-transport-https

# Installation du dépôt Grafana selon l'OS
echo "=== Installation du dépôt Grafana ==="
case "$PKG_MANAGER" in
    apt)
        # Ajout de la clé GPG et du dépôt
        wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
        echo "deb https://packages.grafana.com/oss/deb stable main" > /etc/apt/sources.list.d/grafana.list
        pkg_update
        ;;
    dnf|yum)
        # Pour RHEL/CentOS/Fedora
        cat > /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
        ;;
    zypper)
        # Pour SUSE
        zypper addrepo https://packages.grafana.com/oss/rpm grafana
        zypper --gpg-auto-import-keys refresh
        ;;
    pacman)
        # Pour Arch Linux - installation depuis AUR ou binaire
        echo "Grafana sera installé depuis les dépôts officiels Arch..."
        ;;
esac

# Installation de Grafana
echo "=== Installation de Grafana ==="
case "$PKG_MANAGER" in
    apt|dnf|yum|zypper)
        pkg_install grafana
        ;;
    pacman)
        pkg_install grafana
        ;;
esac

# Création de l'utilisateur Grafana (si pas déjà créé par le package)
if ! id "$GRAFANA_USER" >/dev/null 2>&1; then
    useradd -r -s /bin/false -m -d "$GRAFANA_DATA_DIR" -c "Grafana Service" "$GRAFANA_USER"
fi

# Configuration des permissions
chown -R "$GRAFANA_USER:$GRAFANA_USER" "$GRAFANA_DATA_DIR"
chown -R "$GRAFANA_USER:$GRAFANA_USER" "$GRAFANA_LOG_DIR"

# Configuration de Grafana
echo "=== Configuration de Grafana ==="
GRAFANA_CONFIG="/etc/grafana/grafana.ini"

# Sauvegarde de la configuration originale
if [ -f "$GRAFANA_CONFIG" ]; then
    cp "$GRAFANA_CONFIG" "${GRAFANA_CONFIG}.bak"
fi

# Configuration de base
cat > "$GRAFANA_CONFIG" <<EOF
[server]
http_port = 3000
domain = localhost
root_url = http://localhost:3000

[security]
admin_user = admin
admin_password = admin

[users]
allow_sign_up = true
auto_assign_org = true
auto_assign_org_role = Viewer

[auth.anonymous]
enabled = true
org_name = Main Org.
org_role = Viewer

[log]
mode = console file
level = info
EOF

# Démarrage et activation du service
echo "=== Démarrage de Grafana ==="
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

# Attente du démarrage
sleep 5

# Vérification du statut
if systemctl is-active --quiet grafana-server; then
    echo "✓ Grafana démarré avec succès"
else
    echo "⚠️ Grafana n'a pas démarré correctement. Vérifiez les logs avec : journalctl -u grafana-server"
fi

# Configuration du firewall (si ufw est installé)
if command -v ufw >/dev/null 2>&1; then
    echo "=== Configuration du firewall ==="
    ufw allow 3000/tcp
    ufw --force enable
fi

# Installation de plugins populaires (optionnel)
echo "=== Installation de plugins Grafana populaires ==="
grafana-cli plugins install grafana-piechart-panel
grafana-cli plugins install grafana-worldmap-panel
grafana-cli plugins install grafana-clock-panel

# Redémarrage après installation des plugins
systemctl restart grafana-server

echo
echo "============================================"
echo "🎉 GRAFANA INSTALLÉ AVEC SUCCÈS"
echo "============================================"
echo "URL d'accès : http://votre-serveur:3000"
echo "Utilisateur admin : admin"
echo "Mot de passe admin : admin"
echo
echo "Configuration :"
echo "  - Utilisateur système : ${GRAFANA_USER}"
echo "  - Répertoire d'installation : ${GRAFANA_HOME}"
echo "  - Répertoire de données : ${GRAFANA_DATA_DIR}"
echo "  - Fichier de configuration : ${GRAFANA_CONFIG}"
echo "  - Logs : ${GRAFANA_LOG_DIR}"
echo
echo "Actions recommandées :"
echo "  1. Changer le mot de passe administrateur par défaut"
echo "  2. Configurer HTTPS (Let's Encrypt recommandé)"
echo "  3. Configurer des sources de données (Prometheus, InfluxDB, etc.)"
echo "  4. Installer des tableaux de bord pré-configurés"
echo "  5. Configurer l'authentification (LDAP, OAuth, etc.)"
echo
echo "Commandes utiles :"
echo "  - Statut : systemctl status grafana-server"
echo "  - Logs : journalctl -u grafana-server -f"
echo "  - Redémarrage : systemctl restart grafana-server"
echo "  - CLI : grafana-cli --help"
echo "============================================"