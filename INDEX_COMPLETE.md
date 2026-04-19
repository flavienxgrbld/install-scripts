# 📋 Index Complet - Install Scripts Collection

## 🎯 Résumé Général

**Collection de 165+ scripts Bash pour installer des solutions open-source sur Linux**

- ✅ Support multi-distribution (Debian, Ubuntu, RHEL, CentOS, SUSE, Arch)
- ✅ Scripts résistants aux erreurs
- ✅ Gestion automatique du pare-feu
- ✅ 12 catégories organisées
- ✅ Fonctions communes réutilisables

---

## 📂 Catégories et Contenu

### 1️⃣ **ANALYTICS** (3 scripts)
Analyse de données et Web Analytics

```
├── install_matomo.sh              → Matomo (Analytics respectueux)
├── install_plausible.sh           → Plausible (Privacy-first)
└── install_open_web_analytics.sh  → Open Web Analytics
```

**Cas d'usage**: Remplacer Google Analytics, tracking web

---

### 2️⃣ **BACKUP** (6 scripts)
Sauvegarde chiffrée et sauvegarde distribuée

```
├── install_restic.sh              → Restic (Sauvegarde chiffrée)
├── install_bacula.sh              → Bacula (Enterprise backup)
├── install_duplicati.sh           → Duplicati (Sauvegarde distribuée)
├── install_rclone.sh              → Rclone (Sync cloud multi-provider)
└── install_backblaze_sync.sh      → Syncthing (Sync P2P)
```

**Cas d'usage**: Stratégie de sauvegarde, archivage, disaster recovery

---

### 3️⃣ **BUSINESS** (7 scripts)
Solutions d'entreprise et ERP/CRM

```
├── install_odoo.sh                → Odoo (ERP/CRM complet)
├── install_erpnext.sh             → ERPNext (ERP modulaire)
├── install_dolibarr.sh            → Dolibarr (ERP/CRM PME)
├── install_invoice_ninja.sh       → Invoice Ninja (Facturation)
├── install_paperless_ngx.sh       → Paperless-ngx (Gestion documents)
├── install_taiga.sh               → Taiga (Project Management)
└── install_akaunting.sh           → Akaunting (Comptabilité)
```

**Cas d'usage**: Gestion d'entreprise complète, PME, comptabilité

---

### 4️⃣ **CMS** (10 scripts)
Systèmes de gestion de contenu

```
├── install_wordpress.sh           → WordPress (Blog/Site web)
├── install_nextcloud.sh           → Nextcloud (Sync fichiers)
├── install_strapi.sh              → Strapi (Headless CMS)
├── install_ghost.sh               → Ghost (Blog moderne)
├── install_moodle.sh              → Moodle (Plateforme e-learning)
├── install_drupal.sh              → Drupal (CMS puissant)
├── install_mediawiki.sh           → MediaWiki (Wiki)
├── install_dokuwiki.sh            → DokuWiki (Wiki léger)
├── install_wallabag.sh            → Wallabag (Lecteur d'articles)
└── install_owncloud.sh            → OwnCloud (Sync fichiers)
```

**Cas d'usage**: Sites web, blogs, wikis internes, e-learning

---

### 5️⃣ **COLLABORATION** (12 scripts)
Outils collaboratifs et communication

```
├── install_rocket_chat.sh         → Rocket.Chat (Chat d'équipe)
├── install_mattermost_enhanced.sh → Mattermost (Plateforme collaboration)
├── install_gitea.sh               → Gitea (Git auto-hébergé)
├── install_seafile.sh             → Seafile (Partage fichiers)
├── install_zulip.sh               → Zulip (Chat avec threads)
├── install_jitsi_meet.sh          → Jitsi Meet (Visioconférence)
├── install_syncthing.sh           → Syncthing (Sync P2P)
├── install_mastodon.sh            → Mastodon (Réseau social)
├── install_discourse.sh           → Discourse (Forum)
├── install_etherpad.sh            → Etherpad (Écriture collaborative)
├── install_matrix_synapse.sh      → Matrix Synapse (Communication)
├── install_nextcloud_talk.sh      → Nextcloud Talk (Visioconférence)
├── install_outline.sh             → Outline (Wiki collaboratif)
└── install_focalboard.sh          → Focalboard (Tableau blanc)
```

**Cas d'usage**: Communication équipe, chat, visioconférence, collaboration documentaire

---

### 6️⃣ **DATABASES** (4 scripts)
Bases de données

```
├── install_postgresql.sh          → PostgreSQL (SQL puissant)
├── install_mongodb.sh             → MongoDB (NoSQL document)
├── install_redis.sh               → Redis (In-memory cache)
└── install_influxdb.sh            → InfluxDB (Séries temporelles)
```

