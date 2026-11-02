#!/usr/bin/env bash
# Installe les outils utilisés par les skills Triple Performance.
# Linux (apt, dnf, pacman, zypper), macOS (Homebrew) et WSL.
#
# Peut être lancé sans clone du dépôt : aucun autre fichier n'est nécessaire.

set -euo pipefail

CHECK_ONLY=0
ASSUME_YES=0
WORKDIR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --dir)
      [ "$#" -ge 2 ] || { echo "--dir attend un dossier" >&2; exit 2; }
      WORKDIR="$2"
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Installe les outils utilisés par les skills Triple Performance.

Options :
  --check      vérifie les outils, les skills et leur mise à jour, n'installe rien
  --yes        ne demande pas de confirmation avant d'installer
  --dir DIR    dossier de travail où installer les skills
               (par défaut : ~/Triple Performance)
EOF
      exit 0
      ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done

CHECK_REQUESTED="$CHECK_ONLY"

MEDIAWIKI_INSTALLER="https://raw.githubusercontent.com/neayi/Mediawiki-LLM-Cli/main/install.sh"
# Les paquets yt-dlp des distributions sont souvent trop anciens pour YouTube :
# on installe l'exécutable officiel, qui se met à jour avec `yt-dlp -U`.
YTDLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
DENO_INSTALLER="https://deno.land/install.sh"
CLAUDE_INSTALLER="https://claude.ai/install.sh"
WIKI_URL="https://wiki.tripleperformance.fr"
PLUGIN_ID="triple-performance@triple-performance"
MARKETPLACE_NAME="triple-performance"
MARKETPLACE_REPO="neayi/tripleperformance-skills"
PLUGIN_MANIFEST_URL="https://raw.githubusercontent.com/$MARKETPLACE_REPO/main/.claude-plugin/plugin.json"
DEFAULT_WORKDIR="$HOME/Triple Performance"

if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  GREEN=""; RED=""; YELLOW=""; RESET=""
fi

info() { printf '%s\n' "$*"; }
ok()   { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
ko()   { printf '  %s✘%s %s\n' "$RED" "$RESET" "$*"; }
warn() { printf '%s%s%s\n' "$YELLOW" "$*" "$RESET"; }

confirm() {
  [ "$ASSUME_YES" -eq 1 ] && return 0
  printf '%s [o/N] ' "$1"
  read -r answer
  case "$answer" in o|O|oui|y|Y|yes) return 0 ;; *) return 1 ;; esac
}

# --- Détection du système --------------------------------------------------

OS="$(uname -s)"
PM=""
case "$OS" in
  Darwin) PM="brew" ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then PM="apt"
    elif command -v dnf >/dev/null 2>&1; then PM="dnf"
    elif command -v pacman >/dev/null 2>&1; then PM="pacman"
    elif command -v zypper >/dev/null 2>&1; then PM="zypper"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    warn "Windows détecté : utilisez plutôt install.ps1 dans PowerShell (voir le README)."
    exit 1
    ;;
esac

ENV_LABEL="$OS"
if [ "$OS" = "Linux" ] && grep -qi microsoft /proc/version 2>/dev/null; then
  ENV_LABEL="Linux (WSL)"
fi
info "Système : $ENV_LABEL — gestionnaire de paquets : ${PM:-aucun détecté}"

# --- Outils requis ---------------------------------------------------------
# Format : "clé|commandes acceptées (séparées par des espaces)|description"
# Une commande "py:<module>" désigne un module Python importable par python3.

TOOLS=(
  "mediawiki|mediawiki|CLI MediaWiki (lecture/écriture des pages)"
  "imagemagick|magick convert|ImageMagick (images)"
  "pandoc|pandoc|Pandoc (conversion de documents)"
  "poppler|pdftotext|Poppler (extraction PDF)"
  "jq|jq|jq (JSON)"
  "python|python3|Python 3 (scripts des skills)"
  "openpyxl|py:openpyxl|openpyxl (lecture et écriture des fichiers Excel)"
  "ytdlp|yt-dlp|yt-dlp (vidéos YouTube : métadonnées, vignette, transcription)"
  "deno|deno|Deno (moteur JavaScript requis par yt-dlp pour YouTube)"
  "curl|curl|curl (appels API)"
  "git|git|git"
  "claude|claude|Claude Code (exécute les skills)"
)

