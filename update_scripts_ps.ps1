# Script PowerShell pour mettre à jour tous les scripts d'installation avec le système de gestion d'erreurs

param(
    [string]$ScriptDir = "r:\git\install-scripts"
)

$LogFile = "r:\git\install-scripts\update_scripts_ps.log"

function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage
}

function Update-Script {
    param([string]$ScriptFile)

    Write-Log "INFO" "Mise à jour de $ScriptFile"

    $content = Get-Content -Path $ScriptFile -Raw

    # Vérifier si le script a déjà été mis à jour
    if ($content -match "ensure_root" -and $content -match "detect_os") {
        Write-Log "INFO" "Script déjà mis à jour: $ScriptFile"
        return $true
    }

    # Extraire le nom de l'application
    $appName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptFile) -replace '^install_', '' -replace '_', ' '
    $appName = (Get-Culture).TextInfo.ToTitleCase($appName.ToLower())

    # Nouveau contenu d'en-tête
    $header = @"
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="`$(cd "`$(dirname "`${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "`$SCRIPT_DIR/install_common.sh"

# Vérifications préalables
ensure_root
detect_os
detect_package_manager

info "Installation de $appName..."

"@

    # Supprimer les anciennes lignes et ajouter le nouvel en-tête
    $content = $content -replace '(?s)^#!/usr/bin/env bash\s*set -euo pipefail\s*SCRIPT_DIR=.*?\. "\$SCRIPT_DIR/install_common\.sh"\s*# Variables de configuration', $header

    # Si la regex n'a pas fonctionné, essayer une approche différente
    if ($content -notmatch "ensure_root") {
        $content = $header + $content
        # Supprimer les doublons
        $content = $content -replace '(?s)(#!/usr/bin/env bash\s*set -euo pipefail\s*.*?ensure_root.*?\n.*?detect_os.*?\n.*?detect_package_manager.*?\n.*?info "Installation de .*?".*?\n).*?\1', '$1'
    }

    # Écrire le fichier mis à jour
    Set-Content -Path $ScriptFile -Value $content -Encoding UTF8

    Write-Log "SUCCESS" "En-tête mis à jour pour $ScriptFile"
    return $true
}

function Update-FunctionCalls {
    param([string]$ScriptFile)

    Write-Log "INFO" "Mise à jour des appels de fonctions dans $ScriptFile"

    $content = Get-Content -Path $ScriptFile -Raw

    # Remplacer pkg_install par pkg_install_with_rollback
    $content = $content -replace '\bpkg_install\b', 'pkg_install_with_rollback'

    # Ajouter un appel success à la fin si nécessaire
    if ($content -notmatch 'success "Installation terminée"') {
        $content = $content -replace '(?s)(.*)(\n\s*echo\s+"=+.*INSTALLATION.*TERMINÉE.*=+"\s*.*)$', '$1success "Installation terminée avec succès"$2'
    }

    Set-Content -Path $ScriptFile -Value $content -Encoding UTF8

    Write-Log "SUCCESS" "Appels de fonctions mis à jour dans $ScriptFile"
}

# Script principal
Write-Log "INFO" "Début de la mise à jour des scripts d'installation"

# Trouver tous les scripts install_*.sh
$scripts = Get-ChildItem -Path $ScriptDir -Filter "install_*.sh" -Recurse | Where-Object { $_.Name -ne "install_common.sh" -and $_.Name -ne "update_scripts.sh" }

$total = $scripts.Count
Write-Log "INFO" "Nombre de scripts à mettre à jour: $total"

$updated = 0
foreach ($script in $scripts) {
    try {
        if (Update-Script -ScriptFile $script.FullName) {
            Update-FunctionCalls -ScriptFile $script.FullName
            $updated++
        }
    }
    catch {
        Write-Log "ERROR" "Erreur lors de la mise à jour de $($script.FullName): $($_.Exception.Message)"
    }
}

Write-Log "SUCCESS" "Mise à jour terminée: $updated/$total scripts mis à jour"