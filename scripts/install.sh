#!/usr/bin/env bash
# Installe les outils utilisés par les skills Triple Performance.
# Linux (apt, dnf, pacman, zypper), macOS (Homebrew) et WSL.
#
# Usage : ./scripts/install.sh [--check] [--yes]
#   --check  vérifie seulement la présence des outils, n'installe rien
#   --yes    ne demande pas de confirmation avant d'installer

set -euo pipefail

CHECK_ONLY=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Option inconnue : $arg" >&2; exit 2 ;;
  esac
done

MEDIAWIKI_INSTALLER="https://raw.githubusercontent.com/neayi/Mediawiki-LLM-Cli/main/install.sh"

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
    warn "Windows détecté : utilisez plutôt scripts\\install.ps1 dans PowerShell."
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
  "curl|curl|curl (appels API)"
  "git|git|git"
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

# --- Vérification ----------------------------------------------------------

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

if [ "${#MISSING[@]}" -eq 0 ]; then
  info ""
  info "Tout est installé."
  if ! mediawiki version >/dev/null 2>&1; then
    warn "La commande mediawiki est présente mais ne répond pas correctement."
  fi
  info "Pensez à vous connecter au wiki : mediawiki login https://wiki.tripleperformance.fr"
  exit 0
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  info ""
  info "Outils manquants : ${MISSING[*]}"
  info "Lancez ./scripts/install.sh pour les installer."
  exit 1
fi

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
for key in "${MISSING[@]}"; do
  if [ "$key" = "mediawiki" ]; then
    NEED_MEDIAWIKI=1
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
confirm "Continuer ?" || { info "Abandon."; exit 1; }

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

info ""
info "Installation terminée. Vérification finale :"
exec "$0" --check