# Nom du paquet pour chaque outil, selon le gestionnaire
package_name() {
  local tool="$1"
  case "$PM:$tool" in
    apt:imagemagick)    echo imagemagick ;;
    apt:poppler)        echo poppler-utils ;;
    apt:python)         echo python3 ;;
    dnf:imagemagick)    echo ImageMagick ;;
    dnf:poppler)        echo poppler-utils ;;
    dnf:python)         echo python3 ;;
    apt:openpyxl|dnf:openpyxl|zypper:openpyxl) echo python3-openpyxl ;;
    pacman:pandoc)      echo pandoc-cli ;;
    pacman:python)      echo python ;;
    pacman:openpyxl)    echo python-openpyxl ;;
    zypper:imagemagick) echo ImageMagick ;;
    zypper:poppler)     echo poppler-tools ;;
    zypper:python)      echo python3 ;;
    brew:python)        echo python ;;
    brew:ytdlp)         echo yt-dlp ;;
    *:*)                echo "$tool" ;;
  esac
}

has_any() {
  local cmd
  for cmd in $1; do
    case "$cmd" in
      py:*) python3 -c "import ${cmd#py:}" >/dev/null 2>&1 && return 0 ;;
      *)    command -v "$cmd" >/dev/null 2>&1 && return 0 ;;
    esac
  done
  return 1
}

# Information seulement : la lecture ne demande pas de compte, le code de sortie n'en dépend pas
show_wiki_login() {
  local output name
  has_any mediawiki || return 0
  output="$(mediawiki api "$WIKI_URL/api.php?action=query&meta=userinfo&format=json" 2>/dev/null)" || output=""
  name="$(printf '%s\n' "$output" | sed -n 's/^ *"name": "\(.*\)",\{0,1\}$/\1/p')"
  if [ -z "$name" ]; then
    warn "  ? Connexion au wiki non vérifiée (wiki injoignable ?)"
  elif printf '%s\n' "$output" | grep -q '"anon": true'; then
    ko "Non connecté au wiki (nécessaire pour écrire) : mediawiki login $WIKI_URL"
  else
    ok "Connecté au wiki : $name"
  fi
}

# --- Skills ----------------------------------------------------------------

SKILL_STATE=""     # ok, update, missing ou unknown
SKILL_ENTRIES=()   # "portée|version|dossier", dossier vide pour la portée user
LATEST_VERSION=""
SKILLS_INSTALLED=0

# Un dossier supprimé depuis l'installation ne compte plus
SKILL_PARSER='
import json, os, sys
for e in json.load(sys.stdin):
    path = e.get("projectPath", "")
    if e.get("id") == sys.argv[1] and (e.get("scope") == "user" or os.path.isdir(path)):
        print("|".join((e.get("scope", ""), e.get("version", ""), path)))
'

read_skills() {
  local list parsed line scope version dir
  SKILL_ENTRIES=()
  LATEST_VERSION=""
  SKILL_STATE=missing
  has_any claude || return 0
  if ! has_any python3; then SKILL_STATE=unknown; return 0; fi
  list="$(claude plugin list --json 2>/dev/null)" || { SKILL_STATE=unknown; return 0; }
  parsed="$(printf '%s' "$list" | python3 -c "$SKILL_PARSER" "$PLUGIN_ID" 2>/dev/null)" \
    || { SKILL_STATE=unknown; return 0; }
  while IFS= read -r line; do
    if [ -n "$line" ]; then SKILL_ENTRIES+=("$line"); fi
  done <<<"$parsed"
  [ "${#SKILL_ENTRIES[@]}" -gt 0 ] || return 0

  SKILL_STATE=ok
  # Lecture seule : comparer à GitHub évite de modifier la marketplace pendant --check
  LATEST_VERSION="$(curl -fsSL --max-time 10 "$PLUGIN_MANIFEST_URL" 2>/dev/null \
    | sed -n 's/^ *"version": "\(.*\)",\{0,1\}$/\1/p' | head -n 1)" || LATEST_VERSION=""
  for line in "${SKILL_ENTRIES[@]}"; do
    IFS='|' read -r scope version dir <<<"$line"
    if [ -n "$LATEST_VERSION" ] && [ "$version" != "$LATEST_VERSION" ]; then SKILL_STATE=update; fi
  done
}

