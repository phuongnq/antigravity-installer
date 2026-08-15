#!/usr/bin/env bash
# ==============================================================================
# Standalone Google Antigravity 2.0 (Hub) & Antigravity IDE Installer for Linux x64
# ==============================================================================
#
# Supports:
#   - Full Installation & Upgrades
#   - Component selection (--hub-only, --ide-only)
#   - Version checks (--check)
#   - Clean Uninstallation (--uninstall)
#   - Custom version/URL overrides via environment variables
#
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Default Version URLs & Configuration
# ------------------------------------------------------------------------------
DEFAULT_HUB_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.8.1-6512087774658560/linux-x64/Antigravity.tar.gz"
DEFAULT_IDE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/linux-x64/Antigravity%20IDE.tar.gz"

HUB_URL="${ANTIGRAVITY_HUB_URL:-$DEFAULT_HUB_URL}"
IDE_URL="${ANTIGRAVITY_IDE_URL:-$DEFAULT_IDE_URL}"

INSTALL_DIR="${ANTIGRAVITY_INSTALL_DIR:-/opt/antigravity}"
BIN_DIR="${ANTIGRAVITY_BIN_DIR:-/usr/local/bin}"
APPLICATIONS_DIR="/usr/share/applications"
PIXMAPS_DIR="/usr/share/pixmaps"
ICONS_BASE_DIR="/usr/share/icons/hicolor"

# Terminal formatting
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo -e "\n${BOLD}${CYAN}==>${RESET} ${BOLD}$*${RESET}"; }

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

show_help() {
  echo -e "${BOLD}Google Antigravity 2.0 & IDE Linux Installer / Updater${RESET}"
  echo ""
  echo -e "${BOLD}USAGE:${RESET}"
  echo -e "  sudo ./install_antigravity.sh [OPTIONS]"
  echo ""
  echo -e "${BOLD}OPTIONS:${RESET}"
  echo -e "  -u, --update        Update/upgrade existing Antigravity installation"
  echo -e "      --hub-only      Install or update only Antigravity Hub (2.0)"
  echo -e "      --ide-only      Install or update only Antigravity IDE"
  echo -e "  -c, --check         Display installed versions vs available installer versions"
  echo -e "      --uninstall     Completely remove Antigravity Hub, IDE, symlinks, and launchers"
  echo -e "  -f, --force         Bypass running process and architecture warnings"
  echo -e "  -h, --help          Show this help message"
  echo ""
  echo -e "${BOLD}ENVIRONMENT VARIABLES:${RESET}"
  echo -e "  ANTIGRAVITY_HUB_URL       Custom tarball URL for Antigravity Hub"
  echo -e "  ANTIGRAVITY_IDE_URL       Custom tarball URL for Antigravity IDE"
  echo -e "  ANTIGRAVITY_INSTALL_DIR   Target installation folder (default: /opt/antigravity)"
  echo -e "  ANTIGRAVITY_BIN_DIR       Target binary symlink folder (default: /usr/local/bin)"
  echo ""
  echo -e "${BOLD}EXAMPLES:${RESET}"
  echo -e "  sudo ./install_antigravity.sh                # Install or update both Hub & IDE"
  echo -e "  sudo ./install_antigravity.sh --ide-only     # Install or update IDE only"
  echo -e "  ./install_antigravity.sh --check             # Check current installation status"
  echo -e "  sudo ./install_antigravity.sh --uninstall    # Clean uninstallation"
}

ORIG_ARGS=("$@")

