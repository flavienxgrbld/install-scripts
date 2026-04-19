#!/usr/bin/env bash

# Script d'installation de Kanboard sur tous les OS supportés

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
KANBOARD_VERSION="latest"
KANBOARD_DB_NAME="kanboard"
KANBOARD_DB_USER="kanboard"
PHP_MIN_VERSION="7.4"
KANBOARD_ADMIN_USER="admin"

echo "=== Mise à jour du système ==="
pkg_update
pkg_upgrade

# Installation de PHP
echo "=== Installation de PHP ${PHP_MIN_VERSION}+ ==="
install_php "$PHP_MIN_VERSION"

# Vérifier la version de PHP installée
PHP_INSTALLED_VERSION=$(php -r "echo PHP_VERSION;" | cut -d. -f1,2)
echo "Version PHP installée: $PHP_INSTALLED_VERSION"

if (( $(echo "$PHP_INSTALLED_VERSION < $PHP_MIN_VERSION" | bc -l 2>/dev/null || echo "1") )); then
    echo "ERREUR: PHP $PHP_INSTALLED_VERSION est installé mais Kanboard requiert PHP $PHP_MIN_VERSION minimum"
    exit 1
fi

echo "✓ PHP $PHP_INSTALLED_VERSION est compatible avec Kanboard"

# Installation du serveur web
echo "=== Installation du serveur web ==="
install_webserver "apache"

# Installation de la base de données
echo "=== Installation de MariaDB ==="
install_database

# Configuration de PHP
echo "=== Configuration de PHP ==="
configure_php "$PHP_MIN_VERSION"

# Extensions PHP supplémentaires selon l'OS
case "$PKG_MANAGER" in
    apt)
        pkg_install php${PHP_MIN_VERSION//./}-mysql php${PHP_MIN_VERSION//./}-gd php${PHP_MIN_VERSION//./}-mbstring php${PHP_MIN_VERSION//./}-xml php${PHP_MIN_VERSION//./}-zip php${PHP_MIN_VERSION//./}-curl php${PHP_MIN_VERSION//./}-json php${PHP_MIN_VERSION//./}-openssl
        ;;
    dnf|yum)
        pkg_install php-mysqlnd php-gd php-mbstring php-xml php-zip php-curl php-json php-openssl
        ;;
    zypper)
        pkg_install php${PHP_MIN_VERSION//./}-mysql php${PHP_MIN_VERSION//./}-gd php${PHP_MIN_VERSION//./}-mbstring php${PHP_MIN_VERSION//./}-xml php${PHP_MIN_VERSION//./}-zip php${PHP_MIN_VERSION//./}-curl php${PHP_MIN_VERSION//./}-json php${PHP_MIN_VERSION//./}-openssl
        ;;
    pacman)
        pkg_install php-gd php-sqlite
        ;;
esac

# Installation d'outils supplémentaires
echo "=== Installation d'outils supplémentaires ==="
pkg_install wget unzip curl

# Configuration de MariaDB
echo "=== Configuration de MariaDB ==="
read -sp "Entrez le mot de passe root MySQL à définir: " MYSQL_ROOT_PASS
echo
read -sp "Entrez le mot de passe pour l'utilisateur Kanboard (DB): " KANBOARD_DB_PASS
echo

# Sécurisation de MySQL
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';"
mysql -uroot -p"${MYSQL_ROOT_PASS}" <<EOSQL
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOSQL

