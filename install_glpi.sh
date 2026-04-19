#!/usr/bin/env bash

# Script d'installation de GLPI 11.0.4 sur tous les OS supportés

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
GLPI_VERSION="11.0.4"
GLPI_DB_NAME="glpi"
GLPI_DB_USER="glpi"
PHP_MIN_VERSION="8.2"  # Version minimum requise pour GLPI 11.x

echo "=== Mise à jour du système ==="
pkg_update
pkg_upgrade

# Installation de PHP sur tous les OS
echo "=== Installation de PHP ${PHP_MIN_VERSION}+ ==="
install_php "$PHP_MIN_VERSION"

# Vérifier la version de PHP installée
PHP_INSTALLED_VERSION=$(php -r "echo PHP_VERSION;" | cut -d. -f1,2)
echo "Version PHP installée: $PHP_INSTALLED_VERSION"

if (( $(echo "$PHP_INSTALLED_VERSION < $PHP_MIN_VERSION" | bc -l 2>/dev/null || echo "1") )); then
    echo "ERREUR: PHP $PHP_INSTALLED_VERSION est installé mais GLPI 11.x requiert PHP $PHP_MIN_VERSION minimum"
    exit 1
fi

echo "✓ PHP $PHP_INSTALLED_VERSION est compatible avec GLPI 11.x"

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
        pkg_install php${PHP_MIN_VERSION//./}-apcu php${PHP_MIN_VERSION//./}-imap php${PHP_MIN_VERSION//./}-ldap php${PHP_MIN_VERSION//./}-xmlrpc php${PHP_MIN_VERSION//./}-redis php${PHP_MIN_VERSION//./}-bz2 php${PHP_MIN_VERSION//./}-soap php-cas libapache2-mod-php${PHP_MIN_VERSION//./}
        ;;
    dnf|yum)
        pkg_install php-apcu php-imap php-ldap php-xmlrpc php-redis php-bz2 php-soap php-pecl-apcu
        ;;
    zypper)
        pkg_install php${PHP_MIN_VERSION//./}-apcu php${PHP_MIN_VERSION//./}-imap php${PHP_MIN_VERSION//./}-ldap php${PHP_MIN_VERSION//./}-xmlrpc php${PHP_MIN_VERSION//./}-redis php${PHP_MIN_VERSION//./}-bz2 php${PHP_MIN_VERSION//./}-soap
        ;;
    pacman)
        pkg_install php-apcu php-imap php-ldap php-xmlrpc php-redis
        ;;
esac

echo "=== Configuration de MariaDB ==="
# Demander les mots de passe
read -sp "Entrez le mot de passe root MySQL à définir: " MYSQL_ROOT_PASS
echo
read -sp "Entrez le mot de passe pour l'utilisateur GLPI (DB): " GLPI_DB_PASS
echo

echo "=== Sécurisation automatique de MySQL ==="
# Exécuter mysql_secure_installation automatiquement
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';"
mysql -uroot -p"${MYSQL_ROOT_PASS}" <<EOSQL
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOSQL

echo "✓ MySQL sécurisé avec succès"

