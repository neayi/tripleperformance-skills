<#
.SYNOPSIS
    Installe les outils utilisés par les skills Triple Performance sous Windows.

.DESCRIPTION
    Utilise winget pour ImageMagick, Pandoc, Poppler, jq, Python, yt-dlp, Deno, Git et Claude Code,
    et l'installeur officiel pour la CLI mediawiki.

.PARAMETER Check
    Vérifie les outils, les skills et leur mise à jour, n'installe rien.

.PARAMETER Yes
    Ne demande pas de confirmation avant d'installer.

.PARAMETER Dossier
    Dossier de travail où installer les skills (par défaut : Documents\Triple Performance).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Check
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Yes,
    [string]$Dossier
)

$ErrorActionPreference = 'Stop'

$MediawikiInstaller = 'https://raw.githubusercontent.com/neayi/Mediawiki-LLM-Cli/main/install.ps1'
$WikiUrl = 'https://wiki.tripleperformance.fr'
$PluginId = 'triple-performance@triple-performance'
$MarketplaceName = 'triple-performance'
$MarketplaceRepo = 'neayi/tripleperformance-skills'
$PluginManifestUrl = "https://raw.githubusercontent.com/$MarketplaceRepo/main/.claude-plugin/plugin.json"

$SkillState = 'missing'   # ok, update, missing ou unknown
$SkillEntries = @()
$LatestVersion = $null
$Workdir = $null
$SkillsInstalled = $false

