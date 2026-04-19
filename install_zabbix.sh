#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/install_common.sh"

# Variables de configuration
ZABBIX_VERSION="7.4"
ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"
TMP_DIR="/tmp/zabbix_install_$$"

get_repo_base_path() {
    case "$1" in
        ubuntu) echo "ubuntu" ;;
        debian) echo "debian" ;;
        raspbian) echo "raspbian" ;;
        centos) echo "centos" ;;
        rhel) echo "rhel" ;;
        ol|oraclelinux|oracle) echo "oracle" ;;
        rocky) echo "rocky" ;;
        almalinux) echo "alma" ;;
        amazonlinux) echo "amazonlinux" ;;
        sles|opensuse) echo "sles" ;;
        arch) echo "arch" ;;
        *) return 1 ;;
    esac
}

get_zabbix_repo_package() {
    local os_id="$1"
    local major="$2"
    local codename="${3:-}"

    case "$os_id" in
        ubuntu)
            if [ -n "$codename" ]; then
                printf 'zabbix-release_latest_%s+ubuntu%s_all.deb' "$ZABBIX_VERSION" "$codename"
            else
                printf 'zabbix-release_latest_%s+ubuntu%s_all.deb' "$ZABBIX_VERSION" "$major"
            fi
            ;;
        debian)
            printf 'zabbix-release_latest_%s+debian%s_all.deb' "$ZABBIX_VERSION" "$major"
            ;;
        raspbian)
            printf 'zabbix-release_latest_%s+raspbian%s_all.deb' "$ZABBIX_VERSION" "$major"
            ;;
        centos|rhel|ol|oraclelinux|oracle|rocky|almalinux)
            printf 'zabbix-release-latest.el%s.noarch.rpm' "$major"
            ;;
        amazonlinux)
            printf 'zabbix-release-latest.amzn%s.noarch.rpm' "$major"
            ;;
        sles|opensuse)
            printf 'zabbix-release-latest.sles%s.noarch.rpm' "$major"
            ;;
        arch)
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

configure_zabbix_repository() {
    local os_path
    local repo_pkg
    local os_major

    os_path="$(get_repo_base_path "$OS_ID")" || return 1
    os_major="${OS_VERSION_ID%%.*}"

    if [ "$os_path" = "arch" ]; then
        info "Pas de dépôt Zabbix externe requis pour Arch Linux"
        return 0
    fi

    repo_pkg="$(get_zabbix_repo_package "$OS_ID" "$os_major" "${VERSION_CODENAME:-}")" || return 1

    if printf '%s' "$repo_pkg" | grep -q '\.deb$'; then
        ZABBIX_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/${os_path}/pool/main/z/zabbix-release/${repo_pkg}"
        ZABBIX_PACKAGE="${repo_pkg}"
        if ! dpkg-query -W -f='${Status}' zabbix-release 2>/dev/null | grep -q "install ok installed"; then
            mkdir -p "$TMP_DIR"
            download_file "$ZABBIX_URL" "${TMP_DIR}/${ZABBIX_PACKAGE}"
            dpkg -i "${TMP_DIR}/${ZABBIX_PACKAGE}"
            pkg_update
        else
            info "Dépôt Zabbix déjà installé"
        fi
        return 0
    fi

    if printf '%s' "$repo_pkg" | grep -q '\.rpm$'; then
        ZABBIX_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/${os_path}/${os_major}/noarch/${repo_pkg}"
        ZABBIX_PACKAGE="${repo_pkg}"
        if ! rpm -q zabbix-release >/dev/null 2>&1; then
            mkdir -p "$TMP_DIR"
            download_file "$ZABBIX_URL" "${TMP_DIR}/${ZABBIX_PACKAGE}"
            rpm -Uvh "${TMP_DIR}/${ZABBIX_PACKAGE}"
            pkg_update
        else
            info "Dépôt Zabbix déjà installé"
        fi
        return 0
    fi

    return 1
}

cleanup() {
    [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
    unset MYSQL_ROOT_PASS ZBX_DB_PASS ZBX_DB_PASS_CONFIRM 2>/dev/null || true
}

trap cleanup EXIT

ensure_root
detect_os
detect_package_manager

info "Détection de l'OS : ${OS_NAME} ${OS_VERSION_ID}"
if ! is_debian_family && ! is_redhat_family && ! is_suse_family && ! is_pacman_family; then
    error_exit "Ce script prend en charge Debian/Ubuntu/Raspbian, RHEL/CentOS/Oracle/Alma/Rocky/AmazonLinux, SUSE et Arch Linux"
fi

info "Vérification de la connectivité HTTPS vers repo.zabbix.com"
check_url "https://repo.zabbix.com"

success "Environnement validé"

info "Mise à jour du système"
pkg_update
pkg_upgrade
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

# Installation du dépôt Zabbix
info "Installation du dépôt Zabbix ${ZABBIX_VERSION}"
if ! configure_zabbix_repository; then
    error_exit "Impossible de configurer le dépôt Zabbix pour ${OS_NAME}"
fi

# Installation de PHP et MariaDB
info "Installation de PHP et MariaDB"
install_php "8.2"
install_database
configure_php "8.2"

# Installation du serveur web
info "Installation du serveur web"
install_webserver "apache"

info "Installation des paquets Zabbix"
pkg_install \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-sql-scripts \
    zabbix-agent

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
