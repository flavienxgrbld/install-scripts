# 🎓 Guide d'Utilisation - Install Scripts

## 📖 Table des Matières

1. [Installation et Configuration](#1-installation-et-configuration)
2. [Utilisation Basique](#2-utilisation-basique)
3. [Installations Multiples](#3-installations-multiples)
4. [Dépannage](#4-dépannage)
5. [Bonnes Pratiques](#5-bonnes-pratiques)

---

## 1️⃣ Installation et Configuration

### 1.1 Prérequis

- Système Linux : Debian, Ubuntu, RHEL, CentOS, SUSE, Arch, Alpine
- Accès root (via `sudo`)
- Connexion Internet
- 2 GB RAM minimum (selon les solutions)
- Ports libres (voir la documentation de chaque script)

### 1.2 Installation du Référentiel

```bash
# Cloner le référentiel
git clone https://github.com/your-repo/install-scripts.git
cd install-scripts

# Ou télécharger et extraire
wget https://github.com/your-repo/install-scripts/archive/main.zip
unzip main.zip
cd install-scripts-main
```

### 1.3 Vérifier les Permissions

```bash
# Voir les droits actuels
ls -la *.sh
chmod -R 755 *.sh
chmod -R 755 */*.sh

# Vérifier l'exécution
./infrastructure/install_docker.sh --help 2>&1 | head -5
```

---

## 2️⃣ Utilisation Basique

### 2.1 Installation Simple

```bash
# Format basique
sudo bash /chemin/vers/install_app.sh

# Exemples
sudo bash infrastructure/install_docker.sh
sudo bash cms/install_wordpress.sh
sudo bash monitoring/install_prometheus.sh
```

### 2.2 Rendre Exécutable et Lancer

```bash
# 1. Rendre exécutable
chmod +x infrastructure/install_docker.sh

# 2. Lancer avec sudo
sudo ./infrastructure/install_docker.sh

# 3. Ou lancer directement
sudo bash infrastructure/install_docker.sh
```

### 2.3 Afficher les Informations

```bash
# Voir le contenu d'un script
cat infrastructure/install_docker.sh

# Voir seulement les commentaires
grep -E "^#|^#!/" infrastructure/install_docker.sh

# Voir les ports utilisés
grep -i "ufw allow" infrastructure/install_docker.sh
```

---

## 3️⃣ Installations Multiples

### 3.1 Installation Séquencielle

```bash
# Installation de plusieurs solutions
sudo bash infrastructure/install_docker.sh
sudo bash infrastructure/install_portainer.sh
sudo bash monitoring/install_prometheus.sh
sudo bash monitoring/install_grafana.sh
```

### 3.2 Script d'Installation Personnalisé

Créez un fichier `install_all_monitoring.sh`:

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "📦 Installation du Stack Monitoring..."

# Installer les dépendances
echo "1. Installation de Prometheus..."
sudo bash "$SCRIPT_DIR/monitoring/install_prometheus.sh" || exit 1

echo "2. Installation de Grafana..."
sudo bash "$SCRIPT_DIR/monitoring/install_grafana.sh" || exit 1

echo "3. Installation d'Alertmanager..."
sudo bash "$SCRIPT_DIR/monitoring/install_alertmanager.sh" || exit 1

echo "4. Installation de Loki..."
sudo bash "$SCRIPT_DIR/monitoring/install_loki.sh" || exit 1

echo ""
echo "✅ Stack Monitoring installé avec succès!"
echo ""
echo "URLs disponibles:"
echo "  - Prometheus: http://votre-serveur:9090"
echo "  - Grafana: http://votre-serveur:3000"
echo "  - AlertManager: http://votre-serveur:9093"
```

Utilisation:
```bash
chmod +x install_all_monitoring.sh
sudo bash install_all_monitoring.sh
```

### 3.3 Installation avec Paramètres

```bash
# Créer un script wrapper avec paramètres
#!/bin/bash

APPS="${1:-all}"

case "$APPS" in
    docker)
        sudo bash infrastructure/install_docker.sh
        ;;
    stack)
        sudo bash infrastructure/install_docker.sh
        sudo bash infrastructure/install_portainer.sh
        ;;
    monitoring)
        sudo bash monitoring/install_prometheus.sh
        sudo bash monitoring/install_grafana.sh
        ;;
    all)
        sudo bash infrastructure/install_docker.sh
        sudo bash monitoring/install_prometheus.sh
        # ... etc
        ;;
esac
```

---

## 4️⃣ Dépannage

### 4.1 Erreurs Communes

#### ❌ "Permission denied"
```bash
# Solution: Utiliser sudo
sudo bash script.sh

# Ou rendre exécutable d'abord
chmod +x script.sh
sudo ./script.sh
```

#### ❌ "Command not found"
```bash
# Solution: Vérifier 'wc', 'wget', etc. sont installés
sudo apt update && sudo apt install wget curl

# Puis relancer le script
sudo bash script.sh
```

#### ❌ "Port already in use"
```bash
# Vérifier le port utilisé
sudo netstat -tulpn | grep 8080
# Ou
sudo lsof -i :8080

# Changer le port dans la configuration
sudo vim /etc/app/app.conf
```

#### ❌ "Service failed to start"
```bash
# Vérifier les logs
sudo journalctl -u app-name -n 50
sudo journalctl -u app-name -f  # Suivi temps réel

# Vérifier le statut
sudo systemctl status app-name

# Voir la configuration
sudo vim /etc/app/app.conf
```

### 4.2 Débogage

```bash
# Exécuter en mode verbose
bash -x infrastructure/install_docker.sh

# Rediriger les erreurs dans un fichier
sudo bash infrastructure/install_docker.sh 2>&1 | tee install.log

# Vérifier les erreurs spécifiques
tail -f /var/log/syslog
tail -f /var/log/docker/deamon.log
```

### 4.3 Diagnostiques

```bash
# Vérifier que le système est à jour
sudo apt update && sudo apt upgrade

# Vérifier l'espace disque
df -h

# Vérifier la mémoire
free -h

# Vérifier les services qui tournent
sudo systemctl list-units --state=running

# Vérifier les ports ouverts
sudo ss -tlnp
```

---

## 5️⃣ Bonnes Pratiques

### 5.1 Avant l'Installation

```bash
# 1. Créer un snapshot/backup du système (optionnel)
sudo tar -czf /backup/system-$(date +%Y%m%d).tar.gz / --exclude-from=exclude.txt

# 2. Lire le script avant de l'exécuter
cat infrastructure/install_docker.sh | less

# 3. Noter les ports utilisés
grep -i "port\|ufw" infrastructure/install_docker.sh

# 4. Vérifier l'espace disque disponible
df -h

# 5. Mettre à jour le système
sudo apt update && sudo apt upgrade
```

### 5.2 Pendant l'Installation

```bash
# 1. Enregistrer les résultats
sudo bash infrastructure/install_docker.sh | tee install-docker.log

# 2. Attendre la fin complète (ne pas Ctrl+C)
# Les services mettent du temps à démarrer

# 3. Noter les identifiants par défaut affichés
# Exemple: Admin: admin / Password: xyz123

# 4. Vérifier les ports ouverts
sudo ufw status numbered
```

### 5.3 Après l'Installation

```bash
# 1. Vérifier le statut
sudo systemctl status app-name

# 2. Vérifier les ports
sudo netstat -tulpn | grep app-name

# 3. Tester l'accès
curl http://localhost:8080

# 4. Accéder à l'interface web
# Ouvrir dans le navigateur: http://votre-ip:port

# 5. Changer les mots de passe par défaut
# Accéder à l'interface et modifier le profil

# 6. Configurer SSL/HTTPS
# Utiliser Certbot: certbot certonly --docker -d votre-domaine.com
```

### 5.4 Sécurité

```bash
# 1. Configurer le pare-feu
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable

# 2. Configurer SSL/TLS
sudo bash security/install_certbot.sh
sudo certbot renew --post-hook "systemctl restart nginx"

# 3. Configurer les sauvegardes
sudo bash backup/install_restic.sh

# 4. Installer un VPN
sudo bash security/install_wireguard.sh

# 5. Activer le monitoring
sudo bash monitoring/install_ufw.sh
```

### 5.5 Maintenance Régulière

```bash
# 1. Mettre à jour les paquets
sudo apt update && sudo apt upgrade

# 2. Vérifier les journaux
sudo journalctl --since="1 day ago" --priority=err

# 3. Nettoyer les fichiers temporaires
sudo apt autoclean && sudo apt autoremove

# 4. Vérifier l'espace disque
sudo du -sh * | sort -h | tail -10

# 5. Redémarrer régulièrement
sudo reboot
```

---

## 📊 Cas d'Utilisation Real-World

### Cas 1: Infrastructure Personnelle

```bash
#!/bin/bash
# setup-personal-server.sh

echo "📦 Configuration serveur personnel..."

# Infrastructure de base
sudo bash infrastructure/install_docker.sh
sudo bash infrastructure/install_nginx.sh

# Applications
sudo bash cms/install_nextcloud.sh
sudo bash media/install_jellyfin.sh
sudo bash iot/install_home_assistant.sh

# Sécurité
sudo bash security/install_certbot.sh
sudo bash security/install_wireguard.sh

# Monitoring
sudo bash monitoring/install_uptime_kuma.sh

echo "✅ Serveur personnel configuré!"
```

### Cas 2: Infrastructure PME

```bash
#!/bin/bash
# setup-pme.sh

echo "💼 Configuration infrastructure PME..."

# Infrastructure
sudo bash infrastructure/install_docker.sh
sudo bash infrastructure/install_portainer.sh
sudo bash infrastructure/install_haproxy.sh

# Business
sudo bash business/install_dolibarr.sh

# Collaboration
sudo bash collaboration/install_mattermost.sh
sudo bash collaboration/install_nextcloud.sh

# Monitoring
sudo bash monitoring/install_prometheus.sh
sudo bash monitoring/install_grafana.sh

# Sécurité
sudo bash security/install_vault.sh
sudo bash backup/install_restic.sh

echo "✅ Infrastructure PME configurée!"
```

### Cas 3: Stack Monitoring Complet

```bash
#!/bin/bash
# setup-monitoring.sh

echo "📈 Configuration Stack Monitoring..."

# Base de données temporelles
sudo bash databases/install_influxdb.sh
sudo bash databases/install_postgresql.sh

# Collecte et alertes
sudo bash monitoring/install_prometheus.sh
sudo bash monitoring/install_alertmanager.sh
sudo bash monitoring/install_loki.sh

# Visualisation
sudo bash monitoring/install_grafana.sh

# Logging
sudo bash monitoring/install_elk.sh

# Health checks
sudo bash monitoring/install_uptime_kuma.sh

echo "✅ Stack Monitoring complet!"
```

---

## 📚 Ressources Additionnelles

- Documentation officielle: Voir README_SCRIPTS.sh
- Index complet: INDEX_COMPLETE.md
- Scripts utilitaires: LIST_ALL_SCRIPTS.sh

---

## 🔗 Liens Utiles

- [Docker Official Images](https://hub.docker.com)
- [Let's Encrypt](https://letsencrypt.org)
- [Linux Distributions](https://distrowatch.com)
- [Systemd Documentation](https://www.freedesktop.org/wiki/Software/systemd)

---

**Dernière mise à jour**: 2024  
**Version**: 1.0  
**Auteur**: Install Scripts Team
