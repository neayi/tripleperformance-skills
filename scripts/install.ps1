<#
.SYNOPSIS
    Installe les outils utilisés par les skills Triple Performance sous Windows.

.DESCRIPTION
    Utilise winget pour ImageMagick, Pandoc, Poppler, jq, Python, yt-dlp, Deno, Git et Claude Code,
    et l'installeur officiel pour la CLI mediawiki. Si winget est absent, il est installé depuis GitHub.

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
# La CLI associe tripleperformance.fr et wiki.tripleperformance.fr au même compte
$LoginUrl = 'https://tripleperformance.fr'
$PluginId = 'triple-performance@triple-performance'
$MarketplaceName = 'triple-performance'
$MarketplaceRepo = 'neayi/tripleperformance-skills'
$PluginManifestUrl = "https://raw.githubusercontent.com/$MarketplaceRepo/main/.claude-plugin/plugin.json"
$InstallerUrl = "https://raw.githubusercontent.com/$MarketplaceRepo/main/scripts/install.ps1"
$WingetRelease = 'https://github.com/microsoft/winget-cli/releases/latest/download'

$SkillState = 'missing'   # ok, update, missing ou unknown
$WikiState = 'absent'     # ok, anon, unknown ou absent (CLI mediawiki manquante)
$SkillEntries = @()
$LatestVersion = $null
$Workdir = $null

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

function Find-Winget {
    $found = Get-Command winget -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    # Alias d'exécution créé par l'installation, absent du PATH d'un terminal déjà ouvert
    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $alias) { return $alias }
    return $null
}

# Certains Windows (installations épurées, LTSC, Store désactivé) n'ont pas « App Installer » :
# on installe la dernière version publiée sur GitHub, avec ses dépendances
function Install-Winget {
    Write-Host 'Installation de winget depuis GitHub...'
    $arch = switch ($env:PROCESSOR_ARCHITECTURE) { 'ARM64' { 'arm64' } 'x86' { 'x86' } default { 'x64' } }
    $temp = Join-Path ([IO.Path]::GetTempPath()) "winget-$([Guid]::NewGuid())"
    $progress = $ProgressPreference
    try {
        # La barre de progression rend Invoke-WebRequest très lent sous Windows PowerShell 5.1
        $ProgressPreference = 'SilentlyContinue'
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        $bundle = Join-Path $temp 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        $deps = Join-Path $temp 'DesktopAppInstaller_Dependencies.zip'
        Invoke-WebRequest "$WingetRelease/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile $bundle -UseBasicParsing
        Invoke-WebRequest "$WingetRelease/DesktopAppInstaller_Dependencies.zip" -OutFile $deps -UseBasicParsing
        Expand-Archive -LiteralPath $deps -DestinationPath (Join-Path $temp 'deps') -Force
        $packages = Get-ChildItem -LiteralPath (Join-Path $temp 'deps') -Recurse -Include '*.appx', '*.msix' |
            Where-Object { $_.FullName -match "[\\_]$arch[\\_.]" }
        foreach ($package in $packages) {
            # Une version égale ou plus récente déjà présente fait échouer l'ajout : sans conséquence
            try { Add-AppxPackage -Path $package.FullName -ErrorAction Stop } catch { }
        }
        Add-AppxPackage -Path $bundle -ErrorAction Stop
    } catch {
        Write-Host "  Échec de l'installation de winget : $($_.Exception.Message)" -ForegroundColor Yellow
    } finally {
        $ProgressPreference = $progress
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
    Update-SessionPath
    return Find-Winget
}

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
    $script:WikiState = 'absent'
    if (-not (Find-Command @('mediawiki'))) { return }
    $ErrorActionPreference = 'Continue'
    try {
        $output = & mediawiki api "$WikiUrl/api.php?action=query&meta=userinfo&format=json" 2>$null
        $user = (($output -join "`n") | ConvertFrom-Json).query.userinfo
    } catch {
        $user = $null
    }
    if (-not $user) {
        $script:WikiState = 'unknown'
        Write-Host '  [??] Connexion au wiki non vérifiée (wiki injoignable ?)' -ForegroundColor Yellow
    } elseif ($user.id -gt 0) {
        $script:WikiState = 'ok'
        Write-Host "  [OK] Connecté au wiki : $($user.name)" -ForegroundColor Green
    } else {
        $script:WikiState = 'anon'
        Write-Host "  [--] Non connecté au wiki (nécessaire pour écrire) : mediawiki login $LoginUrl" -ForegroundColor Red
    }
}

