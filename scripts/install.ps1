<#
.SYNOPSIS
    Installe les outils utilisés par les skills Triple Performance sous Windows.

.DESCRIPTION
    Utilise winget pour ImageMagick, Pandoc, Poppler, jq, Python, yt-dlp, Deno, Git et Claude Code,
    et l'installeur officiel pour la CLI mediawiki.

.PARAMETER Check
    Vérifie seulement la présence des outils, n'installe rien.

.PARAMETER Yes
    Ne demande pas de confirmation avant d'installer.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Check
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

$MediawikiInstaller = 'https://raw.githubusercontent.com/neayi/Mediawiki-LLM-Cli/main/install.ps1'
$WikiUrl = 'https://wiki.tripleperformance.fr'

# Commandes acceptées (la première trouvée suffit) et identifiant winget
$Tools = @(
    @{ Key = 'mediawiki';   Commands = @('mediawiki');          WingetId = $null;                      Label = 'CLI MediaWiki (lecture/écriture des pages)' }
    @{ Key = 'imagemagick'; Commands = @('magick');             WingetId = 'ImageMagick.ImageMagick';  Label = 'ImageMagick (images)' }
    @{ Key = 'pandoc';      Commands = @('pandoc');             WingetId = 'JohnMacFarlane.Pandoc';    Label = 'Pandoc (conversion de documents)' }
    @{ Key = 'poppler';     Commands = @('pdftotext');          WingetId = 'oschwartz10612.Poppler';   Label = 'Poppler (extraction PDF)' }
    @{ Key = 'jq';          Commands = @('jq');                 WingetId = 'jqlang.jq';                Label = 'jq (JSON)' }
    @{ Key = 'python';      Commands = @('python3', 'python', 'py'); WingetId = 'Python.Python.3.12';  Label = 'Python 3 (scripts des skills)' }
    @{ Key = 'openpyxl';    Module = 'openpyxl';                WingetId = $null;                      Label = 'openpyxl (lecture et écriture des fichiers Excel)' }
    @{ Key = 'ytdlp';       Commands = @('yt-dlp');             WingetId = 'yt-dlp.yt-dlp';            Label = 'yt-dlp (vidéos YouTube : métadonnées, vignette, transcription)' }
    @{ Key = 'deno';        Commands = @('deno');               WingetId = 'DenoLand.Deno';            Label = 'Deno (moteur JavaScript requis par yt-dlp pour YouTube)' }
    @{ Key = 'git';         Commands = @('git');                WingetId = 'Git.Git';                  Label = 'git (et Git Bash, utilisé par Claude Code)' }
    @{ Key = 'claude';      Commands = @('claude');             WingetId = 'Anthropic.ClaudeCode';     Label = 'Claude Code (exécute les skills)' }
)

function Update-SessionPath {
    # Un terminal ouvert avant l'installation transmet un PATH périmé : on complète avec celui du registre
    $known = $env:Path -split ';'
    $added = foreach ($scope in 'Machine', 'User') {
        [Environment]::GetEnvironmentVariable('Path', $scope) -split ';' | Where-Object { $_ -and $known -notcontains $_ }
    }
    if ($added) { $env:Path = (@($env:Path.TrimEnd(';')) + $added) -join ';' }
}

function Find-Command([string[]]$Commands) {
    foreach ($cmd in $Commands) {
        $found = Get-Command $cmd -ErrorAction SilentlyContinue
        # L'alias "python" du Microsoft Store n'est qu'un raccourci vers le Store
        if ($found -and $found.Source -notlike '*WindowsApps*') { return $found.Source }
    }
    return $null
}

function Find-Python { Find-Command @('python3', 'python', 'py') }

function Test-Tool($Tool) {
    if ($Tool.Module) {
        $python = Find-Python
        if (-not $python) { return $false }
        # Windows PowerShell transforme la sortie d'erreur d'un programme en erreur bloquante si 'Stop'
        # (l'affectation reste locale à cette fonction)
        $ErrorActionPreference = 'Continue'
        & $python -c "import $($Tool.Module)" 2>$null
        return $LASTEXITCODE -eq 0
    }
    return [bool](Find-Command $Tool.Commands)
}

