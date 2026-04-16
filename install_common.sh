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
        *rhel*|*fedora*|*centos*|*rocky*|*almalinux*) return 0 ;; 
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

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$dest"
    else
        error_exit "Ni curl ni wget n'est installé pour télécharger: $url"
    fi
}