**Cas d'usage**: Stockage données, cache, métriques temporelles

---

### 7️⃣ **DEVOPS** (14 scripts)
Outils DevOps, CI/CD, qualité de code

```
├── install_sonarqube.sh           → SonarQube (Qualité code)
├── install_gitlab_runner.sh       → GitLab Runner (CI/CD)
├── install_jenkins.sh             → Jenkins (Automation serveur)
├── install_woodpecker_ci.sh       → Woodpecker CI (Pipeline CI/CD)
├── install_landscape.sh           → Landscape (Gestion Ubuntu)
├── install_gitpod.sh              → Gitpod (Dev environment)
├── install_gitea_self_hosted.sh   → Gitea (Git auto-hébergé)
├── install_gitlist.sh             → Gitlist (Navigateur Git)
├── install_requestbin.sh          → RequestBin (Debug webhook)
├── install_penpot.sh              → Penpot (Design collaboratif)
├── install_localstack.sh          → LocalStack (AWS emulateur)
├── install_rustlings.sh           → Rustlings (Tutoriel Rust)
├── install_hurl.sh                → Hurl (Test API)
└── install_luajit.sh              → LuaJIT (Compilateur Lua)
```

**Cas d'usage**: Pipeline CI/CD, qualité code, collaboration développeurs

---

### 8️⃣ **INFRASTRUCTURE** (15 scripts)
Infrastructure, orchestration, réseaux

```
├── install_docker.sh              → Docker (Containerisation)
├── install_portainer.sh           → Portainer (Docker UI)
├── install_minio.sh               → MinIO (S3 compatible)
├── install_docker_compose.sh      → Docker Compose (Multi-container)
├── install_lxd.sh                 → LXD (Conteneurs légers)
├── install_hashicorp_consul.sh    → Consul (Service mesh)
├── install_hashicorp_nomad.sh     → Nomad (Orchestration)
├── install_haproxy.sh             → HAProxy (Load balancer)
├── install_nginx.sh               → Nginx (Web server)
├── install_apache.sh              → Apache (Web server)
├── install_nginx_ui.sh            → Nginx UI (Gestion web)
├── install_filebrowser.sh         → Filebrowser (Gestionnaire fichiers)
├── install_meilisearch.sh         → Meilisearch (Moteur recherche)
├── install_typesense.sh           → Typesense (Moteur recherche)
├── install_guacamole.sh           → Guacamole (RDP/SSH/VNC)
├── install_rustdesk.sh            → Rustdesk (Bureau distant)
├── install_dnsmasq.sh             → DNSmasq (DNS/DHCP)
├── install_seaweedfs.sh           → SeaweedFS (Distributed storage)
├── install_hyperledger_fabric.sh  → Hyperledger (Blockchain)
└── install_openwrt.sh             → OpenWrt (Système routeur)
```

**Cas d'usage**: Infrastructure cloud, conteneurs, orchestration, services réseau

---

### 9️⃣ **IOT** (3 scripts)
Internet des Objets et domotique

```
├── install_home_assistant.sh      → Home Assistant (Domotique)
├── install_node_red.sh            → Node-RED (Automation)
├── install_openhab.sh             → openHAB (Domotique universelle)
└── install_mosquitto.sh           → Mosquitto (Broker MQTT)
```

**Cas d'usage**: Domotique, automatisation, IoT, sensors

---

### 🔟 **MEDIA** (6 scripts)
Serveurs multimédia et streaming

```
├── install_jellyfin.sh            → Jellyfin (Plex alternative)
├── install_plex.sh                → Plex (Serveur multimédia)
├── install_emby.sh                → Emby (Streaming vidéo)
├── install_kodi.sh                → Kodi (Centre multimédia)
├── install_immich.sh              → Immich (Galerie photos)
```

**Cas d'usage**: Streaming vidéo personnel, galeries photos

---

### 1️⃣1️⃣ **MONITORING** (12 scripts)
Monitoring et alertes

```
├── install_prometheus.sh          → Prometheus (Collecte métriques)
├── install_grafana.sh             → Grafana (Tableaux bord)
├── install_zabbix.sh              → Zabbix (Monitoring complet)
├── install_zabbix_agent.sh        → Zabbix Agent (Client)
├── install_loki.sh                → Loki (Log aggregation)
├── install_netdata.sh             → Netdata (Real-time monitoring)
├── install_elk.sh                 → ELK Stack (Logging)
├── install_alertmanager.sh        → Alertmanager (Gestion alertes)
├── install_sentry.sh              → Sentry (Monitoring erreurs)
├── install_tig_stack.sh           → TIG Stack (Telegraf/InfluxDB/Grafana)
├── install_cacti.sh               → Cacti (Collecte données SNMP)
├── install_ntopng.sh              → ntopng (Moniteur trafic)
└── install_uptime_kuma.sh         → Uptime Kuma (Surveillance services)
```