# Sans connexion, Claude peut lire le wiki mais pas y publier : on propose de se connecter tout de suite
function Connect-Wiki {
    if ($Check -or $WikiState -ne 'anon') { return }
    Write-Host ''
    Write-Host 'Pour que Claude publie des pages sur Triple Performance, connectez-vous avec votre compte du wiki'
    Write-Host '(créez-en un sur le wiki si besoin). La commande ouvre la page Spécial:BotPasswords et vous guide'
    Write-Host "pour créer un mot de passe de robot : accordez au moins l'édition, la création de pages et le téléversement."
    if ($Yes -or [Console]::IsInputRedirected) {
        Write-Host "  mediawiki login $LoginUrl"
        return
    }
    $answer = Read-Host 'Se connecter au wiki maintenant ? [O/n]'
    if ($answer -notmatch '^(|o|oui|y|yes)$') {
        Write-Host "Vous pourrez vous connecter plus tard avec : mediawiki login $LoginUrl"
        return
    }
    $ErrorActionPreference = 'Continue'
    & mediawiki login $LoginUrl
    Write-Host ''
    Show-WikiLogin
}

# Le Contrôle intelligent des applications bloque à chaque lancement les programmes non signés
# (yt-dlp, jq, pdftotext, mediawiki…). Le désactiver est définitif : c'est à l'utilisateur de choisir.
function Show-SmartAppControl {
    try {
        $state = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -Name VerifiedAndReputablePolicyState -ErrorAction Stop).VerifiedAndReputablePolicyState
    } catch {
        return   # Windows 10 ou valeur absente : la fonction n'existe pas
    }
    if ($state -eq 1) {
        Write-Host '  [!!] Contrôle intelligent des applications activé : il bloque les outils non signés (yt-dlp, jq, pdftotext, mediawiki…)' -ForegroundColor Yellow
        Write-Host '       Pour les utiliser, désactivez-le : Sécurité Windows > Contrôle des applications et du navigateur >' -ForegroundColor Yellow
        Write-Host '       Paramètres du Contrôle intelligent des applications > Désactivé.' -ForegroundColor Yellow
        Write-Host '       Attention : ce choix est définitif, Windows ne permet de le réactiver qu''en le réinstallant.' -ForegroundColor Yellow
    } elseif ($state -eq 2) {
        Write-Host '  [!!] Contrôle intelligent des applications en évaluation : Windows peut l''activer et bloquer les outils non signés' -ForegroundColor Yellow
        Write-Host '       Si un outil est bloqué (« éditeur non vérifié »), désactivez-le dans Sécurité Windows >' -ForegroundColor Yellow
        Write-Host '       Contrôle des applications et du navigateur (choix définitif).' -ForegroundColor Yellow
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

# Les références du plugin sont dans son cache : sans cela, chaque lecture demanderait l'autorisation
function Grant-PluginRead {
    foreach ($entry in $SkillEntries) {
        if (-not $entry.projectPath -or -not $entry.installPath) { continue }
        try {
            $cache = (Split-Path (Split-Path $entry.installPath)) -replace '\\', '/'
            $file = Join-Path $entry.projectPath '.claude\settings.local.json'
            $settings = New-Object PSObject
            if (Test-Path -LiteralPath $file) {
                $settings = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
            }
            if (-not $settings.permissions) { $settings | Add-Member permissions (New-Object PSObject) }
            $folders = @($settings.permissions.additionalDirectories | Where-Object { $_ })
            if ($folders -contains $cache) { continue }
            $settings.permissions | Add-Member additionalDirectories @($folders + $cache) -Force
            [IO.File]::WriteAllText($file, ($settings | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
        } catch {
            Write-Host '  Autorisation de lecture du plugin non ajoutée.' -ForegroundColor Yellow
        }
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

# Claude Desktop : paquet MSIX publié par Anthropic, ou ancien installeur dans %LOCALAPPDATA%\AnthropicClaude
function Test-ClaudeDesktop {
    if ($env:LOCALAPPDATA -and (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'))) { return $true }
    try {
        return [bool](@(Get-AppxPackage -Name 'Claude' -ErrorAction Stop | Where-Object { $_.Publisher -like '*Anthropic*' }).Count)
    } catch {
        return $false
    }
}

# Raccourcis dans le dossier de travail : un double-clic depuis l'Explorateur ouvre Claude Code dans ce dossier,
# ou met à jour les skills. Avec Claude Desktop, le raccourci lance directement claude.exe --desktop ;
# sinon, Claude Code s'ouvre dans PowerShell (plutôt que Windows Terminal, qui n'est pas toujours installé).
function New-ClaudeShortcut {
    foreach ($entry in @($SkillEntries | Where-Object { $_.projectPath })) {
        $file = Join-Path $entry.projectPath 'Ouvrir Claude.lnk'
        $exists = Test-Path -LiteralPath $file
        try {
            $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $claude = Find-Command @('claude')
            $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($file)
            if ($claude -like '*.exe' -and (Test-ClaudeDesktop)) {
                # Chemin complet : pas besoin du PATH. Réduite, la console de claude.exe ne fait que passer.
                $shortcut.TargetPath = $claude
                $shortcut.Arguments = '--desktop'
                $shortcut.WindowStyle = 7
            } else {
                $shortcut.TargetPath = $powershell
                # L'Explorateur a pu démarrer avant l'installation : PATH relu dans le registre
                $shortcut.Arguments = '-NoExit -Command "$env:Path = [Environment]::GetEnvironmentVariable(''Path'', ''Machine'') + '';'' + [Environment]::GetEnvironmentVariable(''Path'', ''User''); claude"'
                $shortcut.WindowStyle = 1
            }
            $shortcut.WorkingDirectory = $entry.projectPath
            $shortcut.Description = 'Ouvrir Claude Code dans le dossier Triple Performance'
            $shortcut.IconLocation = if ($claude -like '*.exe') { "$claude,0" } else { "$powershell,0" }
            $shortcut.Save()
            if (-not $exists) { Write-Host "  Raccourci créé : $file" }
        } catch {
            Write-Host '  Raccourci « Ouvrir Claude » non créé.' -ForegroundColor Yellow
        }
        New-UpdateScript $entry.projectPath
    }
}

# « Mettre à jour les skills.bat » : relance ce script, téléchargé à nouveau depuis GitHub.
# cmd lit les .bat dans la page de code OEM : texte en ASCII seulement.
function New-UpdateScript([string]$Folder) {
    $file = Join-Path $Folder 'Mettre à jour les skills.bat'
    $exists = Test-Path -LiteralPath $file
    $text = @"
@echo off
rem Met a jour les skills Triple Performance et les outils dont elles ont besoin
set "TP_DOSSIER=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "`$f = Join-Path `$env:TEMP 'tp-install.ps1'; try { Invoke-RestMethod '$InstallerUrl' -OutFile `$f } catch { Write-Host 'Telechargement du script d''installation impossible : verifiez votre connexion a Internet.' -ForegroundColor Yellow; exit 1 }; & `$f -Dossier `$env:TP_DOSSIER.TrimEnd('\')"
echo.
pause

"@
    try {
        [IO.File]::WriteAllText($file, ($text -replace "`r?`n", "`r`n"), [Text.Encoding]::ASCII)
        if (-not $exists) { Write-Host "  Raccourci créé : $file" }
    } catch {
        Write-Host '  Raccourci « Mettre à jour les skills » non créé.' -ForegroundColor Yellow
    }
}

function Show-FirstSteps {
    $folder = @($SkillEntries | Where-Object { $_.projectPath })[0].projectPath
    Write-Host ''
    Write-Host "Prochaines étapes, dans votre dossier de travail ($folder) :"
    Write-Host '  1. Déposez-y les documents à partir desquels rédiger : documents Word ou PDF, photos,'
    Write-Host '     fichiers Excel, archives zip…'
    $app = if ((Find-Command @('claude')) -like '*.exe' -and (Test-ClaudeDesktop)) { ' dans Claude Desktop' } else { '' }
    Write-Host "  2. Double-cliquez sur « Ouvrir Claude » dans ce dossier pour lancer Claude Code$app."
    Write-Host '     Au premier lancement, connectez-vous à votre compte Claude.'
    Write-Host '  3. Demandez-lui de créer ou de mettre à jour des pages Triple Performance à partir de ces documents :'
    Write-Host '       Crée une page Triple Performance à partir de compte-rendu-essai.pdf'
    Write-Host '       Mets à jour la page « Couverts végétaux » avec les photos de ce dossier'
    Write-Host '       Importe cette vidéo : https://www.youtube.com/watch?v=KZ5Tz3IGoSI'
}

# Ouvre le dossier de travail dans l'Explorateur, pour y déposer les documents
function Open-Workdir {
    $folders = @($SkillEntries | Where-Object { $_.projectPath })
    if ($Check -or $folders.Count -eq 0) { return }
    try {
        Start-Process explorer.exe -ArgumentList "`"$($folders[0].projectPath)`""
    } catch { }
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
- Sous Windows, lance les scripts Python avec `python` (ou `py`) : `python3` ouvre le Microsoft Store.
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
Show-SmartAppControl

# Une mise à jour disponible n'empêche pas de travailler : pas d'échec avec -Check
if ($Missing.Count -eq 0 -and $SkillState -ne 'missing' -and ($SkillState -ne 'update' -or $Check)) {
    Write-Host ''
    Write-Host 'Tout est installé.'
    if ($SkillState -eq 'update') {
        Write-Host "Mise à jour des skills disponible : relancez le script d'installation (sans -Check)."
    }
    if ($Check) {
        Show-WorkdirHint
    } elseif (@($SkillEntries | Where-Object { $_.projectPath }).Count -gt 0) {
        New-ClaudeShortcut
        Connect-Wiki
        Show-FirstSteps
        Open-Workdir
    }
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
$Winget = Find-Winget

Write-Host ''
if ($WingetTools.Count -gt 0 -and -not $Winget) { Write-Host '  À installer : winget (gestionnaire de paquets de Windows, depuis GitHub)' }
foreach ($tool in $Missing) { Write-Host "  À installer : $($tool.Label)" }
if ($SkillState -eq 'missing' -or $SkillState -eq 'unknown') {
    Select-Workdir
    Write-Host "  Skills à installer dans : $Workdir"
}
if ($Missing.Count -gt 0 -or $SkillState -ne 'update') {
    if (-not (Confirm-Step 'Continuer ?')) { Write-Host 'Abandon.'; exit 1 }
}

if ($WingetTools.Count -gt 0 -and -not $Winget) {
    $Winget = Install-Winget
    if (-not $Winget) {
        Write-Host "winget est introuvable. Installez « App Installer » depuis le Microsoft Store, puis relancez ce script." -ForegroundColor Yellow
        exit 1
    }
}

foreach ($tool in $WingetTools) {
    Update-SessionPath
    # Un paquet précédent a pu l'installer comme dépendance (Deno avec yt-dlp)
    if (Test-Tool $tool) { continue }
    Write-Host "Installation de $($tool.WingetId)..."
    & $Winget install --id $tool.WingetId --exact --silent --accept-package-agreements --accept-source-agreements
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
Read-Skills
Grant-PluginRead
New-ClaudeShortcut

Write-Host ''
Write-Host 'Vérification finale :'
Show-Skills
Show-WikiLogin
Show-SmartAppControl

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
Connect-Wiki
if (@($SkillEntries | Where-Object { $_.projectPath }).Count -gt 0) {
    Show-FirstSteps
    Open-Workdir
} else {
    Write-Host 'Ouvrez un NOUVEAU terminal pour utiliser ces outils : celui-ci garde son ancien PATH.'
}
