#!/usr/bin/env bash

# Script d'installation de BookStack sur tous les OS supportés

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
BOOKSTACK_VERSION="latest"
BOOKSTACK_DB_NAME="bookstack"
BOOKSTACK_DB_USER="bookstack"
PHP_MIN_VERSION="8.1"
BOOKSTACK_ADMIN_EMAIL="admin@example.com"
BOOKSTACK_APP_KEY=""

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
    echo "ERREUR: PHP $PHP_INSTALLED_VERSION est installé mais BookStack requiert PHP $PHP_MIN_VERSION minimum"
    exit 1
fi

echo "✓ PHP $PHP_INSTALLED_VERSION est compatible avec BookStack"

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
        pkg_install php${PHP_MIN_VERSION//./}-mysql php${PHP_MIN_VERSION//./}-gd php${PHP_MIN_VERSION//./}-curl php${PHP_MIN_VERSION//./}-zip php${PHP_MIN_VERSION//./}-dom php${PHP_MIN_VERSION//./}-mbstring php${PHP_MIN_VERSION//./}-xml php${PHP_MIN_VERSION//./}-simplexml php${PHP_MIN_VERSION//./}-xmlwriter php${PHP_MIN_VERSION//./}-tokenizer php${PHP_MIN_VERSION//./}-fileinfo php${PHP_MIN_VERSION//./}-iconv php${PHP_MIN_VERSION//./}-tidy
        ;;
    dnf|yum)
        pkg_install php-mysqlnd php-gd php-curl php-zip php-dom php-mbstring php-xml php-simplexml php-xmlwriter php-tokenizer php-fileinfo php-iconv php-tidy
        ;;
    zypper)
        pkg_install php${PHP_MIN_VERSION//./}-mysql php${PHP_MIN_VERSION//./}-gd php${PHP_MIN_VERSION//./}-curl php${PHP_MIN_VERSION//./}-zip php${PHP_MIN_VERSION//./}-dom php${PHP_MIN_VERSION//./}-mbstring php${PHP_MIN_VERSION//./}-xml php${PHP_MIN_VERSION//./}-simplexml php${PHP_MIN_VERSION//./}-xmlwriter php${PHP_MIN_VERSION//./}-tokenizer php${PHP_MIN_VERSION//./}-fileinfo php${PHP_MIN_VERSION//./}-iconv php${PHP_MIN_VERSION//./}-tidy
        ;;
    pacman)
        pkg_install php-gd php-intl php-sqlite
        ;;
esac

# Installation d'outils supplémentaires
echo "=== Installation d'outils supplémentaires ==="
pkg_install wget unzip curl git composer

# Configuration de MariaDB
echo "=== Configuration de MariaDB ==="
read -sp "Entrez le mot de passe root MySQL à définir: " MYSQL_ROOT_PASS
echo
read -sp "Entrez le mot de passe pour l'utilisateur BookStack (DB): " BOOKSTACK_DB_PASS
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

