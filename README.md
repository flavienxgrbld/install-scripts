# Scripts d'Installation Automatisée

Collection de scripts Bash pour installer automatiquement diverses applications open source sur Linux.

## Scripts Disponibles

### Monitoring et Observabilité
- [`install_zabbix.sh`](install_zabbix.sh) - Zabbix Server (monitoring)
- [`install_zabbix_agent.sh`](install_zabbix_agent.sh) - Zabbix Agent
- [`install_grafana.sh`](install_grafana.sh) - Grafana (visualisation de métriques)

### Gestion de Contenu et CMS
- [`install_wordpress.sh`](install_wordpress.sh) - WordPress (CMS)
- [`install_nextcloud.sh`](install_nextcloud.sh) - Nextcloud (cloud personnel)
- [`install_glpi.sh`](install_glpi.sh) - GLPI (gestion IT)

### Outils de Collaboration
- [`install_mattermost.sh`](install_mattermost.sh) - Mattermost (messagerie)
- [`install_gitea.sh`](install_gitea.sh) - Gitea (Git)

### Documentation et Gestion
- [`install_bookstack.sh`](install_bookstack.sh) - BookStack (documentation)
- [`install_kanboard.sh`](install_kanboard.sh) - Kanboard (gestion de projet Kanban)

## Systèmes d'Exploitation Supportés

Tous les scripts supportent automatiquement :
- **Debian/Ubuntu/Raspbian** (famille Debian)
- **RHEL/CentOS/Oracle/AlmaLinux/Rocky Linux/Amazon Linux** (famille Red Hat)
- **SUSE/SLES/openSUSE** (famille SUSE)
- **Arch Linux** (famille Pacman)

## Utilisation

### Prérequis
- Être connecté en root ou avoir les droits sudo
- Connexion internet pour télécharger les paquets

### Installation Générale
```bash
# Télécharger le script souhaité
wget https://raw.githubusercontent.com/votre-repo/install-scripts/main/install_nom_application.sh

# Rendre exécutable
chmod +x install_nom_application.sh

# Exécuter
./install_nom_application.sh
```

### Exemple avec Zabbix
```bash
wget https://raw.githubusercontent.com/votre-repo/install-scripts/main/install_zabbix.sh
chmod +x install_zabbix.sh
./install_zabbix.sh
```

## Fonctionnalités Communes

### Détection Automatique d'OS
- Détection automatique du système d'exploitation
- Installation des dépôts appropriés selon la distribution
- Gestion des gestionnaires de paquets (apt, dnf, yum, zypper, pacman)

### Installation Complète
- Installation des dépendances système
- Configuration automatique des services
- Configuration des bases de données
- Configuration des serveurs web (Apache/Nginx)
- Configuration de sécurité de base

### Sécurité
- Génération automatique de mots de passe
- Configuration des permissions appropriées
- Sécurisation des bases de données
- Configuration firewall (UFW si disponible)

## Structure des Scripts

Chaque script suit cette structure :
1. **Détection d'OS** - Vérification de la compatibilité
2. **Mise à jour système** - Mise à jour des paquets
3. **Installation dépendances** - PHP, bases de données, serveurs web
4. **Téléchargement application** - Depuis les dépôts officiels
5. **Configuration** - Base de données, fichiers de config, permissions
6. **Démarrage services** - Activation et vérification des services
7. **Instructions finales** - URLs d'accès, identifiants, recommandations

## Variables de Configuration

La plupart des scripts utilisent des variables configurables :
- Versions des applications (latest par défaut)
- Noms d'utilisateurs et mots de passe
- Ports et chemins d'installation
- Paramètres de base de données

## Dépannage

### Problèmes Courants
- **Erreur de téléchargement** : Vérifier la connexion internet
- **Erreur de permissions** : S'assurer d'être root
- **Service qui ne démarre pas** : Vérifier les logs avec `journalctl -u nom_service`
- **Erreur base de données** : Vérifier les identifiants et permissions

### Logs et Debugging
```bash
# Vérifier le statut d'un service
systemctl status nom_service

# Consulter les logs
journalctl -u nom_service -f

# Vérifier la configuration
nom_service -t  # Pour certains services
```

## Contribution

Les scripts sont conçus pour être maintenables et extensibles :
- Fonctions communes dans `install_common.sh`
- Structure modulaire pour ajouter de nouveaux OS
- Commentaires détaillés
- Gestion d'erreurs robuste

## Licence

Ces scripts sont fournis tels quels, sans garantie. Utilisez-les à vos risques et périls.

## Support

Pour des problèmes spécifiques :
1. Vérifier les logs des services
2. Consulter la documentation officielle de l'application
3. Ouvrir une issue sur le dépôt Git

---

*Scripts développés pour automatiser le déploiement d'applications open source sur diverses distributions Linux.*