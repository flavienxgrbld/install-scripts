#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/install_common.sh"

# Variables de configuration
ZABBIX_VERSION="7.4"
ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"
TMP_DIR="/tmp/zabbix_install_$$"

cleanup() {
    [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
    unset MYSQL_ROOT_PASS ZBX_DB_PASS ZBX_DB_PASS_CONFIRM 2>/dev/null || true
}

trap cleanup EXIT

ensure_root
detect_os
detect_package_manager

info "Détection de l'OS : ${OS_NAME} ${OS_VERSION_ID}"
if ! is_debian_family; then
    error_exit "Ce script prend en charge principalement Debian/Ubuntu pour l'instant"
fi

DEBIAN_VERSION="${OS_VERSION_ID%%.*}"
ZABBIX_DEB="zabbix-release_latest_${ZABBIX_VERSION}+debian${DEBIAN_VERSION}_all.deb"
ZABBIX_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/debian/pool/main/z/zabbix-release/${ZABBIX_DEB}"

info "Vérification de la connectivité HTTPS vers repo.zabbix.com"
check_url "https://repo.zabbix.com"

success "Environnement validé"


info "Mise à jour du système"
pkg_update
pkg_upgrade
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin





info "Installation du dépôt Zabbix ${ZABBIX_VERSION}"
if ! dpkg -l | grep -q zabbix-release; then
    mkdir -p "$TMP_DIR"
    download_file "$ZABBIX_URL" "${TMP_DIR}/${ZABBIX_DEB}"
    dpkg -i "${TMP_DIR}/${ZABBIX_DEB}"
    pkg_update
else
    info "Dépôt Zabbix déjà installé"
fi


info "Installation des paquets Zabbix et MariaDB"
pkg_install \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-apache-conf \
    zabbix-sql-scripts \
    zabbix-agent \
    mariadb-server

success "Paquets installés"


info "Sécurisation automatique de MariaDB"
read -sp "Mot de passe root MariaDB à définir : " MYSQL_ROOT_PASS
echo

# Sécurisation automatique de MySQL
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';" 2>/dev/null || \
    mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MYSQL_ROOT_PASS}');"

mysql -u root -p"$MYSQL_ROOT_PASS" <<EOSQL
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOSQL

success "MariaDB sécurisé automatiquement"

# Validation de la connexion MySQL
if ! mysql -u root -p"$MYSQL_ROOT_PASS" -e "SELECT 1;" &>/dev/null; then
    error_exit "Impossible de se connecter à MariaDB avec ce mot de passe"
fi

while true; do
    read -sp "Mot de passe utilisateur SQL zabbix : " ZBX_DB_PASS
    echo
    [ -n "$ZBX_DB_PASS" ] || { echo "❌ Le mot de passe ne peut pas être vide"; continue; }
    read -sp "Confirmation : " ZBX_DB_PASS_CONFIRM
    echo
    [ "$ZBX_DB_PASS" = "$ZBX_DB_PASS_CONFIRM" ] && break
    echo "❌ Les mots de passe ne correspondent pas"
done

info "Création et configuration de la base Zabbix"
mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF || error_exit "Échec de la création de la base de données"
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${ZBX_DB_PASS}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
EOF

info "Import du schéma Zabbix (peut être long)"
if zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | \
   mysql --default-character-set=utf8mb4 -u zabbix -p"$ZBX_DB_PASS" zabbix; then
    mysql -u root -p"$MYSQL_ROOT_PASS" -e "SET GLOBAL log_bin_trust_function_creators = 0;" || true
    success "Base de données prête"
else
    error_exit "Échec de l'import du schéma Zabbix"
fi


info "Configuration de zabbix_server.conf"

if grep -q "^DBPassword=" "$ZABBIX_CONF"; then
    sed -i "s|^DBPassword=.*|DBPassword=${ZBX_DB_PASS}|" "$ZABBIX_CONF"
else
    echo "DBPassword=${ZBX_DB_PASS}" >> "$ZABBIX_CONF"
fi

chown zabbix:zabbix "$ZABBIX_CONF"
chmod 640 "$ZABBIX_CONF"

info "Redémarrage et activation des services"
systemctl enable zabbix-server zabbix-agent apache2

SERVICES_OK=true
for svc in zabbix-server zabbix-agent apache2; do
    if systemctl restart "$svc" && systemctl is-active --quiet "$svc"; then
        success "$svc actif"
    else
        echo "⚠️ $svc inactif ou échec du redémarrage"
        SERVICES_OK=false
    fi
done

[ "$SERVICES_OK" = true ] || error_exit "Certains services ont échoué"

info "Vérification de l'interface Web (attente 5 secondes)"
sleep 5
if curl -fs http://localhost/zabbix >/dev/null; then
    success "Interface Web accessible"
else
    echo "⚠️ Interface Web non accessible - vérifier Apache/PHP"
fi


echo
echo "============================================"
echo "🎉 INSTALLATION ZABBIX TERMINÉE"
echo "============================================"
echo "URL : http://IP_DU_SERVEUR/zabbix"
echo "Login : Admin"
echo "Mot de passe : zabbix"
echo "============================================"