check_root() {
  if [ "$EUID" -ne 0 ]; then
    log_error "This operation requires administrative privileges."
    if [ ${#ORIG_ARGS[@]} -gt 0 ]; then
      log_error "Please run with sudo or as root: sudo $0 ${ORIG_ARGS[*]}"
    else
      log_error "Please run with sudo or as root: sudo $0"
    fi
    exit 1
  fi
}

check_architecture() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64)
      # Supported
      ;;
    *)
      if [ -z "${ANTIGRAVITY_HUB_URL:-}" ] && [ -z "${ANTIGRAVITY_IDE_URL:-}" ]; then
        log_warn "Detected architecture: ${arch}."
        log_warn "Default pre-compiled packages are built for Linux x64 (x86_64)."
        log_warn "If you have custom package URLs for your architecture, provide ANTIGRAVITY_HUB_URL / ANTIGRAVITY_IDE_URL."
        if [ "${FORCE_FLAG}" -ne 1 ]; then
          log_error "Aborting. Re-run with --force if you wish to proceed anyway."
          exit 1
        fi
      fi
      ;;
  esac
}

ensure_dependencies() {
  local missing=()
  for cmd in curl tar python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -eq 0 ]; then
    return 0
  fi

  log_info "Missing required extraction tools: ${missing[*]}. Attempting automatic installation..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y "${missing[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y "${missing[@]}"
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "${missing[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm "${missing[@]}"
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install "${missing[@]}"
  elif command -v apk >/dev/null 2>&1; then
    apk add "${missing[@]}"
  else
    log_error "Could not auto-install: ${missing[*]}. Please install them using your package manager and re-run."
    exit 1
  fi
}

check_running_processes() {
  if [ "${FORCE_FLAG}" -eq 1 ]; then
    return 0
  fi
  local running=()
  if pgrep -f "antigravity/hub/antigravity" >/dev/null 2>&1 || pgrep -x "antigravity" >/dev/null 2>&1; then
    running+=("Antigravity Hub")
  fi
  if pgrep -f "antigravity/ide/antigravity-ide" >/dev/null 2>&1 || pgrep -x "antigravity-ide" >/dev/null 2>&1; then
    running+=("Antigravity IDE")
  fi

  if [ ${#running[@]} -gt 0 ]; then
    log_warn "Active running instances detected: ${running[*]}."
    log_warn "Overwriting files while apps are open may cause runtime issues."
    if [ -t 0 ]; then
      read -rp "Would you like to continue anyway? [y/N] " confirm
      case "${confirm}" in
        [yY]|[yY][eE][sS]) ;;
        *) log_info "Installation / update cancelled."; exit 0 ;;
      esac
    fi
  fi
}

# Helper function to extract a file from an ASAR archive using python3
extract_asar_file() {
  local asar_file="$1"
  local target_file="$2"
  local output_file="$3"

  if [ ! -f "${asar_file}" ]; then
    return 1
  fi

  python3 - "${asar_file}" "${target_file}" "${output_file}" << 'PYEOF' 2>/dev/null || return 1
import struct, json, os, sys

asar_path = sys.argv[1]
target_file = sys.argv[2]
out_path = sys.argv[3]

try:
    with open(asar_path, "rb") as f:
        header = f.read(16)
        u1, u2, u3, u4 = struct.unpack("<IIII", header)
        json_bytes = f.read(u4)
        tree = json.loads(json_bytes.decode("utf-8"))
        
        node = tree
        for part in target_file.split("/"):
            node = node.get("files", {}).get(part, {})
        
        if "size" in node and "offset" in node:
            f.seek(8 + u2 + int(node["offset"]))
            data = f.read(int(node["size"]))
            os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
            with open(out_path, "wb") as out:
                out.write(data)
            sys.exit(0)
except Exception:
    sys.exit(1)
sys.exit(1)
PYEOF
}

get_installed_hub_version() {
  local asar_file="${INSTALL_DIR}/hub/resources/app.asar"
  if [ -f "${asar_file}" ] && command -v python3 >/dev/null 2>&1; then
    python3 - "${asar_file}" << 'PYEOF' 2>/dev/null || echo "Unknown"
import struct, json, sys
try:
    with open(sys.argv[1], "rb") as f:
        header = f.read(16)
        u1, u2, u3, u4 = struct.unpack("<IIII", header)
        tree = json.loads(f.read(u4).decode("utf-8"))
        node = tree.get("files", {}).get("package.json", {})
        if "size" in node and "offset" in node:
            f.seek(8 + u2 + int(node["offset"]))
            pkg = json.loads(f.read(int(node["size"])).decode("utf-8"))
            print(pkg.get("version", "Unknown"))
            sys.exit(0)
except Exception:
    pass
print("Unknown")
PYEOF
  elif [ -d "${INSTALL_DIR}/hub" ]; then
    echo "Installed (version unknown)"
  else
    echo "Not installed"
  fi
}

get_installed_ide_version() {
  local prod_json="${INSTALL_DIR}/ide/resources/app/product.json"
  if [ -f "${prod_json}" ] && command -v python3 >/dev/null 2>&1; then
    python3 - "${prod_json}" << 'PYEOF' 2>/dev/null || echo "Unknown"
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
        ide_v = d.get("ideVersion", "")
        core_v = d.get("version", "")
        if ide_v:
            print(f"{ide_v} (VS Code {core_v})")
        else:
            print(core_v or "Unknown")
        sys.exit(0)
except Exception:
    pass
print("Unknown")
PYEOF
  elif [ -d "${INSTALL_DIR}/ide" ]; then
    echo "Installed (version unknown)"
  else
    echo "Not installed"
  fi
}

show_status() {
  echo -e "\n${BOLD}Antigravity Installation Status:${RESET}"
  echo -e "  • Target Install Dir : ${CYAN}${INSTALL_DIR}${RESET}"
  echo -e "  • Binary Symlinks    : ${CYAN}${BIN_DIR}${RESET}"
  echo -e "  • Antigravity Hub    : ${GREEN}$(get_installed_hub_version)${RESET}"
  echo -e "  • Antigravity IDE    : ${GREEN}$(get_installed_ide_version)${RESET}"
  echo ""
  echo -e "${BOLD}Default Installer Versions:${RESET}"
  echo -e "  • Hub Package URL    : ${DEFAULT_HUB_URL}"
  echo -e "  • IDE Package URL    : ${DEFAULT_IDE_URL}"
  echo ""
}

# ------------------------------------------------------------------------------
# Core Installation Routines
# ------------------------------------------------------------------------------

install_hub() {
  log_step "Installing / Updating Antigravity Hub (2.0)..."
  
  local hub_tar="${TMP_DIR}/hub.tar.gz"
  local hub_stage="${TMP_DIR}/stage_hub"
  mkdir -p "${hub_stage}"

  log_info "Downloading Antigravity Hub..."
  curl -fsSL --retry 3 --connect-timeout 15 --progress-bar "${HUB_URL}" -o "${hub_tar}"

  log_info "Extracting Hub archive..."
  tar -xzf "${hub_tar}" -C "${hub_stage}" --strip-components=1 2>/dev/null || tar -xzf "${hub_tar}" -C "${hub_stage}"

  log_info "Staging to ${INSTALL_DIR}/hub..."
  mkdir -p "${INSTALL_DIR}/hub"
  rm -rf "${INSTALL_DIR}/hub"/*
  cp -a "${hub_stage}/." "${INSTALL_DIR}/hub/"

  # Configure chrome-sandbox permissions for Hub
  if [ -f "${INSTALL_DIR}/hub/chrome-sandbox" ]; then
    chown root:root "${INSTALL_DIR}/hub/chrome-sandbox"
    chmod 4755 "${INSTALL_DIR}/hub/chrome-sandbox"
    log_info "Configured chrome-sandbox permissions for Hub (mode 4755, root:root)"
  fi

  # Extract and register Hub icons
  local hub_icon="${INSTALL_DIR}/hub/icon.png"
  if extract_asar_file "${INSTALL_DIR}/hub/resources/app.asar" "icon.png" "${hub_icon}"; then
    mkdir -p "${PIXMAPS_DIR}"
    cp -f "${hub_icon}" "${PIXMAPS_DIR}/antigravity.png"
    for size_dir in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512 scalable; do
      mkdir -p "${ICONS_BASE_DIR}/${size_dir}/apps"
      cp -f "${hub_icon}" "${ICONS_BASE_DIR}/${size_dir}/apps/antigravity.png" 2>/dev/null || true
    done
    log_info "Registered Antigravity Hub icons"
  else
    log_warn "Could not extract icon from Hub app.asar"
  fi

  # Create CLI symlinks for Hub (both 'antigravity' and 'agy')
  local hub_bin
  hub_bin=$(find "${INSTALL_DIR}/hub" -maxdepth 1 -type f \( -name "antigravity" -o -name "Antigravity" \) -perm /111 | head -n 1)
  if [ -n "${hub_bin}" ]; then
    ln -sf "${hub_bin}" "${BIN_DIR}/antigravity"
    ln -sf "${hub_bin}" "${BIN_DIR}/agy"
    chmod +x "${hub_bin}"
    log_info "Symlinked Hub CLI to ${BIN_DIR}/antigravity and ${BIN_DIR}/agy"
  else
    log_warn "Could not locate Hub executable binary in ${INSTALL_DIR}/hub"
  fi

  # Desktop launcher for Hub
  log_info "Registering desktop entry for Antigravity Hub..."
  cat <<EOF > "${APPLICATIONS_DIR}/antigravity.desktop"
[Desktop Entry]
Name=Antigravity
Comment=Antigravity Agentic Platform & Hub
GenericName=Agentic Development Hub
Exec=${BIN_DIR}/antigravity %U
Icon=antigravity
Terminal=false
Type=Application
Categories=Development;
StartupNotify=true
StartupWMClass=antigravity
MimeType=x-scheme-handler/antigravity;
EOF
  chmod 644 "${APPLICATIONS_DIR}/antigravity.desktop"
}

install_ide() {
  log_step "Installing / Updating Antigravity IDE..."
  
  local ide_tar="${TMP_DIR}/ide.tar.gz"
  local ide_stage="${TMP_DIR}/stage_ide"
  mkdir -p "${ide_stage}"

  log_info "Downloading Antigravity IDE..."
  curl -fsSL --retry 3 --connect-timeout 15 --progress-bar "${IDE_URL}" -o "${ide_tar}"

  log_info "Extracting IDE archive..."
  tar -xzf "${ide_tar}" -C "${ide_stage}" --strip-components=1 2>/dev/null || tar -xzf "${ide_tar}" -C "${ide_stage}"

  log_info "Staging to ${INSTALL_DIR}/ide..."
  mkdir -p "${INSTALL_DIR}/ide"
  rm -rf "${INSTALL_DIR}/ide"/*
  cp -a "${ide_stage}/." "${INSTALL_DIR}/ide/"

  # Configure chrome-sandbox permissions for IDE
  if [ -f "${INSTALL_DIR}/ide/chrome-sandbox" ]; then
    chown root:root "${INSTALL_DIR}/ide/chrome-sandbox"
    chmod 4755 "${INSTALL_DIR}/ide/chrome-sandbox"
    log_info "Configured chrome-sandbox permissions for IDE (mode 4755, root:root)"
  fi

  # Locate and register IDE icons
  local ide_icon="${INSTALL_DIR}/ide/icon.png"
  local ide_res_dir="${INSTALL_DIR}/ide/resources/app/resources/linux"
  local ide_icon_source=""

  if [ -f "${ide_res_dir}/code.png" ]; then
    ide_icon_source="${ide_res_dir}/code.png"
  elif [ -f "${ide_res_dir}/icon.png" ]; then
    ide_icon_source="${ide_res_dir}/icon.png"
  elif [ -f "${INSTALL_DIR}/hub/icon.png" ]; then
    ide_icon_source="${INSTALL_DIR}/hub/icon.png"
  fi

  if [ -n "${ide_icon_source}" ] && [ -f "${ide_icon_source}" ]; then
    mkdir -p "${PIXMAPS_DIR}"
    cp -f "${ide_icon_source}" "${ide_icon}"
    cp -f "${ide_icon_source}" "${PIXMAPS_DIR}/antigravity-ide.png"
    for size_dir in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512 scalable; do
      mkdir -p "${ICONS_BASE_DIR}/${size_dir}/apps"
      cp -f "${ide_icon_source}" "${ICONS_BASE_DIR}/${size_dir}/apps/antigravity-ide.png" 2>/dev/null || true
    done
    log_info "Registered Antigravity IDE icons from ${ide_icon_source}"
  else
    log_warn "Could not locate IDE icon source"
  fi

  # Create symlinks for IDE CLI (prioritizing bin/antigravity-ide wrapper script)
  local ide_bin=""
  if [ -x "${INSTALL_DIR}/ide/bin/antigravity-ide" ]; then
    ide_bin="${INSTALL_DIR}/ide/bin/antigravity-ide"
  else
    ide_bin=$(find "${INSTALL_DIR}/ide" -maxdepth 2 -type f \( -name "antigravity-ide" -o -name "Antigravity IDE" -o -name "antigravity" -o -name "code" \) -perm /111 | head -n 1)
  fi

  if [ -n "${ide_bin}" ]; then
    ln -sf "${ide_bin}" "${BIN_DIR}/antigravity-ide"
    ln -sf "${ide_bin}" "${BIN_DIR}/agy-ide"
    chmod +x "${ide_bin}"
    log_info "Symlinked IDE CLI to ${BIN_DIR}/antigravity-ide and ${BIN_DIR}/agy-ide"
  else
    log_warn "Could not locate IDE executable binary. Check ${INSTALL_DIR}/ide."
  fi

  # Register shell auto-completions
  local ide_comp_dir="${INSTALL_DIR}/ide/resources/completions"
  if [ -d "/usr/share/bash-completion/completions" ] && [ -f "${ide_comp_dir}/bash/antigravity-ide" ]; then
    cp -f "${ide_comp_dir}/bash/antigravity-ide" "/usr/share/bash-completion/completions/antigravity-ide"
    ln -sf "/usr/share/bash-completion/completions/antigravity-ide" "/usr/share/bash-completion/completions/agy-ide" 2>/dev/null || true
    log_info "Installed Bash auto-completions"
  fi
  if [ -d "/usr/share/zsh/vendor-completions" ] && [ -f "${ide_comp_dir}/zsh/_antigravity-ide" ]; then
    cp -f "${ide_comp_dir}/zsh/_antigravity-ide" "/usr/share/zsh/vendor-completions/_antigravity-ide"
    ln -sf "/usr/share/zsh/vendor-completions/_antigravity-ide" "/usr/share/zsh/vendor-completions/_agy-ide" 2>/dev/null || true
    log_info "Installed Zsh auto-completions"
  fi

  # Desktop launcher for IDE
  log_info "Registering desktop entry for Antigravity IDE..."
  cat <<EOF > "${APPLICATIONS_DIR}/antigravity-ide.desktop"
[Desktop Entry]
Name=Antigravity IDE
Comment=Antigravity AI-First Development Environment
GenericName=Integrated Development Environment
Exec=${BIN_DIR}/antigravity-ide %F
Icon=antigravity-ide
Terminal=false
Type=Application
StartupNotify=true
StartupWMClass=antigravity-ide
Categories=Development;IDE;
MimeType=text/plain;inode/directory;x-scheme-handler/antigravity-ide;
Actions=new-empty-window;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=${BIN_DIR}/antigravity-ide --new-window %F
Icon=antigravity-ide
EOF
  chmod 644 "${APPLICATIONS_DIR}/antigravity-ide.desktop"
}

uninstall_all() {
  log_step "Uninstalling Google Antigravity..."
  check_root

  log_info "Removing binary symlinks..."
  rm -f "${BIN_DIR}/antigravity" "${BIN_DIR}/agy" "${BIN_DIR}/antigravity-ide" "${BIN_DIR}/agy-ide"

  log_info "Removing desktop launchers..."
  rm -f "${APPLICATIONS_DIR}/antigravity.desktop" "${APPLICATIONS_DIR}/antigravity-ide.desktop"

  log_info "Removing application icons..."
  rm -f "${PIXMAPS_DIR}/antigravity.png" "${PIXMAPS_DIR}/antigravity-ide.png"
  for size_dir in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512 scalable; do
    rm -f "${ICONS_BASE_DIR}/${size_dir}/apps/antigravity.png" 2>/dev/null || true
    rm -f "${ICONS_BASE_DIR}/${size_dir}/apps/antigravity-ide.png" 2>/dev/null || true
  done

  log_info "Removing shell completions..."
  rm -f "/usr/share/bash-completion/completions/antigravity-ide" "/usr/share/bash-completion/completions/agy-ide" 2>/dev/null || true
  rm -f "/usr/share/zsh/vendor-completions/_antigravity-ide" "/usr/share/zsh/vendor-completions/_agy-ide" 2>/dev/null || true

  log_info "Removing core files in ${INSTALL_DIR}..."
  rm -rf "${INSTALL_DIR}"

  log_info "Refreshing system caches..."
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "${APPLICATIONS_DIR}" 2>/dev/null || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -t "${ICONS_BASE_DIR}" 2>/dev/null || true

  log_info "Uninstallation complete!"
  echo -e "User settings in ${CYAN}~/.gemini${RESET} and ${CYAN}~/.config${RESET} were preserved."
}

# ------------------------------------------------------------------------------
# Argument Parsing & Main Controller
# ------------------------------------------------------------------------------

TARGET_HUB=1
TARGET_IDE=1
FORCE_FLAG=0
ACTION="install"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -c|--check|--status)
      show_status
      exit 0
      ;;
    -u|--update|--upgrade)
      ACTION="install"
      ;;
    --hub-only)
      TARGET_HUB=1
      TARGET_IDE=0
      ;;
    --ide-only)
      TARGET_HUB=0
      TARGET_IDE=1
      ;;
    --uninstall)
      ACTION="uninstall"
      ;;
    -f|--force)
      FORCE_FLAG=1
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
  shift
done

if [ "${ACTION}" = "uninstall" ]; then
  uninstall_all
  exit 0
fi

# ------------------------------------------------------------------------------
# Pre-Flight Checks & Execution
# ------------------------------------------------------------------------------

check_root "$@"
check_architecture
check_running_processes
ensure_dependencies

TMP_DIR="$(mktemp -d /tmp/antigravity_installer.XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${INSTALL_DIR}" "${BIN_DIR}" "${APPLICATIONS_DIR}" "${PIXMAPS_DIR}"

if [ "${TARGET_HUB}" -eq 1 ]; then
  install_hub
fi

if [ "${TARGET_IDE}" -eq 1 ]; then
  install_ide
fi

log_step "Refreshing Desktop & Icon Databases..."
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "${APPLICATIONS_DIR}" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -t "${ICONS_BASE_DIR}" 2>/dev/null || true

echo -e "\n${BOLD}${GREEN}✔ Installation / Update Successful!${RESET}"
show_status
echo -e "You can launch via:"
echo -e "  • ${BOLD}Antigravity Hub (2.0)${RESET} : ${CYAN}antigravity${RESET} or ${CYAN}agy${RESET} (or application menu)"
echo -e "  • ${BOLD}Antigravity IDE${RESET}       : ${CYAN}antigravity-ide .${RESET} or ${CYAN}agy-ide .${RESET} (or application menu)"
