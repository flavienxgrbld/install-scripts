#!/usr/bin/env bash
set -euo pipefail

# Script pour mettre à jour tous les scripts d'installation avec le nouveau système de gestion d'erreurs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/update_scripts.log"

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo "$message"
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Fonction pour mettre à jour un script
update_script() {
    local script_file="$1"
    local temp_file="${script_file}.tmp"

    log "INFO" "Mise à jour de $script_file"

    # Lire le contenu du script
    local content
    content=$(cat "$script_file")

    # Vérifier si le script a déjà été mis à jour
    if grep -q "ensure_root" "$script_file" && grep -q "detect_os" "$script_file"; then
        log "INFO" "Script déjà mis à jour: $script_file"
        return 0
    fi

    # Extraire le nom de l'application du nom du fichier
    local app_name
    app_name=$(basename "$script_file" | sed 's/install_\(.*\)\.sh/\1/' | tr '_' ' ' | sed 's/\b\w/\U&/g')

    # Créer le nouveau contenu
    {
        echo "#!/usr/bin/env bash"
        echo "set -euo pipefail"
        echo ""
        echo "SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\""
        echo "# shellcheck source=/dev/null"
        echo ". \"\$SCRIPT_DIR/install_common.sh\""
        echo ""
        echo "# Vérifications préalables"
        echo "ensure_root"
        echo "detect_os"
        echo "detect_package_manager"
        echo ""
        echo "info \"Installation de $app_name...\""
        echo ""
        # Supprimer les anciennes lignes set -euo pipefail et . install_common.sh
        echo "$content" | sed '/^set -euo pipefail$/d' | sed '/^SCRIPT_DIR=/d' | sed '/^\. "\$SCRIPT_DIR\/install_common.sh"$/d' | sed '/^# shellcheck source=\/dev\/null$/d'
    } > "$temp_file"

    # Remplacer l'ancien fichier
    mv "$temp_file" "$script_file"
    chmod +x "$script_file"

    log "SUCCESS" "Script mis à jour: $script_file"
}

# Fonction pour remplacer les appels de fonctions dans un script
update_function_calls() {
    local script_file="$1"

    log "INFO" "Mise à jour des appels de fonctions dans $script_file"

    # Remplacer pkg_install par pkg_install_with_rollback
    sed -i 's/pkg_install /pkg_install_with_rollback /g' "$script_file"

    # Remplacer info/warn/success/error_exit si nécessaire (mais ils sont déjà définis)
    # Ajouter des appels de succès à la fin si nécessaire
    if ! grep -q "success.*terminée" "$script_file"; then
        # Ajouter un appel success à la fin
        sed -i '$ s/$/\nsuccess "Installation terminée avec succès"/' "$script_file"
    fi

    log "SUCCESS" "Appels de fonctions mis à jour dans $script_file"
}

main() {
    log "INFO" "Début de la mise à jour des scripts d'installation"

    # Trouver tous les scripts install_*.sh
    local scripts
    mapfile -t scripts < <(find "$SCRIPT_DIR" -name "install_*.sh" -type f | grep -v "install_common.sh")

    local total=${#scripts[@]}
    log "INFO" "Nombre de scripts à mettre à jour: $total"

    local updated=0
    for script in "${scripts[@]}"; do
        if update_script "$script"; then
            update_function_calls "$script"
            ((updated++))
        fi
    done

    log "SUCCESS" "Mise à jour terminée: $updated/$total scripts mis à jour"
}

main "$@"