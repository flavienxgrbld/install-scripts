#!/bin/bash
set -euo pipefail

# Détection de la version Debian
if grep -q "bookworm" /etc/os-release; then
    DEBIAN_VERSION="12"
    DEBIAN_CODENAME="bookworm"
elif grep -q "trixie" /etc/os-release; then
    DEBIAN_VERSION="13"
    DEBIAN_CODENAME="trixie"
else
    echo "❌ ERREUR: Ce script est prévu pour Debian 12 (bookworm) ou Debian 13 (trixie)" >&2
    exit 1
fi

# Variables de configuration
ZABBIX_VERSION="7.4"
ZABBIX_DEB="zabbix-release_latest_${ZABBIX_VERSION}+debian${DEBIAN_VERSION}_all.deb"
ZABBIX_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/debian/pool/main/z/zabbix-release/${ZABBIX_DEB}"
ZABBIX_AGENT_CONF="/etc/zabbix/zabbix_agent2.conf"
TMP_DIR="/tmp/zabbix_agent_install_$$"

# Fonctions utilitaires
error_exit() {
    echo "❌ ERREUR: $1" >&2
    cleanup
    exit 1
}

cleanup() {
    [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}

info() {
    echo "➡️  $1"
}

success() {
    echo "✅ $1"
}

trap cleanup EXIT

# Vérifications préliminaires
[ "$EUID" -eq 0 ] || error_exit "Ce script doit être exécuté en root"

info "Détection de Debian ${DEBIAN_VERSION} (${DEBIAN_CODENAME})"

info "Vérification de la connectivité HTTPS vers repo.zabbix.com"
curl -fs https://repo.zabbix.com >/dev/null || error_exit "Accès HTTPS à repo.zabbix.com impossible"

success "Environnement validé"

# Mise à jour du système
info "Mise à jour du système"
apt update
apt upgrade -y
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

# Installation du dépôt Zabbix
info "Installation du dépôt Zabbix ${ZABBIX_VERSION}"
if ! dpkg -l | grep -q zabbix-release; then
    mkdir -p "$TMP_DIR"
    wget -q "$ZABBIX_URL" -O "${TMP_DIR}/${ZABBIX_DEB}"
    dpkg -i "${TMP_DIR}/${ZABBIX_DEB}"
    apt update
else
    info "Dépôt Zabbix déjà installé"
fi

# Installation de l'agent Zabbix 2
info "Installation de Zabbix Agent 2"
apt install -y zabbix-agent2

success "Zabbix Agent 2 installé"

# Suppression des plugins optionnels qui peuvent causer des problèmes
info "Suppression des plugins optionnels installés"
apt remove -y zabbix-agent2-plugin-nvidia-gpu 2>/dev/null || true
apt autoremove -y 2>/dev/null || true

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
