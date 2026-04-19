#!/usr/bin/env bash

# Script d'installation de Nextcloud sur tous les OS supportés

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
NEXTCLOUD_VERSION="latest"
NEXTCLOUD_DB_NAME="nextcloud"
NEXTCLOUD_DB_USER="nextcloud"
PHP_MIN_VERSION="8.1"
NEXTCLOUD_ADMIN_USER="admin"
NEXTCLOUD_DATA_DIR="/var/www/nextcloud/data"

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
    echo "ERREUR: PHP $PHP_INSTALLED_VERSION est installé mais Nextcloud requiert PHP $PHP_MIN_VERSION minimum"
    exit 1
fi

echo "✓ PHP $PHP_INSTALLED_VERSION est compatible avec Nextcloud"

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
        pkg_install php${PHP_MIN_VERSION//./}-gd php${PHP_MIN_VERSION//./}-curl php${PHP_MIN_VERSION//./}-zip php${PHP_MIN_VERSION//./}-xml php${PHP_MIN_VERSION//./}-mbstring php${PHP_MIN_VERSION//./}-mysql php${PHP_MIN_VERSION//./}-intl php${PHP_MIN_VERSION//./}-bz2 php${PHP_MIN_VERSION//./}-ldap php${PHP_MIN_VERSION//./}-smbclient php${PHP_MIN_VERSION//./}-ftp php${PHP_MIN_VERSION//./}-imagick php${PHP_MIN_VERSION//./}-gmp php${PHP_MIN_VERSION//./}-bcmath php${PHP_MIN_VERSION//./}-sqlite3
        ;;
    dnf|yum)
        pkg_install php-gd php-curl php-zip php-xml php-mbstring php-mysqlnd php-intl php-bz2 php-ldap php-ftp php-imagick php-gmp php-bcmath php-sqlite3
        ;;
    zypper)
        pkg_install php${PHP_MIN_VERSION//./}-gd php${PHP_MIN_VERSION//./}-curl php${PHP_MIN_VERSION//./}-zip php${PHP_MIN_VERSION//./}-xml php${PHP_MIN_VERSION//./}-mbstring php${PHP_MIN_VERSION//./}-mysql php${PHP_MIN_VERSION//./}-intl php${PHP_MIN_VERSION//./}-bz2 php${PHP_MIN_VERSION//./}-ldap php${PHP_MIN_VERSION//./}-ftp php${PHP_MIN_VERSION//./}-imagick php${PHP_MIN_VERSION//./}-gmp php${PHP_MIN_VERSION//./}-bcmath php${PHP_MIN_VERSION//./}-sqlite3
        ;;
    pacman)
        pkg_install php-gd php-intl php-mcrypt php-sqlite
        ;;
esac

# Installation d'outils supplémentaires
echo "=== Installation d'outils supplémentaires ==="
pkg_install wget unzip curl bzip2

# Configuration de MariaDB
echo "=== Configuration de MariaDB ==="
read -sp "Entrez le mot de passe root MySQL à définir: " MYSQL_ROOT_PASS
echo
read -sp "Entrez le mot de passe pour l'utilisateur Nextcloud (DB): " NEXTCLOUD_DB_PASS
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