show_skills() {
  local line scope version dir
  read_skills
  case "$SKILL_STATE" in
    missing) ko "Skills Triple Performance — non installées" ;;
    unknown) warn "  ? Skills Triple Performance non vérifiées" ;;
    *)
      for line in "${SKILL_ENTRIES[@]}"; do
        IFS='|' read -r scope version dir <<<"$line"
        if [ -n "$LATEST_VERSION" ] && [ "$version" != "$LATEST_VERSION" ]; then
          warn "  ! Skills Triple Performance $version (${dir:-tous les dossiers}) : version $LATEST_VERSION disponible"
        else
          ok "Skills Triple Performance $version (${dir:-tous les dossiers})"
        fi
      done
      ;;
  esac
}

show_workdir_hint() {
  local line scope version dir
  [ "${#SKILL_ENTRIES[@]}" -gt 0 ] || return 0
  IFS='|' read -r scope version dir <<<"${SKILL_ENTRIES[0]}"
  if [ -n "$dir" ]; then info "Pour travailler, lancez claude dans ce dossier : cd \"$dir\""; fi
}

show_first_steps() {
  local scope version dir
  IFS='|' read -r scope version dir <<<"${SKILL_ENTRIES[0]}"
  info ""
  info "Pour commencer :"
  info "  1. Ouvrez un nouveau terminal et placez-vous dans votre dossier de travail :"
  info "       cd \"$dir\""
  info "  2. Lancez Claude Code (au premier lancement, connectez-vous à votre compte Claude) :"
  info "       claude"
  info "  3. Demandez-lui par exemple d'importer une vidéo YouTube :"
  info "       Importe cette vidéo : https://www.youtube.com/watch?v=KZ5Tz3IGoSI"
}

# Le script a déjà le bon PATH : claude démarre ici, sans nouveau terminal
offer_claude() {
  local answer="" scope version dir
  if [ "$CHECK_REQUESTED" -eq 1 ] || [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ] || [ ! -t 1 ]; then return 0; fi
  [ "${#SKILL_ENTRIES[@]}" -gt 0 ] || return 0
  IFS='|' read -r scope version dir <<<"${SKILL_ENTRIES[0]}"
  [ -n "$dir" ] || return 0
  info ""
  printf 'Lancer Claude Code maintenant dans votre dossier de travail ? [O/n] '
  read -r answer
  case "$answer" in
    ""|o|O|oui|y|Y|yes) cd "$dir"; exec claude ;;
  esac
}

