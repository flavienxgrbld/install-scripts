#!/usr/bin/env bash
set -euo pipefail

# Détection d'OS et gestionnaire de paquets
OS_ID=""
OS_NAME=""
OS_VERSION_ID=""
OS_ID_LIKE=""
PKG_MANAGER=""

error_exit() {
    echo "❌ ERREUR: $1" >&2
    exit 1
}

info() {
    echo "➡️  $1"
}

success() {
    echo "✅ $1"
}

warn() {
    echo "⚠️  $1"
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        error_exit "Commande requise introuvable: $1"
    fi
}

ensure_download_tool() {
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
        return 0
    fi

    info "Installation de curl pour le téléchargement de fichiers"
    pkg_install curl || pkg_install wget
}

ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "Ce script doit être exécuté en root"
    fi
}

# Detect OS from /etc/os-release
detect_os() {
    if [ ! -r /etc/os-release ]; then
        error_exit "Impossible de détecter l'OS : /etc/os-release absent"
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID=${ID,,}
    OS_NAME=${NAME:-$OS_ID}
    OS_VERSION_ID=${VERSION_ID:-}
    OS_ID_LIKE=${ID_LIKE:-}
}

is_debian_family() {
    case "${OS_ID} ${OS_ID_LIKE}" in
        *debian*|*ubuntu*) return 0 ;; 
        *) return 1 ;;
    esac
}

is_ubuntu() {
    [ "${OS_ID}" = "ubuntu" ]
}

is_redhat_family() {
    case "${OS_ID} ${OS_ID_LIKE}" in
        *rhel*|*fedora*|*centos*|*rocky*|*almalinux*|*amazonlinux*|*oraclelinux*) return 0 ;; 
        *) return 1 ;;
    esac
}

is_suse_family() {
    case "${OS_ID} ${OS_ID_LIKE}" in
        *suse*|*opensuse*) return 0 ;; 
        *) return 1 ;;
    esac
}

is_pacman_family() {
    [ "${OS_ID}" = "arch" ]
}

get_major_version() {
    local version="$1"
    printf '%s' "${version%%.*}"
}

# Detect package manager by availability
detect_package_manager() {
    if command -v apt >/dev/null 2>&1; then
        PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
    else
        error_exit "Aucun gestionnaire de paquets supporté détecté"
    fi
}

pkg_update() {
    case "$PKG_MANAGER" in
        apt)
            apt update
            ;;
        dnf)
            dnf makecache --refresh
            ;;
        yum)
            yum makecache
            ;;
        zypper)
            zypper refresh
            ;;
        pacman)
            pacman -Sy --noconfirm
            ;;
    esac
}

pkg_upgrade() {
    case "$PKG_MANAGER" in
        apt)
            apt upgrade -y
            ;;
        dnf)
            dnf upgrade -y
            ;;
        yum)
            yum update -y
            ;;
        zypper)
            zypper update -y
            ;;
        pacman)
            pacman -Syu --noconfirm
            ;;
    esac
}

pkg_install() {
    case "$PKG_MANAGER" in
        apt)
            apt install -y "$@"
            ;;
        dnf)
            dnf install -y "$@"
            ;;
        yum)
            yum install -y "$@"
            ;;
        zypper)
            zypper install -y "$@"
            ;;
        pacman)
            pacman -S --noconfirm "$@"
            ;;
    esac
}

pkg_remove() {
    case "$PKG_MANAGER" in
        apt)
            apt remove -y "$@"
            ;;
        dnf)
            dnf remove -y "$@"
            ;;
        yum)
            yum remove -y "$@"
            ;;
        zypper)
            zypper remove -y "$@"
            ;;
        pacman)
            pacman -R --noconfirm "$@"
            ;;
    esac
}

pkg_autoremove() {
    case "$PKG_MANAGER" in
        apt)
            apt autoremove -y
            ;;
        dnf)
            dnf autoremove -y
            ;;
        yum)
            yum autoremove -y
            ;;
        zypper)
            zypper clean --all
            ;;
        pacman)
            pacman -Rns --noconfirm $(pacman -Qdtq || true)
            ;;
    esac
}

service_enable() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable "$1"
    elif command -v chkconfig >/dev/null 2>&1; then
        chkconfig "$1" on
    else
        warn "Impossible d'activer le service $1 automatiquement"
    fi
}

service_restart() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart "$1"
    else
        service "$1" restart
    fi
}

service_is_active() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active --quiet "$1"
    else
        service "$1" status >/dev/null 2>&1
    fi
}

check_url() {
    ensure_download_tool
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1" >/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget --spider -q "$1"
    else
        error_exit "Ni curl ni wget n'est installé pour vérifier l'URL: $1"
    fi
}

download_file() {
    local url="$1"
    local dest="$2"

    ensure_download_tool
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$dest"
    else
        error_exit "Ni curl ni wget n'est installé pour télécharger: $url"
    fi
}

