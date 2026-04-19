# 📦 Install Scripts - Répertoire Complet

Une collection complète et organisée de **165+ scripts Bash** pour installer des solutions sur Linux.

## 📂 Structure du Répertoire

```
install-scripts/
├── install_common.sh           # Fonctions et utilitaires communs
├── analytics/                  # Analytics et données
├── backup/                     # Sauvegarde et archivage
├── business/                   # Solutions d'entreprise (ERP, CRM)
├── cms/                        # Systèmes de gestion de contenu
├── collaboration/              # Outils collaboratifs et communication
├── databases/                  # Bases de données
├── devops/                     # Outils DevOps et infrastructure
├── infrastructure/             # Infrastructure et réseaux
├── iot/                        # Internet des Objets
├── media/                      # Serveurs médias
├── monitoring/                 # Monitoring et alertes
└── security/                   # Sécurité
```

## 📊 Statistiques

- **Total de catégories**: 12
- **Total de scripts**: 165+
- **Distributions supportées**: Debian, Ubuntu, RHEL, CentOS, SUSE, Arch Linux, Alpine
- **Dernière mise à jour**: 2024

## 📋 Solutions Disponibles

### 🔐 Security (11 scripts)
- Certbot (SSL/TLS)
- OpenVPN (VPN)
- WireGuard (VPN moderne)
- Fail2ban (Protection brute-force)
- Pi-hole (Bloqueur DNS)
- Keycloak (Authentification)
- Vault (Gestion des secrets)
- Vaultwarden (Gestionnaire de mots de passe)

### 📊 Analytics (3 scripts)
- Matomo (Analytics respectueux)
- Open Web Analytics
- Plausible Analytics

### 💾 Backup (6 scripts)
- Restic (Sauvegarde chiffrée)
- Bacula (Enterprise backup)
- Duplicati (Sauvegarde distribuée)
- Rclone (Sync cloud)

### 💼 Business (7 scripts)
- Odoo (ERP/CRM complet)
- ERPNext (ERP modulaire)
- Dolibarr (ERP PME)
- Invoice Ninja (Facturation)
- Paperless-ngx (Gestion documents)
- Taiga (Project management)
- Akaunting (Comptabilité)

### 📝 CMS (9 scripts)
- WordPress
- Nextcloud
- Strapi (Headless CMS)
- Ghost (Blog)
- Moodle (LMS)
- Drupal
- MediaWiki
- DokuWiki
- Wallabag
- OwnCloud

### 👥 Collaboration (12 scripts)
- Rocket.Chat (Messaging)
- Mattermost (Communication)
- Gitea (Git service)
- Seafile (Partage fichiers)
- Zulip (Chat threads)
- Jitsi Meet (Visioconférence)
- Syncthing (Sync P2P)
- Mastodon (Réseau social)
- Discourse (Forum)
- Etherpad (Écriture collaborative)
- Matrix Synapse
- Nextcloud Talk
- Outline (Wiki moderne)
- Focalboard (Tableau blanc)

### 🗄️ Databases (4 scripts)
- PostgreSQL
- MongoDB
- Redis
- InfluxDB

### 🔧 DevOps (14 scripts)
- SonarQube (Code quality)
- GitLab Runner
- Jenkins
- Woodpecker CI
- Landscape
- Gitpod
- Gitlist
- RequestBin
- Penpot (Design)
- LocalStack
- Rustlings
- Hurl
- LuaJIT

### 🏗️ Infrastructure (15 scripts)
- Docker
- Portainer (Docker UI)
- Kubernetes
- Consul (Service mesh)
- Nomad (Orchestration)
- LXD (Conteneurs)
- Vault (Secrets)
- MinIO (S3 storage)
- Meilisearch (Search)
- Filebrowser (File manager)
- Typesense (Search)
- Guacamole (RDP/SSH/VNC)
- Rustdesk (Bureau distant)
- DNSmasq (DNS/DHCP)
- Nginx UI
- HAProxy
- Nginx
- Apache
- Hyperledger Fabric
- Seaweedfs

### 🏠 IoT (3 scripts)
- Home Assistant
- Node-RED
- openHAB
- Mosquitto (MQTT)

### 🎬 Media (6 scripts)
- Jellyfin
- Plex
- Emby
- Kodi
- Immich

### 📈 Monitoring (12 scripts)
- Prometheus
- Grafana
- Zabbix Server/Agent
- Loki (Log aggregation)
- Netdata (Real-time)
- ELK Stack
- Alertmanager
- Sentry
- TIG Stack
- Cacti
- ntopng
- Uptime Kuma

