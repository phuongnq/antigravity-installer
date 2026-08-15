# Google Antigravity Installer for Linux

[![Platform: Linux x64](https://img.shields.io/badge/Platform-Linux%20x64-blue.svg)](https://antigravity.google)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

An automated installer and updater script for **Google Antigravity 2.0 (Hub)** and **Antigravity IDE** on Linux x64 systems.

---

## 🌟 Included Applications

| Application | Command(s) | Description |
| :--- | :--- | :--- |
| **Antigravity 2.0 (Hub)** | `agy`, `antigravity` | The dedicated desktop application for orchestrating and managing AI agents, projects, workflows, and cron tasks. |
| **Antigravity IDE** | `antigravity-ide`, `agy-ide` | AI-first development environment (built on VS Code) featuring passive code completions, inline edits (`Ctrl+I`), and collaborative agent sidebar workflows. |

---

## 🚀 Quick Start

### 1. One-Line Installation (Recommended)

Run the installer directly via `curl` and `bash`:

```bash
curl -fsSL https://raw.githubusercontent.com/phuongnq/antigravity-installer/main/install_antigravity.sh | sudo bash
```

### 2. Manual Installation via Git

```bash
git clone https://github.com/phuongnq/antigravity-installer.git
cd antigravity-installer
chmod +x install_antigravity.sh
sudo ./install_antigravity.sh
```

---

## 💡 What the Installer Does

1. **Live Release Discovery**: Automatically discovers and resolves the latest download links for your architecture directly from [https://antigravity.google/download](https://antigravity.google/download), with built-in fallbacks if offline.
2. **Multi-Architecture Support**: Supports both Linux `x86_64` (`x64`) and `aarch64` (`ARM64`).
3. **Dependency Resolution**: Automatically verifies and installs core extraction tools (`curl`, `tar`, `python3`) across major Linux distributions (`apt`, `dnf`, `pacman`, `zypper`, `apk`).
4. **Safe Staging**: Downloads and extracts official releases of Antigravity Hub and Antigravity IDE to `/opt/antigravity`.
5. **Sandbox Security**: Sets proper permissions (`4755 root:root`) for Electron `chrome-sandbox`.
6. **CLI Symlinks**: Configures terminal commands in `/usr/local/bin`:
   - `agy` & `antigravity` → Antigravity Hub
   - `antigravity-ide` & `agy-ide` → Antigravity IDE CLI launcher
7. **Desktop & Menu Launchers**: Registers `.desktop` files in `/usr/share/applications` with proper `StartupWMClass`, `GenericName`, and URL scheme handlers (`x-scheme-handler/antigravity`).
8. **System Icons**: Extracts and installs high-resolution icons into `/usr/share/pixmaps` and `/usr/share/icons/hicolor/`.
9. **Shell Auto-Completions**: Installs Bash and Zsh auto-completions for `antigravity-ide` and `agy-ide`.

---

## 🔄 Updating / Upgrading

### Is updating supported?
**Yes!** Updating is completely safe and non-destructive.
- All user configurations, projects, credentials, and agent states live in `~/.gemini/`, `~/.config/Antigravity/`, and `~/.config/antigravity-ide/`.
- Running the installer replaces only the application binaries in `/opt/antigravity/` without altering your personal settings or workspace data.

### Check Current vs Available Versions
To check what versions you currently have installed:

```bash
./install_antigravity.sh --check
```

### Update Both Applications
To upgrade to the latest versions:

```bash
sudo ./install_antigravity.sh --update
```

### Update Only One Application
You can selectively install or update just the Hub or just the IDE:

```bash
# Update Antigravity Hub only
sudo ./install_antigravity.sh --hub-only

# Update Antigravity IDE only
sudo ./install_antigravity.sh --ide-only
```

---

## 🛠️ Command-Line Options

```
Google Antigravity 2.0 & IDE Linux Installer / Updater

USAGE:
  sudo ./install_antigravity.sh [OPTIONS]

OPTIONS:
  -u, --update        Update/upgrade existing Antigravity installation
      --hub-only      Install or update only Antigravity Hub (2.0)
      --ide-only      Install or update only Antigravity IDE
  -c, --check         Display installed versions vs available installer versions
      --uninstall     Completely remove Antigravity Hub, IDE, symlinks, and launchers
  -f, --force         Bypass running process and architecture warnings
  -h, --help          Show this help message
```

---

## ⚙️ Environment Variables & Custom Versions

You can override default URLs and paths by providing environment variables:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `ANTIGRAVITY_HUB_URL` | *(Official release URL)* | Custom download URL for Antigravity Hub tarball |
| `ANTIGRAVITY_IDE_URL` | *(Official release URL)* | Custom download URL for Antigravity IDE tarball |
| `ANTIGRAVITY_INSTALL_DIR` | `/opt/antigravity` | Base directory where Hub and IDE files are placed |
| `ANTIGRAVITY_BIN_DIR` | `/usr/local/bin` | Directory where CLI command symlinks are created |

### Example: Installing a Specific Build

```bash
sudo ANTIGRAVITY_IDE_URL="https://example.com/custom/Antigravity%20IDE.tar.gz" ./install_antigravity.sh --ide-only
```

---

## 🗑️ Uninstallation

To cleanly remove Antigravity Hub, IDE, symlinks, desktop entries, completions, and icons:

```bash
sudo ./install_antigravity.sh --uninstall
```

> **Note:** Your personal configuration and agent history in `~/.gemini` and `~/.config` will be preserved. To remove them manually:
> ```bash
> rm -rf ~/.gemini ~/.config/Antigravity ~/.config/antigravity-ide
> ```

---

## 🖥️ Supported Linux Distributions

Tested and compatible with 64-bit Linux distributions:
- **Ubuntu** 20.04+ / **Debian** 11+
- **Fedora** 38+ / **RHEL** 9+ / **CentOS Stream**
- **Arch Linux** / **Manjaro**
- **openSUSE** Leap / Tumbleweed
- Other systemd-based Linux distributions with `glibc 2.28+`

---

## 🔍 Troubleshooting

### 1. "Text file busy" or update issues
If you have Antigravity running when updating, close the app before updating or run:
```bash
sudo ./install_antigravity.sh --force
```

### 2. Missing Icons in Dock / App Launcher
If icons do not show up immediately, update the system icon cache manually:
```bash
sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor
sudo update-desktop-database /usr/share/applications
```

### 3. Launching in Wayland / Electron Flags
To run Antigravity natively under Wayland:
```bash
antigravity --ozone-platform=wayland
antigravity-ide --ozone-platform=wayland
```

---

## 📄 License

This installer script is distributed under the [MIT License](LICENSE). Antigravity and Antigravity IDE are trademarks of Google LLC.
