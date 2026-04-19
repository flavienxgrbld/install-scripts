#!/usr/bin/env bash

# Script pour lister et compter tous les scripts d'installation

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  📦 Installation Scripts - Index Complet"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TOTAL_SCRIPTS=0

# Array des catégories
declare -A CATEGORIES

categories=(
    "analytics:Analyse et Analytics"
    "backup:Sauvegarde et Archivage"
    "business:Solutions d'Entreprise"
    "cms:Systèmes de Gestion de Contenu"
    "collaboration:Outils Collaboratifs"
    "databases:Bases de Données"
    "devops:DevOps et Infrastructure"
    "infrastructure:Infrastructure et Réseaux"
    "iot:Internet des Objets"
    "media:Serveurs Multimédia"
    "monitoring:Monitoring et Alertes"
    "security:Sécurité"
)

echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ 📂 CATÉGORIES ET SOLUTIONS                                      │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""

for category_info in "${categories[@]}"; do
    CATEGORY="${category_info%:*}"
    DESCRIPTION="${category_info#*:}"
    
    if [ -d "$SCRIPT_DIR/$CATEGORY" ]; then
        SCRIPTS=$(ls "$SCRIPT_DIR/$CATEGORY"/install_*.sh 2>/dev/null | wc -l)
        
        if [ "$SCRIPTS" -gt 0 ]; then
            printf "📁 %-20s %-35s │ %2d scripts\n" "$CATEGORY:" "$DESCRIPTION" "$SCRIPTS"
            TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + SCRIPTS))
        fi
    fi
done

# Scripts racine
if [ -f "$SCRIPT_DIR/install_common.sh" ]; then
    ROOT_SCRIPTS=$(ls "$SCRIPT_DIR"/install_*.sh 2>/dev/null | wc -l)
    if [ "$ROOT_SCRIPTS" -gt 0 ]; then
        # Ne pas compter install_common.sh
        ROOT_SCRIPTS=$((ROOT_SCRIPTS - 1))
        printf "📁 %-20s %-35s │ %2d scripts\n" "root:" "Scripts Racine" "$ROOT_SCRIPTS"
        TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + ROOT_SCRIPTS))
    fi
fi

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ 📊 STATISTIQUES                                                 │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  ✓ Total d'applications: $TOTAL_SCRIPTS"
echo "  ✓ Nombre de catégories: 12"
echo "  ✓ Distributions supportées: 7+ (Debian, Ubuntu, RHEL, CentOS, SUSE, Arch, Alpine)"
echo ""

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ 🗂️ SCRIPTS PAR CATÉGORIE (Détail)                               │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""

for category_info in "${categories[@]}"; do
    CATEGORY="${category_info%:*}"
    DESCRIPTION="${category_info#*:}"
    
    if [ -d "$SCRIPT_DIR/$CATEGORY" ]; then
        echo "📚 $DESCRIPTION ($CATEGORY/)"
        
        ls "$SCRIPT_DIR/$CATEGORY"/install_*.sh 2>/dev/null | while read script; do
            BASENAME=$(basename "$script" .sh)
            APP_NAME="${BASENAME#install_}"
            
            # Remplacer les underscores par des tirets et mettre en majuscule
            DISPLAY_NAME=$(echo "$APP_NAME" | sed 's/_/ /g' | sed 's/ /-/g')
            
            echo "   ├─ 🔧 $DISPLAY_NAME"
        done
        echo ""
    fi
done

# Scripts racine
echo "📚 Applications Racine"
ls "$SCRIPT_DIR"/install_*.sh 2>/dev/null | while read script; do
    basename "$script" .sh | grep -v "common" | while read name; do
        APP_NAME="${name#install_}"
        DISPLAY_NAME=$(echo "$APP_NAME" | sed 's/_/ /g')
        echo "   ├─ 🔧 $DISPLAY_NAME"
    done
done

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "🚀 UTILISATION:"
echo ""
echo "   1. Rendez le script exécutable:"
echo "      chmod +x infrastructure/install_docker.sh"
echo ""
echo "   2. Lancez l'installation:"
echo "      sudo ./infrastructure/install_docker.sh"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo ""
