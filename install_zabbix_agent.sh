#!/bin/bash
set -euo pipefail

# Variables de configuration
ZABBIX_VERSION="7.4"
ZABBIX_DEB="zabbix-release_latest_${ZABBIX_VERSION}+debian13_all.deb"
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

grep -q "trixie" /etc/os-release || error_exit "Ce script est prévu pour Debian 13 (trixie)"

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
apt install -y zabbix-agent2 zabbix-agent2-plugin-*

success "Zabbix Agent 2 installé"

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

# Sauvegarde de la configuration originale
if [ -f "$ZABBIX_AGENT_CONF" ]; then
    cp "$ZABBIX_AGENT_CONF" "${ZABBIX_AGENT_CONF}.bak"
    info "Configuration originale sauvegardée"
fi

# Modification de la configuration
info "Application de la configuration"

sed -i "s/^Server=.*/Server=${ZABBIX_SERVER}/" "$ZABBIX_AGENT_CONF"
sed -i "s/^ServerActive=.*/ServerActive=${ZABBIX_SERVER_ACTIVE}/" "$ZABBIX_AGENT_CONF"
sed -i "s/^Hostname=.*/Hostname=${ZABBIX_HOSTNAME}/" "$ZABBIX_AGENT_CONF"

# Activation du mode actif par défaut
if ! grep -q "^ServerActive=" "$ZABBIX_AGENT_CONF"; then
    echo "ServerActive=${ZABBIX_SERVER_ACTIVE}" >> "$ZABBIX_AGENT_CONF"
fi

# Configuration des permissions
chown zabbix:zabbix "$ZABBIX_AGENT_CONF"
chmod 640 "$ZABBIX_AGENT_CONF"

success "Configuration appliquée"

# Démarrage et activation du service
info "Activation et démarrage de Zabbix Agent 2"
systemctl enable zabbix-agent2

if systemctl restart zabbix-agent2 && systemctl is-active --quiet zabbix-agent2; then
    success "Zabbix Agent 2 actif et en cours d'exécution"
else
    error_exit "Échec du démarrage de Zabbix Agent 2"
fi

# Vérification du statut
info "Vérification du statut"
sleep 2

if systemctl status zabbix-agent2 --no-pager | grep -q "active (running)"; then
    success "Service opérationnel"
else
    echo "⚠️ Le service semble avoir un problème"
    systemctl status zabbix-agent2 --no-pager
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