# Installation de PHP sur différents OS
install_php() {
    local php_version="${1:-8.2}"

    case "$PKG_MANAGER" in
        apt)
            # Pour Debian/Ubuntu, utiliser les dépôts Sury/Ondrej
            pkg_install lsb-release ca-certificates apt-transport-https software-properties-common gnupg2 curl wget

            if ! grep -q "sury\|ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
                info "Ajout du dépôt PHP pour ${OS_NAME}..."
                if is_ubuntu; then
                    add-apt-repository -y ppa:ondrej/php
                else
                    curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
                    dpkg -i /tmp/debsuryorg-archive-keyring.deb
                    rm -f /tmp/debsuryorg-archive-keyring.deb
                    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list
                fi
                pkg_update
            fi

            pkg_install "php${php_version}" "php${php_version}-cli" "php${php_version}-common" "php${php_version}-mysql" "php${php_version}-zip" "php${php_version}-gd" "php${php_version}-mbstring" "php${php_version}-curl" "php${php_version}-xml" "php${php_version}-bcmath" "php${php_version}-json" "php${php_version}-intl" "php${php_version}-fpm"
            ;;

        dnf)
            # Pour RHEL/CentOS/Fedora, utiliser les dépôts Remi
            pkg_install https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OS_VERSION_ID%%.*}.noarch.rpm || true
            pkg_install https://rpms.remirepo.net/enterprise/remi-release-${OS_VERSION_ID%%.*}.rpm || true

            if command -v dnf >/dev/null 2>&1; then
                dnf config-manager --set-enabled remi
                dnf module reset php -y
                dnf module enable php:remi-${php_version} -y
            fi

            pkg_install "php" "php-cli" "php-common" "php-mysqlnd" "php-zip" "php-gd" "php-mbstring" "php-curl" "php-xml" "php-bcmath" "php-json" "php-intl" "php-fpm"
            ;;

        yum)
            # Pour CentOS/RHEL 7
            pkg_install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm || true
            pkg_install https://rpms.remirepo.net/enterprise/remi-release-7.rpm || true

            yum-config-manager --enable remi remi-php${php_version//./} || true

            pkg_install "php" "php-cli" "php-common" "php-mysql" "php-zip" "php-gd" "php-mbstring" "php-curl" "php-xml" "php-bcmath" "php-json" "php-intl" "php-fpm"
            ;;

        zypper)
            # Pour SUSE
            pkg_install "php${php_version//./}" "php${php_version//./}-cli" "php${php_version//./}-mysql" "php${php_version//./}-zip" "php${php_version//./}-gd" "php${php_version//./}-mbstring" "php${php_version//./}-curl" "php${php_version//./}-xml" "php${php_version//./}-bcmath" "php${php_version//./}-json" "php${php_version//./}-intl" "php${php_version//./}-fpm"
            ;;

        pacman)
            # Pour Arch Linux
            pkg_install "php" "php-fpm" "php-gd" "php-intl" "php-mysqli"
            ;;
    esac
}

# Installation de MariaDB/MySQL sur différents OS
install_database() {
    case "$PKG_MANAGER" in
        apt)
            pkg_install mariadb-server mariadb-client
            service_enable mariadb
            service_restart mariadb
            ;;

        dnf)
            pkg_install mariadb-server mariadb
            service_enable mariadb
            service_restart mariadb
            ;;

        yum)
            pkg_install mariadb-server mariadb
            service_enable mariadb
            service_restart mariadb
            ;;

        zypper)
            pkg_install mariadb mariadb-client
            service_enable mysql
            service_restart mysql
            ;;

        pacman)
            pkg_install mariadb
            mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
            service_enable mariadb
            service_restart mariadb
            ;;
    esac
}

# Installation d'Apache/Nginx sur différents OS
install_webserver() {
    local webserver="${1:-apache}"

    case "$webserver" in
        apache)
            case "$PKG_MANAGER" in
                apt)
                    pkg_install apache2
                    service_enable apache2
                    service_restart apache2
                    ;;
                dnf)
                    pkg_install httpd
                    service_enable httpd
                    service_restart httpd
                    ;;
                yum)
                    pkg_install httpd
                    service_enable httpd
                    service_restart httpd
                    ;;
                zypper)
                    pkg_install apache2
                    service_enable apache2
                    service_restart apache2
                    ;;
                pacman)
                    pkg_install apache
                    service_enable httpd
                    service_restart httpd
                    ;;
            esac
            ;;

        nginx)
            case "$PKG_MANAGER" in
                apt)
                    pkg_install nginx
                    service_enable nginx
                    service_restart nginx
                    ;;
                dnf)
                    pkg_install nginx
                    service_enable nginx
                    service_restart nginx
                    ;;
                yum)
                    pkg_install nginx
                    service_enable nginx
                    service_restart nginx
                    ;;
                zypper)
                    pkg_install nginx
                    service_enable nginx
                    service_restart nginx
                    ;;
                pacman)
                    pkg_install nginx
                    service_enable nginx
                    service_restart nginx
                    ;;
            esac
            ;;
    esac
}

# Configuration de base de PHP pour GLPI/Zabbix
configure_php() {
    local php_ini="/etc/php/${1:-8.2}/cli/php.ini"
    local fpm_ini="/etc/php/${1:-8.2}/fpm/php.ini"

    # Configuration PHP commune
    for ini_file in "$php_ini" "$fpm_ini"; do
        if [ -f "$ini_file" ]; then
            # Augmenter les limites mémoire et temps d'exécution
            sed -i 's/memory_limit = .*/memory_limit = 256M/' "$ini_file" || true
            sed -i 's/max_execution_time = .*/max_execution_time = 600/' "$ini_file" || true
            sed -i 's/upload_max_filesize = .*/upload_max_filesize = 50M/' "$ini_file" || true
            sed -i 's/post_max_size = .*/post_max_size = 50M/' "$ini_file" || true
            sed -i 's/max_input_time = .*/max_input_time = 300/' "$ini_file" || true
        fi
    done

    # Redémarrer PHP-FPM si nécessaire
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart php*-fpm 2>/dev/null || true
    fi
}
