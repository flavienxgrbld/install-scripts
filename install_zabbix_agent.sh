#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/install_common.sh"

# Variables de configuration
ZABBIX_VERSION="7.4"
ZABBIX_AGENT_CONF="/etc/zabbix/zabbix_agent2.conf"
TMP_DIR="/tmp/zabbix_agent_install_$$"

cleanup() {
    [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}

trap cleanup EXIT

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

# Mise à jour du système
info "Mise à jour du système"
pkg_update
pkg_upgrade
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

# Installation du dépôt Zabbix
info "Installation du dépôt Zabbix ${ZABBIX_VERSION}"
if ! configure_zabbix_repository; then
    error_exit "Impossible de configurer le dépôt Zabbix pour ${OS_NAME}"
fi

# Installation de l'agent Zabbix 2
info "Installation de Zabbix Agent 2"
pkg_install zabbix-agent2

success "Zabbix Agent 2 installé"

# Suppression des plugins optionnels qui peuvent causer des problèmes
info "Suppression des plugins optionnels installés"
pkg_remove zabbix-agent2-plugin-nvidia-gpu 2>/dev/null || true
pkg_autoremove 2>/dev/null || true

# Configuration de l'agent
info "Configuration de l'agent Zabbix"

# Demande des paramètres de configuration
echo
read -p "Adresse IP du serveur Zabbix : " ZABBIX_SERVER
[ -n "$ZABBIX_SERVER" ] || error_exit "L'adresse du serveur Zabbix est obligatoire"

read -p "Adresse IP du serveur Zabbix (actif) [${ZABBIX_SERVER}] : " ZABBIX_SERVER_ACTIVE
ZABBIX_SERVER_ACTIVE=${ZABBIX_SERVER_ACTIVE:-$ZABBIX_SERVER}

read -p "Nom d'hôte de cet agent [$(hostname)] : " ZABBIX_HOSTNAME
ZABBIX_HOSTNAME=${ZABBIX_HOSTNAME:-$(hostname)}

read -p "Adresse IP d'écoute de l'agent [0.0.0.0] : " LISTEN_IP
LISTEN_IP=${LISTEN_IP:-0.0.0.0}

read -p "Port d'écoute de l'agent [10050] : " LISTEN_PORT
LISTEN_PORT=${LISTEN_PORT:-10050}

# Sauvegarde de la configuration originale
if [ -f "$ZABBIX_AGENT_CONF" ]; then
    cp "$ZABBIX_AGENT_CONF" "${ZABBIX_AGENT_CONF}.bak"
    info "Configuration originale sauvegardée"
fi

# Modification de la configuration
info "Application de la configuration"

# Fonction pour configurer un paramètre (décommente et modifie)
configure_param() {
    local param=$1
    local value=$2
    local conf=$3
    
    # Supprime les anciennes lignes (commentées ou non)
    sed -i "/^[#[:space:]]*${param}=/d" "$conf"
    # Ajoute la nouvelle ligne
    echo "${param}=${value}" >> "$conf"
}

configure_param "Server" "${ZABBIX_SERVER}" "$ZABBIX_AGENT_CONF"
configure_param "ServerActive" "${ZABBIX_SERVER_ACTIVE}" "$ZABBIX_AGENT_CONF"
configure_param "Hostname" "${ZABBIX_HOSTNAME}" "$ZABBIX_AGENT_CONF"
configure_param "ListenIP" "${LISTEN_IP}" "$ZABBIX_AGENT_CONF"
configure_param "ListenPort" "${LISTEN_PORT}" "$ZABBIX_AGENT_CONF"

# Désactivation des plugins optionnels qui peuvent causer des problèmes
info "Désactivation des plugins optionnels"

# Désactivation des configurations de plugins problématiques
PLUGINS_DIR="/etc/zabbix/zabbix_agent2.d/plugins.d"
if [ -d "$PLUGINS_DIR" ]; then
    # Désactiver le plugin NVIDIA s'il existe
    if [ -f "$PLUGINS_DIR/nvidia.conf" ]; then
        mv "$PLUGINS_DIR/nvidia.conf" "$PLUGINS_DIR/nvidia.conf.disabled" 2>/dev/null || true
        info "Plugin NVIDIA désactivé"
    fi
fi

cat >> "$ZABBIX_AGENT_CONF" <<EOF

# Plugins désactivés (peuvent causer des erreurs si les dépendances ne sont pas présentes)
Plugins.SystemRun.LogRemoteCommands=0
EOF

# Configuration des permissions
chown zabbix:zabbix "$ZABBIX_AGENT_CONF"
chmod 640 "$ZABBIX_AGENT_CONF"

success "Configuration appliquée"

# Vérification de la syntaxe de la configuration
info "Vérification de la configuration"
if zabbix_agent2 -t agent.ping 2>&1 | grep -q "NOTSUPPORTED"; then
    info "Configuration validée par zabbix_agent2"
elif zabbix_agent2 -c "$ZABBIX_AGENT_CONF" -T 2>/dev/null; then
    info "Syntaxe de la configuration correcte"
else
    echo "⚠️ Attention: impossible de valider la configuration"
fi

# Démarrage et activation du service
info "Activation et démarrage de Zabbix Agent 2"
systemctl enable zabbix-agent2
systemctl restart zabbix-agent2

# Attente du démarrage
sleep 3

# Vérification détaillée du statut
if systemctl is-active --quiet zabbix-agent2; then
    success "Zabbix Agent 2 actif et en cours d'exécution"
    success "Service opérationnel"
else
    echo "❌ Le service n'a pas démarré correctement"
    echo
    echo "=== DIAGNOSTIC DU PROBLÈME ==="
    echo
    echo "--- Test manuel du démarrage ---"
    if /usr/sbin/zabbix_agent2 -c "$ZABBIX_AGENT_CONF" -t agent.ping 2>&1 | head -20; then
        echo "Test agent.ping réussi"
    else
        echo "Échec du test agent.ping"
    fi
    echo
    echo "--- Logs du service (dernières 30 lignes) ---"
    journalctl -u zabbix-agent2 --no-pager --lines=30
    echo
    echo "--- Configuration active (sans commentaires) ---"
    grep -E '^[^#]' "$ZABBIX_AGENT_CONF" | grep -v '^$'
    echo
    echo "--- Statut du service ---"
    systemctl status zabbix-agent2 --no-pager --full
    echo
    echo "--- Test de validation de la config ---"
    /usr/sbin/zabbix_agent2 -c "$ZABBIX_AGENT_CONF" -T
    echo
    error_exit "Échec du démarrage de Zabbix Agent 2 - diagnostic ci-dessus"
fi

# Affichage des informations de configuration
echo
echo "============================================"
echo "🎉 INSTALLATION ZABBIX AGENT 2 TERMINÉE"
echo "============================================"
echo "Configuration :"
echo "  - Serveur Zabbix    : ${ZABBIX_SERVER}"
echo "  - Serveur actif     : ${ZABBIX_SERVER_ACTIVE}"
echo "  - Nom d'hôte        : ${ZABBIX_HOSTNAME}"
echo "  - IP d'écoute       : ${LISTEN_IP}"
echo "  - Port d'écoute     : ${LISTEN_PORT}"
echo "  - Fichier de config : ${ZABBIX_AGENT_CONF}"
echo "  - Version           : Zabbix ${ZABBIX_VERSION}"
echo "============================================"
echo
echo "Pour ajouter cet agent au serveur Zabbix :"
echo "  1. Connectez-vous à l'interface Zabbix"
echo "  2. Allez dans Configuration > Hôtes"
echo "  3. Créez un nouvel hôte avec le nom : ${ZABBIX_HOSTNAME}"
echo "  4. Ajoutez l'interface agent avec l'IP de cette machine"
echo "============================================"
echo
echo "Commandes utiles :"
echo "  - Statut : systemctl status zabbix-agent2"
echo "  - Logs   : journalctl -u zabbix-agent2 -f"
echo "  - Config : cat ${ZABBIX_AGENT_CONF}"
echo "============================================"