function Confirm-Step([string]$Message) {
    if ($Yes) { return $true }
    $answer = Read-Host "$Message [o/N]"
    return $answer -match '^(o|oui|y|yes)$'
}

# Information seulement : la lecture ne demande pas de compte, le code de sortie n'en dépend pas
function Show-WikiLogin {
    if (-not (Find-Command @('mediawiki'))) { return }
    $ErrorActionPreference = 'Continue'
    try {
        $output = & mediawiki api "$WikiUrl/api.php?action=query&meta=userinfo&format=json" 2>$null
        $user = (($output -join "`n") | ConvertFrom-Json).query.userinfo
    } catch {
        $user = $null
    }
    if (-not $user) {
        Write-Host '  [??] Connexion au wiki non vérifiée (wiki injoignable ?)' -ForegroundColor Yellow
    } elseif ($user.id -gt 0) {
        Write-Host "  [OK] Connecté au wiki : $($user.name)" -ForegroundColor Green
    } else {
        Write-Host "  [--] Non connecté au wiki (nécessaire pour écrire) : mediawiki login $WikiUrl" -ForegroundColor Red
    }
}

Update-SessionPath

Write-Host "Système : Windows $([Environment]::OSVersion.Version)"
Write-Host ''
Write-Host 'Vérification des outils :'

$Missing = @()
foreach ($tool in $Tools) {
    if (Test-Tool $tool) {
        Write-Host "  [OK] $($tool.Label)" -ForegroundColor Green
    } else {
        Write-Host "  [--] $($tool.Label) — manquant" -ForegroundColor Red
        $Missing += $tool
    }
}
Show-WikiLogin

if ($Missing.Count -eq 0) {
    Write-Host ''
    Write-Host 'Tout est installé.'
    exit 0
}

if ($Check) {
    Write-Host ''
    Write-Host "Outils manquants : $(($Missing | ForEach-Object { $_.Key }) -join ', ')"
    Write-Host 'Lancez scripts\install.ps1 sans -Check pour les installer.'
    exit 1
}

$WingetTools = @($Missing | Where-Object { $_.WingetId })
if ($WingetTools.Count -gt 0 -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget est introuvable. Installez « App Installer » depuis le Microsoft Store, puis relancez ce script." -ForegroundColor Yellow
    exit 1
}

Write-Host ''
foreach ($tool in $Missing) { Write-Host "  À installer : $($tool.Label)" }
if (-not (Confirm-Step 'Continuer ?')) { Write-Host 'Abandon.'; exit 1 }

foreach ($tool in $WingetTools) {
    Update-SessionPath
    # Un paquet précédent a pu l'installer comme dépendance (Deno avec yt-dlp)
    if (Test-Tool $tool) { continue }
    Write-Host "Installation de $($tool.WingetId)..."
    winget install --id $tool.WingetId --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Échec de l'installation de $($tool.WingetId) (code $LASTEXITCODE)." -ForegroundColor Yellow
    }
}

Update-SessionPath

$PipModules = @($Missing | Where-Object { $_.Module } | ForEach-Object { $_.Module })
if ($PipModules.Count -gt 0) {
    $python = Find-Python
    if ($python) {
        Write-Host "Installation des modules Python : $($PipModules -join ', ')..."
        & $python -m pip install --user @PipModules
    } else {
        Write-Host "Python est introuvable : impossible d'installer $($PipModules -join ', ')." -ForegroundColor Yellow
    }
}

if ($Missing | Where-Object { $_.Key -eq 'mediawiki' }) {
    Write-Host 'Installation de la CLI mediawiki...'
    Invoke-RestMethod $MediawikiInstaller | Invoke-Expression
}

Update-SessionPath

Write-Host ''
$StillMissing = @($Tools | Where-Object { -not (Test-Tool $_) })
if ($StillMissing.Count -gt 0) {
    Write-Host "Outils toujours manquants : $(($StillMissing | ForEach-Object { $_.Key }) -join ', ')" -ForegroundColor Yellow
    Write-Host 'Relancez ce script dans un nouveau terminal pour les installer.'
    exit 1
}

Write-Host 'Installation terminée.' -ForegroundColor Green
Write-Host 'Ouvrez un NOUVEAU terminal pour utiliser ces outils : celui-ci garde son ancien PATH.'
Show-WikiLogin