# Création de la base de données BookStack
mysql -uroot -p"${MYSQL_ROOT_PASS}" <<EOSQL
CREATE DATABASE ${BOOKSTACK_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${BOOKSTACK_DB_USER}'@'localhost' IDENTIFIED BY '${BOOKSTACK_DB_PASS}';
GRANT ALL PRIVILEGES ON ${BOOKSTACK_DB_NAME}.* TO '${BOOKSTACK_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOSQL

echo "✓ Base de données BookStack créée"

# Téléchargement et installation de BookStack
echo "=== Téléchargement et installation de BookStack ==="
cd /tmp

if [ "$BOOKSTACK_VERSION" = "latest" ]; then
    BOOKSTACK_URL="https://github.com/BookStackApp/BookStack/archive/master.zip"
    BOOKSTACK_DIR="BookStack-master"
else
    BOOKSTACK_URL="https://github.com/BookStackApp/BookStack/archive/v${BOOKSTACK_VERSION}.zip"
    BOOKSTACK_DIR="BookStack-${BOOKSTACK_VERSION}"
fi

wget "$BOOKSTACK_URL" -O bookstack.zip
unzip bookstack.zip
rm bookstack.zip

# Déplacement vers /var/www
if [ -d "/var/www/bookstack" ]; then
    mv "/var/www/bookstack" "/var/www/bookstack.bak.$(date +%Y%m%d_%H%M%S)"
fi

mv "$BOOKSTACK_DIR" /var/www/bookstack
chown -R www-data:www-data /var/www/bookstack 2>/dev/null || chown -R apache:apache /var/www/bookstack 2>/dev/null || chown -R nginx:nginx /var/www/bookstack

cd /var/www/bookstack

# Installation des dépendances PHP avec Composer
echo "=== Installation des dépendances PHP ==="
composer install --no-dev --optimize-autoloader

# Génération de la clé d'application
BOOKSTACK_APP_KEY=$(php artisan key:generate --show)

# Configuration de l'environnement
echo "=== Configuration de BookStack ==="
cat > .env <<EOF
APP_NAME="BookStack"
APP_ENV=production
APP_KEY=${BOOKSTACK_APP_KEY}
APP_DEBUG=false
APP_URL=http://localhost

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=${BOOKSTACK_DB_NAME}
DB_USERNAME=${BOOKSTACK_DB_USER}
DB_PASSWORD=${BOOKSTACK_DB_PASS}

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=log
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="${BOOKSTACK_ADMIN_EMAIL}"
MAIL_FROM_NAME="BookStack"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
EOF

# Configuration des permissions
echo "=== Configuration des permissions ==="
mkdir -p storage/logs
mkdir -p storage/uploads
mkdir -p storage/app
mkdir -p bootstrap/cache

chmod -R 755 storage
chmod -R 755 bootstrap/cache
chmod -R 755 public/uploads

# Migration de la base de données
echo "=== Migration de la base de données ==="
php artisan migrate --force

# Création d'un utilisateur administrateur
echo "=== Création de l'utilisateur administrateur ==="
read -p "Nom d'utilisateur administrateur BookStack: " BOOKSTACK_ADMIN_USER
read -sp "Mot de passe administrateur BookStack: " BOOKSTACK_ADMIN_PASS
echo

php artisan bookstack:create-admin-user --email="$BOOKSTACK_ADMIN_EMAIL" --name="$BOOKSTACK_ADMIN_USER" --password="$BOOKSTACK_ADMIN_PASS"

# Configuration Apache
echo "=== Configuration Apache ==="
cat > /etc/apache2/sites-available/bookstack.conf <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/bookstack/public

    <Directory /var/www/bookstack/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/bookstack_error.log
    CustomLog \${APACHE_LOG_DIR}/bookstack_access.log combined
</VirtualHost>
EOF

# Activation du site et des modules nécessaires
a2ensite bookstack.conf 2>/dev/null || true
a2enmod rewrite 2>/dev/null || true

# Configuration PHP pour BookStack
echo "=== Configuration PHP pour BookStack ==="
PHP_INI_FILE="/etc/php/${PHP_MIN_VERSION}/apache2/php.ini"
if [ -f "$PHP_INI_FILE" ]; then
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 50M/' "$PHP_INI_FILE"
    sed -i 's/post_max_size = .*/post_max_size = 50M/' "$PHP_INI_FILE"
    sed -i 's/memory_limit = .*/memory_limit = 256M/' "$PHP_INI_FILE"
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI_FILE"
fi

# Redémarrage des services
echo "=== Redémarrage des services ==="
systemctl restart apache2 2>/dev/null || systemctl restart httpd 2>/dev/null || systemctl restart nginx
systemctl restart mariadb 2>/dev/null || systemctl restart mysql

echo
echo "============================================"
echo "🎉 BOOKSTACK INSTALLÉ AVEC SUCCÈS"
echo "============================================"
echo "URL d'accès : http://votre-serveur"
echo "Utilisateur admin : ${BOOKSTACK_ADMIN_USER}"
echo "Email admin : ${BOOKSTACK_ADMIN_EMAIL}"
echo "Mot de passe admin : ${BOOKSTACK_ADMIN_PASS}"
echo
echo "Base de données :"
echo "  - Nom : ${BOOKSTACK_DB_NAME}"
echo "  - Utilisateur : ${BOOKSTACK_DB_USER}"
echo "  - Mot de passe : ${BOOKSTACK_DB_PASS}"
echo
echo "Actions recommandées :"
echo "  1. Configurer HTTPS (Let's Encrypt recommandé)"
echo "  2. Configurer les sauvegardes automatiques"
echo "  3. Personnaliser les paramètres (thème, langues, etc.)"
echo "  4. Configurer SMTP pour les notifications"
echo "  5. Installer des extensions supplémentaires"
echo
echo "Commandes utiles :"
echo "  - Artisan : cd /var/www/bookstack && php artisan --help"
echo "  - Logs : tail -f storage/logs/laravel.log"
echo "  - Permissions : chown -R www-data:www-data /var/www/bookstack"
echo "============================================"