**Cas d'usage**: Monitoring infrastructure, alertes, visualisation métriques

---

### 1️⃣2️⃣ **SECURITY** (11 scripts)
Sécurité et authentification

```
├── install_certbot.sh             → Certbot (Let's Encrypt SSL/TLS)
├── install_wireguard.sh           → WireGuard (VPN moderne)
├── install_openvpn.sh             → OpenVPN (VPN)
├── install_fail2ban.sh            → Fail2ban (Protection)
├── install_pihole.sh              → Pi-hole (Bloqueur DNS)
├── install_keycloak.sh            → Keycloak (Authentification)
├── install_vault.sh               → Vault (Gestion secrets)
├── install_vaultwarden.sh         → Vaultwarden (Password manager)
```

**Cas d'usage**: HTTPS, VPN, protection brute-force, authentification centralisée

---

## 🚀 Démarrage Rapide

### Étape 1: Cloner ou télécharger
```bash
cd /opt
git clone <repo-url> install-scripts
cd install-scripts
```

### Étape 2: Utiliser un script
```bash
# Exemple: Installer Docker
sudo bash infrastructure/install_docker.sh

# Exemple: Installer Prometheus + Grafana
sudo bash monitoring/install_prometheus.sh
sudo bash monitoring/install_grafana.sh
```

### Étape 3: Accéder au service
Consultez le message affiché par le script pour l'URL et les identifiants.

---

## 📊 Distribution des Scripts

```
Analytics           : 3 scripts (Web Analytics)
Backup              : 6 scripts (Sauvegarde)
Business            : 7 scripts (ERP/CRM)
CMS                 : 10 scripts (Sites web)
Collaboration       : 12 scripts (Communication)
Databases           : 4 scripts (Data storage)
DevOps              : 14 scripts (CI/CD, tools)
Infrastructure      : 15 scripts (Core services)
IoT                 : 3 scripts (Domotique)
Media               : 6 scripts (Streaming)
Monitoring          : 12 scripts (Alertes)
Security            : 11 scripts (Sécurité)
────────────────────────────────
TOTAL               : 103 scripts
```

---

## 🔧 Fonctionnalités Communes

Tous les scripts utilisent ces fonctions de `install_common.sh`:

```bash
ensure_root              # Vérifier accès root
detect_os              # Détecto système
detect_package_manager # Trouver gestionnaire de paquets
pkg_update             # Mettre à jour les paquets
pkg_install APP        # Installer un paquet
service_enable SERVICE # Activer un service au boot
service_restart SERVICE # Redémarrer un service
```

---

## 💡 Cas d'Usage

### 🏠 Serveur Personnel
```bash
# Installer Nextcloud + Jellyfin + Home Assistant
sudo bash cms/install_nextcloud.sh
sudo bash media/install_jellyfin.sh
sudo bash iot/install_home_assistant.sh
```

### 🏢 PME
```bash
# Infrastructure complète
sudo bash infrastructure/install_docker.sh
sudo bash business/install_dolibarr.sh
sudo bash monitoring/install_grafana.sh
sudo bash collaboration/install_mattermost.sh
```

### 📊 Stack Monitoring
```bash
# Stack monitoring complet
sudo bash monitoring/install_prometheus.sh
sudo bash monitoring/install_grafana.sh
sudo bash monitoring/install_alertmanager.sh
sudo bash monitoring/install_loki.sh
```

### 🔐 Infrastructure Sécurisée
```bash
# Infrastructure sécurisée
sudo bash security/install_wireguard.sh
sudo bash security/install_vault.sh
sudo bash security/install_fail2ban.sh
```

---

## 📝 Notes Importantes

- ✅ Les scripts nécessitent un accès **root** (via sudo)
- ✅ Nécessite une **connexion Internet** pour télécharger les ressources
- ✅ La plupart supportent les **7+ distributions Linux**
- ⚠️ Certaines solutions demandent : Docker, Kubernetes,lus spécialisés
- 🔐 Changez les **mots de passe par défaut**
- 📝 Configurez un **domaine et SSL** pour la production

---

## 🤝 Support et Contribution

Pour plus d'information sur un script spécifique:
```bash
cat infrastructure/install_docker.sh
# Voir les commentaires et la documentation
```

---

**Version**: 1.0  
**Solutions**: 103+  
**Support**: Debian, Ubuntu, RHEL, CentOS, SUSE, Arch Linux, Alpine  
**Prochaine mise à jour**: Continu