choose_workdir() {
  local answer=""
  if [ -z "$WORKDIR" ]; then
    WORKDIR="$DEFAULT_WORKDIR"
    if [ "$ASSUME_YES" -eq 0 ]; then
      printf 'Dossier de travail Triple Performance [%s] : ' "$DEFAULT_WORKDIR"
      read -r answer
      if [ -n "$answer" ]; then WORKDIR="$answer"; fi
    fi
  fi
  case "$WORKDIR" in
    \~|\~/*) WORKDIR="$HOME${WORKDIR#\~}" ;;
    /*) ;;
    *) WORKDIR="$PWD/$WORKDIR" ;;
  esac
}

# Contexte pour les demandes ambiguës ; jamais écrasé, l'utilisateur peut l'avoir complété
write_workspace_guide() {
  local file="$WORKDIR/CLAUDE.md"
  if [ -e "$file" ]; then return 0; fi
  cat >"$file" <<'EOF'
# Espace de travail Triple Performance

Ce dossier sert à contribuer à Triple Performance (https://wiki.tripleperformance.fr/), le wiki collaboratif de l'agroécologie.

- Sauf indication contraire, mes demandes concernent ce wiki : utilise les skills Triple Performance.
- Réponds en français, sans jargon technique.
- Je dépose ici mes PDF, images et fichiers Excel.
EOF
}

install_skills() {
  info "Installation des skills dans $WORKDIR..."
  mkdir -p "$WORKDIR"
  if (
    cd "$WORKDIR"
    claude plugin marketplace add "$MARKETPLACE_REPO" --scope local
    claude plugin install "$PLUGIN_ID" --scope local
  ); then
    SKILLS_INSTALLED=1
    write_workspace_guide
  else
    warn "Échec de l'installation des skills."
  fi
}

update_skills() {
  local line scope version dir
  for line in "${SKILL_ENTRIES[@]}"; do
    IFS='|' read -r scope version dir <<<"$line"
    [ "$version" != "$LATEST_VERSION" ] || continue
    info "Mise à jour des skills (${dir:-tous les dossiers})..."
    # Depuis le dossier concerné : ailleurs, la CLI répond que tout est à jour
    (
      cd "${dir:-.}"
      claude plugin marketplace update "$MARKETPLACE_NAME"
      claude plugin update "$PLUGIN_ID" --scope "$scope"
    ) || warn "Échec de la mise à jour des skills."
  done
}

# --- Vérification ----------------------------------------------------------

MISSING=()

check_tools() {
  local entry key cmds label
  MISSING=()
  info ""
  info "Vérification des outils :"
  for entry in "${TOOLS[@]}"; do
    IFS='|' read -r key cmds label <<<"$entry"
    if has_any "$cmds"; then
      ok "$label"
    else
      ko "$label — manquant"
      MISSING+=("$key")
    fi
  done
  show_skills
  show_wiki_login

  if [ "${#MISSING[@]}" -eq 0 ] && [ "$SKILL_STATE" != "missing" ]; then
    # Une mise à jour disponible n'empêche pas de travailler : pas d'échec avec --check
    if [ "$SKILL_STATE" = "update" ] && [ "$CHECK_ONLY" -eq 0 ]; then return 0; fi
    info ""
    info "Tout est installé."
    if ! mediawiki version >/dev/null 2>&1; then
      warn "La commande mediawiki est présente mais ne répond pas correctement."
    fi
    if [ "$SKILL_STATE" = "update" ]; then
      info "Mise à jour des skills disponible : relancez le script d'installation (sans --check)."
    fi
    if [ "$SKILLS_INSTALLED" -eq 1 ]; then
      show_first_steps
    else
      show_workdir_hint
    fi
    offer_claude
    exit 0
  fi

  if [ "$CHECK_ONLY" -eq 1 ]; then
    info ""
    if [ "${#MISSING[@]}" -gt 0 ]; then info "Outils manquants : ${MISSING[*]}"; fi
    if [ "$SKILL_STATE" = "missing" ]; then info "Skills Triple Performance non installées."; fi
    info "Lancez le script d'installation (sans --check) pour les installer."
    exit 1
  fi
}

check_tools

# --- Installation ----------------------------------------------------------

SUDO=""
if [ "$PM" != "brew" ] && [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

ensure_brew() {
  command -v brew >/dev/null 2>&1 && return 0
  warn "Homebrew n'est pas installé : il est nécessaire sur macOS."
  confirm "Installer Homebrew (https://brew.sh) ?" || { info "Abandon."; exit 1; }
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Rendre brew disponible dans cette session (Apple Silicon puis Intel)
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_packages() {
  case "$PM" in
    apt)    $SUDO apt-get update && $SUDO apt-get install -y "$@" ;;
    dnf)    $SUDO dnf install -y "$@" ;;
    pacman) $SUDO pacman -S --needed --noconfirm "$@" ;;
    zypper) $SUDO zypper --non-interactive install "$@" ;;
    brew)   brew install "$@" ;;
    *)
      warn "Aucun gestionnaire de paquets pris en charge détecté."
      warn "Installez manuellement : $*"
      return 1
      ;;
  esac
}

# Modules Python sans paquet système (Homebrew) : installés par pip pour l'utilisateur
pip_install() {
  python3 -m pip install --user "$@" \
    || python3 -m pip install --user --break-system-packages "$@"
}

PACKAGES=()
PIP_MODULES=()
NEED_MEDIAWIKI=0
NEED_YTDLP=0
NEED_DENO=0
NEED_CLAUDE=0
for key in ${MISSING[@]+"${MISSING[@]}"}; do
  if [ "$key" = "mediawiki" ]; then
    NEED_MEDIAWIKI=1
  elif [ "$key" = "claude" ]; then
    NEED_CLAUDE=1
  elif [ "$key" = "ytdlp" ] && [ "$PM" != "brew" ]; then
    NEED_YTDLP=1
  elif [ "$key" = "deno" ] && [ "$PM" != "brew" ]; then
    NEED_DENO=1
    has_any unzip || PACKAGES+=(unzip)
  elif [ "$key" = "openpyxl" ] && { [ "$PM" = "brew" ] || [ -z "$PM" ]; }; then
    PIP_MODULES+=("$key")
  else
    PACKAGES+=("$(package_name "$key")")
  fi
done

info ""
[ "${#PACKAGES[@]}" -gt 0 ] && info "Paquets à installer via $PM : ${PACKAGES[*]}"
[ "${#PIP_MODULES[@]}" -gt 0 ] && info "Modules Python à installer via pip (--user) : ${PIP_MODULES[*]}"
[ "$NEED_MEDIAWIKI" -eq 1 ] && info "CLI mediawiki à installer depuis $MEDIAWIKI_INSTALLER"
[ "$NEED_YTDLP" -eq 1 ] && info "yt-dlp à installer dans ~/.local/bin depuis $YTDLP_URL"
[ "$NEED_DENO" -eq 1 ] && info "Deno à installer dans ~/.deno depuis $DENO_INSTALLER"
[ "$NEED_CLAUDE" -eq 1 ] && info "Claude Code à installer dans ~/.local/bin depuis $CLAUDE_INSTALLER"
if [ "$SKILL_STATE" = "missing" ] || [ "$SKILL_STATE" = "unknown" ]; then
  choose_workdir
  info "Skills à installer dans : $WORKDIR"
fi
if [ "${#MISSING[@]}" -gt 0 ] || [ "$SKILL_STATE" != "update" ]; then
  confirm "Continuer ?" || { info "Abandon."; exit 1; }
fi

if [ "${#PACKAGES[@]}" -gt 0 ]; then
  [ "$PM" = "brew" ] && ensure_brew
  install_packages "${PACKAGES[@]}"
fi

if [ "${#PIP_MODULES[@]}" -gt 0 ]; then
  pip_install "${PIP_MODULES[@]}"
fi

if [ "$NEED_MEDIAWIKI" -eq 1 ]; then
  curl -fsSL "$MEDIAWIKI_INSTALLER" | sh
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) warn "Ajoutez ~/.local/bin à votre PATH puis ouvrez un nouveau terminal." ;;
  esac
fi

if [ "$NEED_YTDLP" -eq 1 ]; then
  mkdir -p "$HOME/.local/bin"
  curl -fL "$YTDLP_URL" -o "$HOME/.local/bin/yt-dlp"
  chmod +x "$HOME/.local/bin/yt-dlp"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) warn "Ajoutez ~/.local/bin à votre PATH puis ouvrez un nouveau terminal." ;;
  esac
fi

if [ "$NEED_DENO" -eq 1 ]; then
  # -y : ajoute aussi ~/.deno/bin au PATH dans le fichier de démarrage du shell
  curl -fsSL "$DENO_INSTALLER" | sh -s -- -y
  warn "Ouvrez un nouveau terminal pour que la commande deno soit disponible."
fi

if [ "$NEED_CLAUDE" -eq 1 ]; then
  # Sans sudo : l'installeur officiel écrit dans le dossier de l'utilisateur
  curl -fsSL "$CLAUDE_INSTALLER" | bash
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) warn "Ajoutez ~/.local/bin à votre PATH puis ouvrez un nouveau terminal." ;;
  esac
fi

# Les installeurs modifient le fichier de démarrage du shell, pas cette session
export PATH="$HOME/.local/bin:$HOME/.deno/bin:$PATH"

read_skills
case "$SKILL_STATE" in
  missing) install_skills ;;
  update)  update_skills ;;
esac

info ""
info "Installation terminée. Vérification finale :"
CHECK_ONLY=1
check_tools