## 🚀 Utilisation Rapide

### Installation d'une solution

```bash
# Rendre le script exécutable
chmod +x infrastructure/install_docker.sh

# Exécuter le script
sudo ./infrastructure/install_docker.sh

# Ou directement
sudo bash infrastructure/install_docker.sh
```

### Voir toutes les solutions disponibles

```bash
# Lister tous les scripts
ls -la */*.sh

# Lister par catégorie
ls -la infrastructure/
ls -la monitoring/
```

### Installation multiple

```bash
# Installation de Docker et Portainer
sudo ./infrastructure/install_docker.sh
sudo ./infrastructure/install_portainer.sh

# Installation de Zabbix avec agent
sudo ./monitoring/install_zabbix.sh
sudo ./monitoring/install_zabbix_agent.sh
```

## ⚙️ Utilisation des Fonctions Communes

Tous les scripts utilisent les fonctions de `install_common.sh`:

```bash
. "$SCRIPT_DIR/../install_common.sh"

# Fonctions disponibles:
ensure_root                    # Vérifier accès root
detect_os                      # Détecter le système
detect_package_manager         # Détecter le gestionnaire de paquets
pkg_update                     # Mettre à jour les paquets
pkg_install <app>            # Installer un paquet
service_enable <service>       # Activer un service
service_restart <service>      # Redémarrer un service
```

## 📋 Distributions Supportées

Chaque script supporte automatiquement:

- ✅ **Debian/Ubuntu** (apt)
- ✅ **RHEL/CentOS/Fedora** (dnf/yum)
- ✅ **SUSE** (zypper)
- ✅ **Arch Linux** (pacman)
- ✅ **Alpine** (apk - support partiel)
- ✅ **Autres variantes** (Ubuntu, Raspberry Pi OS, etc.)

## 🔒 Sécurité

- Tous les scripts incluent des vérifications d'erreur
- Utilisation de `set -euo pipefail` pour la sécurité bash
- Vérification des accès root
- Configuration de pare-feu UFW quand applicable

## 📝 Notes d'Installation

### Avant d'installer

1. **Vérifier la compatibilité**: Certaines solutions nécessitent Docker, Kubernetes, etc.
2. **Ressources**: Vérifiez que votre système a assez de ressources CPU/RAM
3. **Ports**: Vérifiez que les ports nécessaires ne sont pas utilisés
4. **Firewall**: Les scripts configurent automatiquement UFW si présent

### Après l'installation

1. **Accédez à l'interface web**: Voir l'URL affichée en fin d'installation
2. **Configuration**: Certains services nécessitent une configuration post-installation
3. **Certificats SSL**: Utilisez Let's Encrypt/Certbot pour sécuriser les connexions
4. **Sauvegardes**: Mettez en place une stratégie de sauvegarde

## 🛠️ Dépannage

### Script bloqué

Assurez-vous que l'exécution et que vous pouvez vous connecter à Internet pour télécharger les paquets.

### Services ne démarrent pas

```bash
# Vérifier le statut des services
sudo systemctl status <service-name>

# Voir les logs et les erreurs
sudo journalctl -u <service-name> -n 50
```

### Ports en conflit

Les scripts affichent les ports utilisés. Vérifiez avec:

```bash
sudo netstat -tulpn | grep LISTEN
```

## 📚 Documentation

Chaque script contient des commentaires documentant:
- La solution et ses fonctionnalités
- Les ports utilisés
- Les prérequis
- Les étapes post-installation

## 🤝 Contribution

Pour ajouter un nouveau script:

1. Créez le fichier dans la catégorie appropriée
2. Utilisez le modèle commençant avec le header standard
3. Incluez les fonctions de `install_common.sh`
4. Documentez les ports et prérequis

## 📄 Licence

Ces scripts sont fournis à titre d'exemple. Utilisez-les à vos risques et périls.

## 🎯 Objectif

Fournir une bibliothèque centralisée de scripts d'installation pour les solutions open-source courantes, automatisant les tâches d'infrastructure communes.

## ✨ Avantages

- ✅ Scripts multi-distributions
- ✅ Gestion d'erreurs robuste
- ✅ Fonctions réutilisables
- ✅ Configuration de pare-feu automatique
- ✅ Support de plus de 100 solutions
- ✅ Structure organisée et cohérente
- ✅ Maintenance centralisée

---

**Démarrez**: `sudo bash infrastructure/install_docker.sh`