# Création de la base de données Nextcloud
mysql -uroot -p"${MYSQL_ROOT_PASS}" <<EOSQL
CREATE DATABASE ${NEXTCLOUD_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '${NEXTCLOUD_DB_USER}'@'localhost' IDENTIFIED BY '${NEXTCLOUD_DB_PASS}';
GRANT ALL PRIVILEGES ON ${NEXTCLOUD_DB_NAME}.* TO '${NEXTCLOUD_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOSQL

echo "✓ Base de données Nextcloud créée"

# Téléchargement et installation de Nextcloud
echo "=== Téléchargement et installation de Nextcloud ==="
cd /tmp
if [ "$NEXTCLOUD_VERSION" = "latest" ]; then
    NEXTCLOUD_URL="https://download.nextcloud.com/server/releases/latest.zip"
else
    NEXTCLOUD_URL="https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.zip"
fi

wget "$NEXTCLOUD_URL" -O nextcloud.zip
unzip nextcloud.zip
rm nextcloud.zip

# Déplacement vers /var/www
if [ -d "/var/www/nextcloud" ]; then
    mv "/var/www/nextcloud" "/var/www/nextcloud.bak.$(date +%Y%m%d_%H%M%S)"
fi

mv nextcloud /var/www/
chown -R www-data:www-data /var/www/nextcloud 2>/dev/null || chown -R apache:apache /var/www/nextcloud 2>/dev/null || chown -R nginx:nginx /var/www/nextcloud

# Création du répertoire de données
mkdir -p "$NEXTCLOUD_DATA_DIR"
chown -R www-data:www-data "$NEXTCLOUD_DATA_DIR" 2>/dev/null || chown -R apache:apache "$NEXTCLOUD_DATA_DIR" 2>/dev/null || chown -R nginx:nginx "$NEXTCLOUD_DATA_DIR"

# Configuration Apache
echo "=== Configuration Apache ==="
cat > /etc/apache2/sites-available/nextcloud.conf <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/nextcloud

    <Directory /var/www/nextcloud>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog \${APACHE_LOG_DIR}/nextcloud_access.log combined
</VirtualHost>
EOF

# Activation du site et des modules nécessaires
a2ensite nextcloud.conf 2>/dev/null || true
a2enmod rewrite headers env dir mime 2>/dev/null || true

# Configuration PHP pour gros fichiers
echo "=== Configuration PHP pour Nextcloud ==="
PHP_INI_FILE="/etc/php/${PHP_MIN_VERSION}/apache2/php.ini"
if [ -f "$PHP_INI_FILE" ]; then
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 512M/' "$PHP_INI_FILE"
    sed -i 's/post_max_size = .*/post_max_size = 512M/' "$PHP_INI_FILE"
    sed -i 's/memory_limit = .*/memory_limit = 512M/' "$PHP_INI_FILE"
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI_FILE"
fi

# Redémarrage des services
echo "=== Redémarrage des services ==="
systemctl restart apache2 2>/dev/null || systemctl restart httpd 2>/dev/null || systemctl restart nginx
systemctl restart mariadb 2>/dev/null || systemctl restart mysql

# Configuration finale
echo "=== Configuration finale ==="
read -sp "Entrez le mot de passe administrateur Nextcloud: " NEXTCLOUD_ADMIN_PASS
echo

# Création du fichier de configuration automatique
cat > /var/www/nextcloud/config/autoconfig.php <<EOF
<?php
\$AUTOCONFIG = array(
  "dbtype"        => "mysql",
  "dbname"        => "${NEXTCLOUD_DB_NAME}",
  "dbuser"        => "${NEXTCLOUD_DB_USER}",
  "dbpass"        => "${NEXTCLOUD_DB_PASS}",
  "dbhost"        => "localhost",
  "dbtableprefix" => "oc_",
  "adminlogin"    => "${NEXTCLOUD_ADMIN_USER}",
  "adminpass"     => "${NEXTCLOUD_ADMIN_PASS}",
  "directory"     => "${NEXTCLOUD_DATA_DIR}",
);
EOF

chown www-data:www-data /var/www/nextcloud/config/autoconfig.php 2>/dev/null || chown apache:apache /var/www/nextcloud/config/autoconfig.php 2>/dev/null || chown nginx:nginx /var/www/nextcloud/config/autoconfig.php

echo
echo "============================================"
echo "🎉 NEXTCLOUD INSTALLÉ AVEC SUCCÈS"
echo "============================================"
echo "URL d'accès : http://votre-serveur/nextcloud"
echo "Utilisateur admin : ${NEXTCLOUD_ADMIN_USER}"
echo "Mot de passe admin : ${NEXTCLOUD_ADMIN_PASS}"
echo
echo "Base de données :"
echo "  - Nom : ${NEXTCLOUD_DB_NAME}"
echo "  - Utilisateur : ${NEXTCLOUD_DB_USER}"
echo "  - Mot de passe : ${NEXTCLOUD_DB_PASS}"
echo
echo "Répertoire de données : ${NEXTCLOUD_DATA_DIR}"
echo
echo "Actions recommandées :"
echo "  1. Configurer HTTPS (Let's Encrypt recommandé)"
echo "  2. Configurer les tâches cron pour Nextcloud"
echo "  3. Vérifier les permissions des fichiers"
echo "  4. Installer des applications supplémentaires"
echo "============================================"