echo "=== Création de la base de données GLPI ==="
mysql -uroot -p"${MYSQL_ROOT_PASS}" <<EOSQL
CREATE DATABASE IF NOT EXISTS ${GLPI_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${GLPI_DB_USER}'@'localhost' IDENTIFIED BY '${GLPI_DB_PASS}';
GRANT ALL PRIVILEGES ON ${GLPI_DB_NAME}.* TO '${GLPI_DB_USER}'@'localhost';
GRANT SELECT ON \`mysql\`.\`time_zone_name\` TO '${GLPI_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOSQL

echo "=== Chargement des fuseaux horaires MySQL ==="
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -uroot -p"${MYSQL_ROOT_PASS}" mysql

echo "=== Téléchargement et extraction de GLPI ==="
cd /tmp
wget -q --show-progress https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz
tar -xzf glpi-${GLPI_VERSION}.tgz -C /var/www/html/
rm -f glpi-${GLPI_VERSION}.tgz

echo "=== Création des répertoires de configuration ==="
mkdir -p /etc/glpi
mkdir -p /var/lib/glpi
mkdir -p /var/log/glpi

echo "=== Création du fichier downstream.php ==="
cat > /var/www/html/glpi/inc/downstream.php <<'EOPHP'
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
    require_once GLPI_CONFIG_DIR . '/local_define.php';
}
EOPHP

echo "=== Déplacement des répertoires ==="
if [ -d "/var/www/html/glpi/config" ]; then
    mv /var/www/html/glpi/config/* /etc/glpi/ 2>/dev/null || true
    rmdir /var/www/html/glpi/config
fi

if [ -d "/var/www/html/glpi/files" ]; then
    mv /var/www/html/glpi/files/* /var/lib/glpi/ 2>/dev/null || true
    rmdir /var/www/html/glpi/files
fi

if [ -d "/var/lib/glpi/_log" ]; then
    mv /var/lib/glpi/_log/* /var/log/glpi/ 2>/dev/null || true
    rmdir /var/lib/glpi/_log
fi

echo "=== Création du fichier local_define.php ==="
cat > /etc/glpi/local_define.php <<'EOPHP'
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi');
define('GLPI_DOC_DIR', GLPI_VAR_DIR);
define('GLPI_CACHE_DIR', GLPI_VAR_DIR . '/_cache');
define('GLPI_CRON_DIR', GLPI_VAR_DIR . '/_cron');
define('GLPI_GRAPH_DIR', GLPI_VAR_DIR . '/_graphs');
define('GLPI_LOCAL_I18N_DIR', GLPI_VAR_DIR . '/_locales');
define('GLPI_LOCK_DIR', GLPI_VAR_DIR . '/_lock');
define('GLPI_PICTURE_DIR', GLPI_VAR_DIR . '/_pictures');
define('GLPI_PLUGIN_DOC_DIR', GLPI_VAR_DIR . '/_plugins');
define('GLPI_RSS_DIR', GLPI_VAR_DIR . '/_rss');
define('GLPI_SESSION_DIR', GLPI_VAR_DIR . '/_sessions');
define('GLPI_TMP_DIR', GLPI_VAR_DIR . '/_tmp');
define('GLPI_UPLOAD_DIR', GLPI_VAR_DIR . '/_uploads');
define('GLPI_INVENTORY_DIR', GLPI_VAR_DIR . '/_inventories');
define('GLPI_THEMES_DIR', GLPI_VAR_DIR . '/_themes');
define('GLPI_LOG_DIR', '/var/log/glpi');
EOPHP

echo "=== Configuration des permissions ==="
chown -R root:root /var/www/html/glpi/
chown -R www-data:www-data /etc/glpi
chown -R www-data:www-data /var/lib/glpi
chown -R www-data:www-data /var/log/glpi
chown -R www-data:www-data /var/www/html/glpi/marketplace

find /var/www/html/glpi/ -type f -exec chmod 0644 {} \;
find /var/www/html/glpi/ -type d -exec chmod 0755 {} \;
find /etc/glpi -type f -exec chmod 0644 {} \;
find /etc/glpi -type d -exec chmod 0755 {} \;
find /var/lib/glpi -type f -exec chmod 0644 {} \;
find /var/lib/glpi -type d -exec chmod 0755 {} \;
find /var/log/glpi -type f -exec chmod 0644 {} \;
find /var/log/glpi -type d -exec chmod 0755 {} \;

echo "=== Configuration du VirtualHost Apache ==="
# Détecter automatiquement la version PHP
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")

cat > /etc/apache2/sites-available/glpi.conf <<'EOCONF'
<VirtualHost *:80>
    ServerName yourglpi.yourdomain.com
    DocumentRoot /var/www/html/glpi/public
    
    <Directory /var/www/html/glpi/public>
        Require all granted
        RewriteEngine On
        
        # Ensure authorization headers are passed to PHP
        RewriteCond %{HTTP:Authorization} ^(.+)$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
        
        # Redirect all requests to GLPI router, unless the file exists
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
</VirtualHost>
EOCONF

echo "=== Activation du site GLPI ==="
a2dissite 000-default.conf
a2ensite glpi.conf
a2enmod rewrite

echo "=== Configuration de PHP ==="
# Détecter la version PHP installée et le fichier php.ini
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
PHP_INI="/etc/php/${PHP_VERSION}/apache2/php.ini"

if [ -f "$PHP_INI" ]; then
    # Sauvegarde du fichier original
    cp "$PHP_INI" "${PHP_INI}.backup"
    
    # Modifier les paramètres PHP
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 20M/' "$PHP_INI"
    sed -i 's/^post_max_size = .*/post_max_size = 20M/' "$PHP_INI"
    sed -i 's/^memory_limit = .*/memory_limit = 256M/' "$PHP_INI"
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
    sed -i 's/^max_input_vars = .*/max_input_vars = 5000/' "$PHP_INI"
    sed -i 's/^session.cookie_httponly = .*/session.cookie_httponly = On/' "$PHP_INI"
    sed -i 's/^;date.timezone =.*/date.timezone = Europe\/Paris/' "$PHP_INI"
    
    echo "Configuration PHP mise à jour dans: $PHP_INI"
else
    echo "ATTENTION: Fichier php.ini non trouvé à $PHP_INI"
    echo "Veuillez configurer manuellement les paramètres PHP suivants:"
    echo "  upload_max_filesize = 20M"
    echo "  post_max_size = 20M"
    echo "  memory_limit = 256M"
    echo "  max_execution_time = 300"
    echo "  max_input_vars = 5000"
    echo "  session.cookie_httponly = On"
    echo "  date.timezone = Europe/Paris"
fi

echo "=== Redémarrage d'Apache ==="
systemctl restart apache2

echo ""
echo "========================================="
echo "Installation de GLPI terminée !"
echo "========================================="
echo ""
echo "Prochaines étapes:"
echo "1. Modifiez ServerName dans /etc/apache2/sites-available/glpi.conf"
echo "2. Accédez à http://votre-serveur/glpi pour l'installation web"
echo "3. Utilisez les identifiants de base de données:"
echo "   - Serveur: localhost"
echo "   - Base de données: ${GLPI_DB_NAME}"
echo "   - Utilisateur: ${GLPI_DB_USER}"
echo ""
echo "Identifiants par défaut GLPI:"
echo "   - glpi/glpi (Super-Admin)"
echo "   - tech/tech (Technicien)"
echo "   - normal/normal (Normal)"
echo "   - post-only/postonly (Post-only)"
echo ""
echo "IMPORTANT:"
echo "  - Changez tous les mots de passe par défaut"
echo "  - Supprimez /var/www/html/glpi/install après l'installation"
echo ""
