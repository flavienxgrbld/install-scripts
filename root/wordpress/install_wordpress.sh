#!/usr/bin/env bash

# Script d'installation de WordPress sur tous les OS supportés

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
WORDPRESS_VERSION="latest"
WORDPRESS_DB_NAME="wordpress"
WORDPRESS_DB_USER="wordpress"
PHP_MIN_VERSION="7.4"
WORDPRESS_ADMIN_USER="admin"
WORDPRESS_SITE_URL="http://localhost"

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
    echo "ERREUR: PHP $PHP_INSTALLED_VERSION est installé mais WordPress requiert PHP $PHP_MIN_VERSION minimum"
    exit 1
fi

echo "✓ PHP $PHP_INSTALLED_VERSION est compatible avec WordPress"

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
        pkg_install php${PHP_MIN_VERSION//./}-mysql php${PHP_MIN_VERSION//./}-curl php${PHP_MIN_VERSION//./}-gd php${PHP_MIN_VERSION//./}-mbstring php${PHP_MIN_VERSION//./}-xml php${PHP_MIN_VERSION//./}-xmlrpc php${PHP_MIN_VERSION//./}-soap php${PHP_MIN_VERSION//./}-intl php${PHP_MIN_VERSION//./}-zip
        ;;
    dnf|yum)
        pkg_install php-mysqlnd php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip
        ;;
    zypper)
        pkg_install php${PHP_MIN_VERSION//./}-mysql php${PHP_MIN_VERSION//./}-curl php${PHP_MIN_VERSION//./}-gd php${PHP_MIN_VERSION//./}-mbstring php${PHP_MIN_VERSION//./}-xml php${PHP_MIN_VERSION//./}-xmlrpc php${PHP_MIN_VERSION//./}-soap php${PHP_MIN_VERSION//./}-intl php${PHP_MIN_VERSION//./}-zip
        ;;
    pacman)
        pkg_install php-gd php-intl
        ;;
esac

# Installation d'outils supplémentaires
echo "=== Installation d'outils supplémentaires ==="
pkg_install wget unzip curl

# Configuration de MariaDB
echo "=== Configuration de MariaDB ==="
read -sp "Entrez le mot de passe root MySQL à définir: " MYSQL_ROOT_PASS
echo
read -sp "Entrez le mot de passe pour l'utilisateur WordPress (DB): " WORDPRESS_DB_PASS
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

# Création de la base de données WordPress
mysql -uroot -p"${MYSQL_ROOT_PASS}" <<EOSQL
CREATE DATABASE ${WORDPRESS_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '${WORDPRESS_DB_USER}'@'localhost' IDENTIFIED BY '${WORDPRESS_DB_PASS}';
GRANT ALL PRIVILEGES ON ${WORDPRESS_DB_NAME}.* TO '${WORDPRESS_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOSQL

echo "✓ Base de données WordPress créée"

# Téléchargement et installation de WordPress
echo "=== Téléchargement et installation de WordPress ==="
cd /tmp
if [ "$WORDPRESS_VERSION" = "latest" ]; then
    WORDPRESS_URL="https://wordpress.org/latest.zip"
else
    WORDPRESS_URL="https://wordpress.org/wordpress-${WORDPRESS_VERSION}.zip"
fi

wget "$WORDPRESS_URL" -O wordpress.zip
unzip wordpress.zip
rm wordpress.zip

# Déplacement vers /var/www
if [ -d "/var/www/wordpress" ]; then
    mv "/var/www/wordpress" "/var/www/wordpress.bak.$(date +%Y%m%d_%H%M%S)"
fi

mv wordpress /var/www/
chown -R www-data:www-data /var/www/wordpress 2>/dev/null || chown -R apache:apache /var/www/wordpress 2>/dev/null || chown -R nginx:nginx /var/www/wordpress

# Configuration Apache
echo "=== Configuration Apache ==="
cat > /etc/apache2/sites-available/wordpress.conf <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/wordpress

    <Directory /var/www/wordpress>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/wordpress_error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress_access.log combined
</VirtualHost>
EOF

# Activation du site et des modules nécessaires
a2ensite wordpress.conf 2>/dev/null || true
a2enmod rewrite 2>/dev/null || true

# Création du fichier de configuration wp-config.php
echo "=== Configuration WordPress ==="
cd /var/www/wordpress

# Génération des clés de sécurité WordPress
WP_SALT_KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

cat > wp-config.php <<EOF
<?php
define( 'DB_NAME', '${WORDPRESS_DB_NAME}' );
define( 'DB_USER', '${WORDPRESS_DB_USER}' );
define( 'DB_PASSWORD', '${WORDPRESS_DB_PASS}' );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

${WP_SALT_KEYS}

\$table_prefix = 'wp_';

define( 'WP_DEBUG', false );

if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
EOF

chown www-data:www-data wp-config.php 2>/dev/null || chown apache:apache wp-config.php 2>/dev/null || chown nginx:nginx wp-config.php

# Configuration PHP pour WordPress
echo "=== Configuration PHP pour WordPress ==="
PHP_INI_FILE="/etc/php/${PHP_MIN_VERSION}/apache2/php.ini"
if [ -f "$PHP_INI_FILE" ]; then
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' "$PHP_INI_FILE"
    sed -i 's/post_max_size = .*/post_max_size = 64M/' "$PHP_INI_FILE"
    sed -i 's/memory_limit = .*/memory_limit = 256M/' "$PHP_INI_FILE"
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI_FILE"
fi

# Redémarrage des services
echo "=== Redémarrage des services ==="
systemctl restart apache2 2>/dev/null || systemctl restart httpd 2>/dev/null || systemctl restart nginx
systemctl restart mariadb 2>/dev/null || systemctl restart mysql

echo
echo "============================================"
echo "🎉 WORDPRESS INSTALLÉ AVEC SUCCÈS"
echo "============================================"
echo "URL d'accès : ${WORDPRESS_SITE_URL}/wordpress"
echo
echo "Base de données :"
echo "  - Nom : ${WORDPRESS_DB_NAME}"
echo "  - Utilisateur : ${WORDPRESS_DB_USER}"
echo "  - Mot de passe : ${WORDPRESS_DB_PASS}"
echo
echo "Pour finaliser l'installation :"
echo "  1. Accédez à ${WORDPRESS_SITE_URL}/wordpress"
echo "  2. Choisissez la langue"
echo "  3. Créez votre compte administrateur"
echo
echo "Actions recommandées :"
echo "  1. Configurer HTTPS (Let's Encrypt recommandé)"
echo "  2. Installer un thème et des plugins"
echo "  3. Configurer les sauvegardes automatiques"
echo "  4. Mettre à jour régulièrement WordPress"
echo "============================================"