# Commandes acceptées (la première trouvée suffit) et identifiant winget
$Tools = @(
    @{ Key = 'mediawiki';   Commands = @('mediawiki');          WingetId = $null;                      Label = 'CLI MediaWiki (lecture/écriture des pages)' }
    @{ Key = 'imagemagick'; Commands = @('magick');             WingetId = 'ImageMagick.ImageMagick';  Label = 'ImageMagick (images)' }
    @{ Key = 'pandoc';      Commands = @('pandoc');             WingetId = 'JohnMacFarlane.Pandoc';    Label = 'Pandoc (conversion de documents)' }
    @{ Key = 'poppler';     Commands = @('pdftotext');          WingetId = 'oschwartz10612.Poppler';   Label = 'Poppler (extraction PDF)' }
    @{ Key = 'jq';          Commands = @('jq');                 WingetId = 'jqlang.jq';                Label = 'jq (JSON)' }
    @{ Key = 'python';      Commands = @('python3', 'python', 'py'); WingetId = 'Python.Python.3.14';  Label = 'Python 3 (scripts des skills)' }
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

function Get-LatestVersion {
    # Lecture seule : comparer à GitHub évite de modifier la marketplace pendant -Check
    try {
        $manifest = Invoke-RestMethod $PluginManifestUrl -TimeoutSec 10
        if ($manifest -is [string]) { $manifest = $manifest | ConvertFrom-Json }
        return $manifest.version
    } catch {
        return $null
    }
}

function Read-Skills {
    $script:SkillEntries = @()
    $script:LatestVersion = $null
    $script:SkillState = 'missing'
    if (-not (Find-Command @('claude'))) { return }

    $ErrorActionPreference = 'Continue'
    $encoding = [Console]::OutputEncoding
    try {
        # Sans cela, un dossier accentué serait mal décodé et paraîtrait supprimé
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        $json = (& claude plugin list --json 2>$null) -join "`n"
        if ($LASTEXITCODE -ne 0 -or -not $json) { throw 'liste indisponible' }
        $installed = $json | ConvertFrom-Json
    } catch {
        $script:SkillState = 'unknown'
        return
    } finally {
        [Console]::OutputEncoding = $encoding
    }

    foreach ($entry in $installed) {
        if ($entry.id -ne $PluginId) { continue }
        # Un dossier supprimé depuis l'installation ne compte plus
        if ($entry.scope -eq 'user' -or ($entry.projectPath -and (Test-Path -LiteralPath $entry.projectPath))) {
            $script:SkillEntries += $entry
        }
    }
    if ($script:SkillEntries.Count -eq 0) { return }

    $script:SkillState = 'ok'
    $script:LatestVersion = Get-LatestVersion
    if ($script:LatestVersion -and @($script:SkillEntries | Where-Object { $_.version -ne $script:LatestVersion }).Count -gt 0) {
        $script:SkillState = 'update'
    }
}

function Show-Skills {
    Read-Skills
    if ($SkillState -eq 'missing') {
        Write-Host '  [--] Skills Triple Performance — non installées' -ForegroundColor Red
    } elseif ($SkillState -eq 'unknown') {
        Write-Host '  [??] Skills Triple Performance non vérifiées' -ForegroundColor Yellow
    }
    foreach ($entry in $SkillEntries) {
        $where = if ($entry.projectPath) { $entry.projectPath } else { 'tous les dossiers' }
        if ($LatestVersion -and $entry.version -ne $LatestVersion) {
            Write-Host "  [!!] Skills Triple Performance $($entry.version) ($where) : version $LatestVersion disponible" -ForegroundColor Yellow
        } else {
            Write-Host "  [OK] Skills Triple Performance $($entry.version) ($where)" -ForegroundColor Green
        }
    }
}

function Show-WorkdirHint {
    if ($SkillEntries.Count -gt 0 -and $SkillEntries[0].projectPath) {
        Write-Host "Pour travailler, lancez claude dans ce dossier : cd `"$($SkillEntries[0].projectPath)`""
    }
}

function Show-FirstSteps {
    Write-Host ''
    Write-Host 'Pour commencer :'
    Write-Host '  1. Ouvrez un NOUVEAU terminal (celui-ci garde son ancien PATH) et placez-vous dans votre dossier de travail :'
    Write-Host "       cd `"$($SkillEntries[0].projectPath)`""
    Write-Host '  2. Lancez Claude Code (au premier lancement, connectez-vous à votre compte Claude) :'
    Write-Host '       claude'
    Write-Host "  3. Demandez-lui par exemple d'importer une vidéo YouTube :"
    Write-Host '       Importe cette vidéo : https://www.youtube.com/watch?v=KZ5Tz3IGoSI'
}

# La nouvelle fenêtre hérite du PATH rechargé par ce script
function Open-Claude {
    $folders = @($SkillEntries | Where-Object { $_.projectPath })
    if ($Check -or $Yes -or $folders.Count -eq 0 -or [Console]::IsInputRedirected) { return }
    Write-Host ''
    $answer = Read-Host 'Ouvrir Claude Code maintenant dans votre dossier de travail ? [O/n]'
    if ($answer -match '^(|o|oui|y|yes)$') {
        Start-Process powershell -WorkingDirectory $folders[0].projectPath -ArgumentList '-NoExit', '-Command', 'claude'
    }
}

function Select-Workdir {
    $default = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Triple Performance'
    $path = $Dossier
    if (-not $path) {
        $path = $default
        if (-not $Yes) {
            $answer = (Read-Host "Dossier de travail Triple Performance [$default]").Trim().Trim('"')
            if ($answer) { $path = $answer }
        }
    }
    $script:Workdir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
}

# Contexte pour les demandes ambiguës ; jamais écrasé, l'utilisateur peut l'avoir complété
function Write-WorkspaceGuide {
    $file = Join-Path $Workdir 'CLAUDE.md'
    if (Test-Path -LiteralPath $file) { return }
    $text = @'
# Espace de travail Triple Performance

Ce dossier sert à contribuer à Triple Performance (https://wiki.tripleperformance.fr/), le wiki collaboratif de l'agroécologie.

- Sauf indication contraire, mes demandes concernent ce wiki : utilise les skills Triple Performance.
- Réponds en français, sans jargon technique.
- Je dépose ici mes PDF, images et fichiers Excel.
'@
    [IO.File]::WriteAllText($file, $text, (New-Object Text.UTF8Encoding($false)))
}

function Install-Skills {
    Write-Host "Installation des skills dans $Workdir..."
    New-Item -ItemType Directory -Path $Workdir -Force | Out-Null
    Push-Location -LiteralPath $Workdir
    try {
        & claude plugin marketplace add $MarketplaceRepo --scope local
        if ($LASTEXITCODE -eq 0) { & claude plugin install $PluginId --scope local }
        if ($LASTEXITCODE -eq 0) {
            $script:SkillsInstalled = $true
            Write-WorkspaceGuide
        } else {
            Write-Host "  Échec de l'installation des skills." -ForegroundColor Yellow
        }
    } finally {
        Pop-Location
    }
}

function Update-Skills {
    foreach ($entry in $SkillEntries) {
        if ($entry.version -eq $LatestVersion) { continue }
        $where = if ($entry.projectPath) { $entry.projectPath } else { $PWD.Path }
        Write-Host "Mise à jour des skills ($where)..."
        # Depuis le dossier concerné : ailleurs, la CLI répond que tout est à jour
        Push-Location -LiteralPath $where
        try {
            & claude plugin marketplace update $MarketplaceName
            if ($LASTEXITCODE -eq 0) { & claude plugin update $PluginId --scope $entry.scope }
            if ($LASTEXITCODE -ne 0) { Write-Host '  Échec de la mise à jour des skills.' -ForegroundColor Yellow }
        } finally {
            Pop-Location
        }
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
Show-Skills
Show-WikiLogin

# Une mise à jour disponible n'empêche pas de travailler : pas d'échec avec -Check
if ($Missing.Count -eq 0 -and $SkillState -ne 'missing' -and ($SkillState -ne 'update' -or $Check)) {
    Write-Host ''
    Write-Host 'Tout est installé.'
    if ($SkillState -eq 'update') {
        Write-Host "Mise à jour des skills disponible : relancez le script d'installation (sans -Check)."
    }
    Show-WorkdirHint
    Open-Claude
    exit 0
}

if ($Check) {
    Write-Host ''
    if ($Missing.Count -gt 0) { Write-Host "Outils manquants : $(($Missing | ForEach-Object { $_.Key }) -join ', ')" }
    if ($SkillState -eq 'missing') { Write-Host 'Skills Triple Performance non installées.' }
    Write-Host "Lancez le script d'installation (sans -Check) pour les installer."
    exit 1
}

$WingetTools = @($Missing | Where-Object { $_.WingetId })
if ($WingetTools.Count -gt 0 -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget est introuvable. Installez « App Installer » depuis le Microsoft Store, puis relancez ce script." -ForegroundColor Yellow
    exit 1
}

Write-Host ''
foreach ($tool in $Missing) { Write-Host "  À installer : $($tool.Label)" }
if ($SkillState -eq 'missing' -or $SkillState -eq 'unknown') {
    Select-Workdir
    Write-Host "  Skills à installer dans : $Workdir"
}
if ($Missing.Count -gt 0 -or $SkillState -ne 'update') {
    if (-not (Confirm-Step 'Continuer ?')) { Write-Host 'Abandon.'; exit 1 }
}

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

Read-Skills
if ($SkillState -eq 'missing' -and (Find-Command @('claude'))) { Install-Skills }
elseif ($SkillState -eq 'update') { Update-Skills }

Write-Host ''
Write-Host 'Vérification finale :'
Show-Skills
Show-WikiLogin

Write-Host ''
$StillMissing = @($Tools | Where-Object { -not (Test-Tool $_) })
if ($StillMissing.Count -gt 0 -or $SkillState -eq 'missing') {
    $names = @($StillMissing | ForEach-Object { $_.Key })
    if ($SkillState -eq 'missing') { $names += 'skills' }
    Write-Host "Toujours manquants : $($names -join ', ')" -ForegroundColor Yellow
    Write-Host 'Relancez ce script dans un nouveau terminal pour les installer.'
    exit 1
}

Write-Host 'Installation terminée.' -ForegroundColor Green
if ($SkillsInstalled -and $SkillEntries.Count -gt 0) {
    Show-FirstSteps
} else {
    Write-Host 'Ouvrez un NOUVEAU terminal pour utiliser ces outils : celui-ci garde son ancien PATH.'
    Show-WorkdirHint
}
Open-Claude