# Création de la base de données Kanboard
mysql -uroot -p"${MYSQL_ROOT_PASS}" <<EOSQL
CREATE DATABASE ${KANBOARD_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${KANBOARD_DB_USER}'@'localhost' IDENTIFIED BY '${KANBOARD_DB_PASS}';
GRANT ALL PRIVILEGES ON ${KANBOARD_DB_NAME}.* TO '${KANBOARD_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOSQL

echo "✓ Base de données Kanboard créée"

# Téléchargement et installation de Kanboard
echo "=== Téléchargement et installation de Kanboard ==="
cd /tmp

if [ "$KANBOARD_VERSION" = "latest" ]; then
    KANBOARD_URL="https://github.com/kanboard/kanboard/archive/master.zip"
    KANBOARD_DIR="kanboard-master"
else
    KANBOARD_URL="https://github.com/kanboard/kanboard/archive/v${KANBOARD_VERSION}.zip"
    KANBOARD_DIR="kanboard-${KANBOARD_VERSION}"
fi

wget "$KANBOARD_URL" -O kanboard.zip
unzip kanboard.zip
rm kanboard.zip

# Déplacement vers /var/www
if [ -d "/var/www/kanboard" ]; then
    mv "/var/www/kanboard" "/var/www/kanboard.bak.$(date +%Y%m%d_%H%M%S)"
fi

mv "$KANBOARD_DIR" /var/www/kanboard
chown -R www-data:www-data /var/www/kanboard 2>/dev/null || chown -R apache:apache /var/www/kanboard 2>/dev/null || chown -R nginx:nginx /var/www/kanboard

# Configuration de Kanboard
echo "=== Configuration de Kanboard ==="
cd /var/www/kanboard

# Copie du fichier de configuration
cp config.default.php config.php

# Configuration de la base de données
sed -i "s/define('DB_DRIVER', 'sqlite');/define('DB_DRIVER', 'mysql');/" config.php
sed -i "s/define('DB_USERNAME', 'root');/define('DB_USERNAME', '${KANBOARD_DB_USER}');/" config.php
sed -i "s/define('DB_PASSWORD', '');/define('DB_PASSWORD', '${KANBOARD_DB_PASS}');/" config.php
sed -i "s/define('DB_NAME', 'kanboard');/define('DB_NAME', '${KANBOARD_DB_NAME}');/" config.php

# Configuration des permissions
echo "=== Configuration des permissions ==="
mkdir -p data
chmod 755 data
chmod 755 plugins
chmod 755 config.php

# Configuration Apache
echo "=== Configuration Apache ==="
cat > /etc/apache2/sites-available/kanboard.conf <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/kanboard

    <Directory /var/www/kanboard>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/kanboard_error.log
    CustomLog \${APACHE_LOG_DIR}/kanboard_access.log combined
</VirtualHost>
EOF

# Activation du site et des modules nécessaires
a2ensite kanboard.conf 2>/dev/null || true
a2enmod rewrite 2>/dev/null || true

# Configuration PHP pour Kanboard
echo "=== Configuration PHP pour Kanboard ==="
PHP_INI_FILE="/etc/php/${PHP_MIN_VERSION}/apache2/php.ini"
if [ -f "$PHP_INI_FILE" ]; then
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 20M/' "$PHP_INI_FILE"
    sed -i 's/post_max_size = .*/post_max_size = 20M/' "$PHP_INI_FILE"
    sed -i 's/memory_limit = .*/memory_limit = 128M/' "$PHP_INI_FILE"
    sed -i 's/max_execution_time = .*/max_execution_time = 60/' "$PHP_INI_FILE"
fi

# Redémarrage des services
echo "=== Redémarrage des services ==="
systemctl restart apache2 2>/dev/null || systemctl restart httpd 2>/dev/null || systemctl restart nginx
systemctl restart mariadb 2>/dev/null || systemctl restart mysql

echo
echo "============================================"
echo "🎉 KANBOARD INSTALLÉ AVEC SUCCÈS"
echo "============================================"
echo "URL d'accès : http://votre-serveur/kanboard"
echo "Utilisateur admin par défaut : admin"
echo "Mot de passe admin par défaut : admin"
echo
echo "Base de données :"
echo "  - Nom : ${KANBOARD_DB_NAME}"
echo "  - Utilisateur : ${KANBOARD_DB_USER}"
echo "  - Mot de passe : ${KANBOARD_DB_PASS}"
echo
echo "Actions recommandées :"
echo "  1. Changer le mot de passe administrateur par défaut"
echo "  2. Configurer HTTPS (Let's Encrypt recommandé)"
echo "  3. Configurer les sauvegardes automatiques"
echo "  4. Installer des plugins supplémentaires"
echo "  5. Personnaliser les paramètres du projet"
echo
echo "Commandes utiles :"
echo "  - Permissions : chown -R www-data:www-data /var/www/kanboard"
echo "  - Logs Apache : tail -f /var/log/apache2/kanboard_error.log"
echo "  - Base de données : mysql -u ${KANBOARD_DB_USER} -p ${KANBOARD_DB_NAME}"
echo "============================================"