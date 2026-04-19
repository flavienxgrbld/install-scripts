#!/usr/bin/env bash

set -euo pipefail

echo "================================================"
echo "  📦 Installation Scripts Repository"
echo "================================================"
echo ""
echo "Une collection complète de scripts Bash autom"
echo "pour installer plus de 100 solutions sur Linux"
echo ""

# Compter les scripts
if [ -d "$(dirname "${BASH_SOURCE[0]}")" ]; then
    SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
    TOTAL_SCRIPTS=$(find "$SCRIPT_DIR" -name "install_*.sh" 2>/dev/null | wc -l)
    echo "Total des scripts: $TOTAL_SCRIPTS"
fi

echo ""
echo "================================================"
echo "  📂 Catégories disponibles:"
echo "================================================"

categories=(
    "analytics"
    "backup"
    "business"
    "cms"
    "collaboration"
    "databases"
    "devops"
    "infrastructure"
    "iot"
    "media"
    "monitoring"
    "security"
)

for category in "${categories[@]}"; do
    DIR="$SCRIPT_DIR/$category"
    if [ -d "$DIR" ]; then
        count=$(find "$DIR" -name "install_*.sh" 2>/dev/null | wc -l)
        echo "  ✓ $category ($count scripts)"
    fi
done

echo ""
echo "================================================"
echo "  🚀 Utilisation:"
echo "================================================"
echo ""
echo "Pour installer une solution:"
echo "  chmod +x infrastructure/install_docker.sh"
echo "  ./infrastructure/install_docker.sh"
echo ""
echo "Prérequis:"
echo "  - Accès root (sudo)"
echo "  - Linux Debian/Ubuntu ou RHEL/CentOS ou autre"
echo "  - Connexion Internet"
echo ""
echo "================================================"
