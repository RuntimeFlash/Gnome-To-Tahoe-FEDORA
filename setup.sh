#!/usr/bin/env bash
# ==============================================================================
#  ✦ GNOME to macOS Transformation Suite ✦
#  Designed exclusively for Fedora Linux (GNOME Shell)
#
#  Features:
#   - Safe sudo escalation for Fedora DNF / Flatpak dependencies
#   - Automated installation of GNOME Tweaks, Git, & Extension Manager
#   - Automated deployment of GNOME extensions & Liquid Glass V2
#   - Full dconf configuration restore from Extensions-Configs/
#   - MacTahoe theme installation to ~/.themes and ~/.local/share/themes
#   - Interactive GNOME Tweaks launch & graceful session logout prompt
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/Extensions-Configs"
THEMES_DIR="${SCRIPT_DIR}/Themes"
THEME_REPO_DIR="${SCRIPT_DIR}/MacTahoe-gtk-theme"
THEME_REPO_URL="https://github.com/vinceliuice/MacTahoe-gtk-theme.git"
ICONS_REPO_DIR="${THEMES_DIR}/MacTahoe-icon-theme"
ICONS_REPO_URL="https://github.com/vinceliuice/MacTahoe-icon-theme.git"
CURSORS_SRC_DIR="${THEMES_DIR}/macOS-cursors"
ENABLED_EXTENSIONS_FILE="${CONFIG_DIR}/enabled-extensions-list.txt"
USER_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}"
EXT_DEST_DIR="${USER_DATA_DIR}/gnome-shell/extensions"
THEMES_DEST_DIR="${HOME}/.themes"
LOCAL_THEMES_DEST_DIR="${USER_DATA_DIR}/themes"
ICONS_DEST_DIR="${USER_DATA_DIR}/icons"
USER_ICONS_DIR="${HOME}/.icons"
BACKUP_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}/gnome-to-macos"
BACKUP_LATEST_FILE="${BACKUP_ROOT}/latest"

# ==============================================================================
#  Color Palette & Visual Formatting (Nord / Pastel Calm Aesthetics)
# ==============================================================================
COLOR_RESET=$'\033[0m'
COLOR_BOLD=$'\033[1m'
COLOR_DIM=$'\033[2m'
COLOR_CYAN=$'\033[38;2;136;192;208m'      # #88c0d0 Nord Frost Cyan
COLOR_BLUE=$'\033[38;2;129;161;193m'      # #81a1c1 Nord Frost Blue
COLOR_PURPLE=$'\033[38;2;180;142;173m'    # #b48ead Nord Aurora Lavender
COLOR_GREEN=$'\033[38;2;163;190;140m'     # #a3be8c Nord Aurora Sage Green
COLOR_AMBER=$'\033[38;2;235;203;139m'     # #ebcb8b Nord Aurora Amber
COLOR_MUTED=$'\033[38;2;120;135;155m'     # Subtle slate gray
COLOR_DARK_BOX=$'\033[38;2;76;86;106m'

print_banner() {
    printf "\n"
    printf "  %s%s╭────────────────────────────────────────────────────────────────────────╮%s\n" "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}"
    printf "  %s%s│%s   %s%s✦ GNOME to macOS — Fedora Transformation Suite ✦%s                  %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}"
    printf "  %s%s│%s   %sA calm, automated experience for a refined desktop environment%s   %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}" "${COLOR_MUTED}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}"
    printf "  %s%s╰────────────────────────────────────────────────────────────────────────╯%s\n" "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}"
    printf "\n"
}

step_header() {
    local step_num="$1"
    local title="$2"
    printf "\n  %s%s[%s/7]%s %s%s%s\n" "${COLOR_BOLD}" "${COLOR_PURPLE}" "${step_num}" "${COLOR_RESET}" "${COLOR_BOLD}" "${title}" "${COLOR_RESET}"
    printf "  %s%s%s\n" "${COLOR_DARK_BOX}" "──────────────────────────────────────────────────────────────────" "${COLOR_RESET}"
}

log_info() {
    printf "   %s✦%s %s\n" "${COLOR_CYAN}" "${COLOR_RESET}" "$1"
}

log_success() {
    printf "   %s✔%s %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$1"
}

log_warn() {
    printf "   %sℹ%s %s\n" "${COLOR_AMBER}" "${COLOR_RESET}" "$1"
}

log_sub() {
    printf "     %s•%s %s\n" "${COLOR_MUTED}" "${COLOR_RESET}" "$1"
}

# ==============================================================================
#  Validation & Sudo Escalation
# ==============================================================================
check_environment() {
    # Ensure not running as root directly
    if [[ $EUID -eq 0 ]]; then
        printf "\n  %s%s[!] Please run this script as your regular user (without sudo).%s\n" "${COLOR_BOLD}" "${COLOR_AMBER}" "${COLOR_RESET}"
        printf "      The script will request sudo automatically for system packages\n"
        printf "      while keeping your desktop preferences safely in user space.\n\n"
        exit 1
    fi

    # Verify Fedora
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        if [[ "${ID:-}" != "fedora" && "${ID_LIKE:-}" != *"fedora"* ]]; then
            log_warn "Notice: Detected system is '${PRETTY_NAME:-Linux}'. This script is optimized for Fedora."
        else
            log_info "Detected: ${COLOR_BLUE}${PRETTY_NAME:-Fedora Linux}${COLOR_RESET}"
        fi
    fi
}

request_sudo() {
    log_info "Requesting elevated permissions for package management..."
    if ! sudo -v; then
        printf "\n  %s[!] Sudo authentication failed. Exiting.%s\n\n" "${COLOR_AMBER}" "${COLOR_RESET}"
        exit 1
    fi

    # Maintain sudo timestamp in the background
    while true; do
        sudo -n true
        sleep 50
        kill -0 "$$" 2>/dev/null || exit
    done &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT INT TERM
    log_success "Sudo privileges granted for system package installation."
}

# ==============================================================================
#  Step 1: Install Fedora System Packages
# ==============================================================================
install_system_packages() {
    step_header "1" "Installing Essential Fedora Packages"

    log_info "Updating package lists and installing: ${COLOR_BLUE}gnome-tweaks, git${COLOR_RESET}"
    sudo dnf install -y gnome-tweaks git

    log_info "Checking GNOME Extension Manager..."
    if command -v extension-manager >/dev/null 2>&1 || { command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -q "com.mattjakeman.ExtensionManager"; }; then
        log_success "Extension Manager is already installed."
    else
        log_info "Attempting to install Extension Manager via DNF..."
        if sudo dnf install -y gnome-shell-extension-manager 2>/dev/null || sudo dnf install -y extension-manager 2>/dev/null; then
            log_success "Extension Manager installed via DNF."
        elif command -v flatpak >/dev/null 2>&1; then
            log_info "Installing Extension Manager via Flathub Flatpak..."
            flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
            if flatpak install -y flathub com.mattjakeman.ExtensionManager; then
                log_success "Extension Manager installed via Flatpak."
            else
                log_warn "Extension Manager could not be installed via Flatpak. Continuing with the GNOME Extensions CLI."
            fi
        else
            log_warn "Extension Manager package not found in repos; GNOME Tweaks and Extensions CLI will manage extensions."
        fi
    fi
}

# ==============================================================================
#  Step 2: Back Up Current Extensions & Settings
# ==============================================================================
backup_current_state() {
    step_header "2" "Backing Up Current Extensions & GNOME Settings"

    local backup_dir
    umask 077
    mkdir -p "${BACKUP_ROOT}"
    if [[ -f "${BACKUP_LATEST_FILE}" ]]; then
        IFS= read -r backup_dir < "${BACKUP_LATEST_FILE}" || true
        if [[ -n "${backup_dir:-}" && -d "${backup_dir}" ]]; then
            log_success "Keeping the original pre-install backup at ${COLOR_MUTED}${backup_dir}${COLOR_RESET}"
            return
        fi
    fi
    backup_dir="$(mktemp -d "${BACKUP_ROOT}/backup-XXXXXXXX-XXXXXX")"

    log_info "Saving a restorable snapshot to ${COLOR_MUTED}${backup_dir}${COLOR_RESET}..."
    if [[ -d "${EXT_DEST_DIR}" ]]; then
        cp -a "${EXT_DEST_DIR}" "${backup_dir}/extensions"
    else
        mkdir -p "${backup_dir}/extensions"
    fi
    dconf dump /org/gnome/shell/extensions/ > "${backup_dir}/extensions.dconf"
    dconf dump /org/gnome/desktop/interface/ > "${backup_dir}/interface-settings.dconf"
    dconf dump /org/gnome/desktop/wm/ > "${backup_dir}/wm-settings.dconf"
    dconf dump /org/gnome/shell/ > "${backup_dir}/shell-settings.dconf"
    gsettings get org.gnome.shell enabled-extensions > "${backup_dir}/enabled-extensions.txt"
    printf '%s\n' "${backup_dir}" > "${BACKUP_LATEST_FILE}"
    log_success "Backup complete. Run uninstall.sh later to restore this snapshot."
}

# ==============================================================================
#  Step 3: Sync & Extract Configurations
# ==============================================================================
sync_configurations() {
    step_header "3" "Synchronizing GNOME Extension & Desktop Configurations"

    mkdir -p "${CONFIG_DIR}"

    local required_config configs_complete=true
    for required_config in extensions.dconf interface-settings.dconf wm-settings.dconf shell-settings.dconf enabled-extensions.txt extensions-list.txt enabled-extensions-list.txt; do
        [[ -f "${CONFIG_DIR}/${required_config}" ]] || configs_complete=false
    done
    if [[ "${configs_complete}" == true ]]; then
        log_success "Found pre-existing configurations in ${COLOR_MUTED}Extensions-Configs/${COLOR_RESET}"
        return
    fi

    log_warn "Configuration set is incomplete; creating only missing files from the current desktop."
    [[ -f "${CONFIG_DIR}/extensions.dconf" ]] || dconf dump /org/gnome/shell/extensions/ > "${CONFIG_DIR}/extensions.dconf"
    [[ -f "${CONFIG_DIR}/interface-settings.dconf" ]] || dconf dump /org/gnome/desktop/interface/ > "${CONFIG_DIR}/interface-settings.dconf"
    [[ -f "${CONFIG_DIR}/wm-settings.dconf" ]] || dconf dump /org/gnome/desktop/wm/ > "${CONFIG_DIR}/wm-settings.dconf"
    [[ -f "${CONFIG_DIR}/shell-settings.dconf" ]] || dconf dump /org/gnome/shell/ > "${CONFIG_DIR}/shell-settings.dconf"
    [[ -f "${CONFIG_DIR}/enabled-extensions.txt" ]] || gsettings get org.gnome.shell enabled-extensions > "${CONFIG_DIR}/enabled-extensions.txt"

    # Format list for iterator
    if [[ -f "${CONFIG_DIR}/enabled-extensions.txt" && ! -f "${CONFIG_DIR}/extensions-list.txt" ]]; then
        CONFIG_FILE="${CONFIG_DIR}/enabled-extensions.txt" LIST_FILE="${CONFIG_DIR}/extensions-list.txt" python3 - <<'EOF'
import ast
import os

with open(os.environ['CONFIG_FILE'], encoding='utf-8') as source:
    extensions = ast.literal_eval(source.read().strip())
if not isinstance(extensions, list) or not all(isinstance(extension, str) for extension in extensions):
    raise ValueError('enabled-extensions is not a list of extension UUIDs')
with open(os.environ['LIST_FILE'], 'w', encoding='utf-8') as destination:
    destination.write('\n'.join(extensions) + ('\n' if extensions else ''))
EOF
    fi

    if [[ -f "${CONFIG_DIR}/enabled-extensions.txt" && ! -f "${ENABLED_EXTENSIONS_FILE}" ]]; then
        CONFIG_FILE="${CONFIG_DIR}/enabled-extensions.txt" LIST_FILE="${ENABLED_EXTENSIONS_FILE}" python3 - <<'EOF'
import ast
import os

with open(os.environ['CONFIG_FILE'], encoding='utf-8') as source:
    extensions = ast.literal_eval(source.read().strip())
if not isinstance(extensions, list) or not all(isinstance(extension, str) for extension in extensions):
    raise ValueError('enabled-extensions is not a list of extension UUIDs')
with open(os.environ['LIST_FILE'], 'w', encoding='utf-8') as destination:
    destination.write('\n'.join(extensions) + ('\n' if extensions else ''))
EOF
    fi
}

# ==============================================================================
#  Step 4: Deploy Liquid Glass V2 & GNOME Extensions
# ==============================================================================
install_extensions() {
    step_header "4" "Deploying GNOME Extensions & Liquid Glass V2"

    mkdir -p "${EXT_DEST_DIR}"

    # 1. Liquid Glass V2 from GitHub
    log_info "Cloning and installing ${COLOR_BLUE}Liquid Glass V2${COLOR_RESET}..."
    local temp_clone_dir
    temp_clone_dir="$(mktemp -d)"

    if git clone --depth 1 "https://github.com/RuntimeFlash/Liquid-Glass-V2.git" "${temp_clone_dir}/Liquid-Glass-V2" 2>/dev/null; then
        local liquid_src="${temp_clone_dir}/Liquid-Glass-V2/liquid-glass-v2@thinkingcoding1231.gmail.com"
        if [[ -d "${liquid_src}" ]]; then
            local liquid_dest="${EXT_DEST_DIR}/liquid-glass-v2@thinkingcoding1231.gmail.com"
            rm -rf "${liquid_dest}"
            cp -a "${liquid_src}" "${liquid_dest}"
            log_success "Liquid Glass V2 deployed to ${COLOR_MUTED}~/.local/share/gnome-shell/extensions/${COLOR_RESET}"
        else
            log_warn "Source folder not found inside cloned Liquid-Glass-V2 repository."
        fi
    else
        log_warn "Could not clone Liquid-Glass-V2 repository. Checking for local copy..."
    fi
    rm -rf "${temp_clone_dir}"

    # Superbar was removed from extensions.gnome.org, so install the maintained
    # upstream copy directly instead of repeatedly reporting its repository 404.
    local superbar_uuid="superbar@Furkan-rgb.github.io"
    if [[ -f "${CONFIG_DIR}/extensions-list.txt" ]] && grep -Fxq "${superbar_uuid}" "${CONFIG_DIR}/extensions-list.txt" && [[ ! -d "${EXT_DEST_DIR}/${superbar_uuid}" ]]; then
        log_info "Cloning and installing ${COLOR_BLUE}Superbar${COLOR_RESET} from its upstream repository..."
        temp_clone_dir="$(mktemp -d)"
        if git clone --depth 1 "https://github.com/Furkan-rgb/superbar.git" "${temp_clone_dir}/superbar" 2>/dev/null && [[ -f "${temp_clone_dir}/superbar/metadata.json" ]] && grep -Fq "\"uuid\": \"${superbar_uuid}\"" "${temp_clone_dir}/superbar/metadata.json"; then
            cp -a "${temp_clone_dir}/superbar" "${EXT_DEST_DIR}/${superbar_uuid}"
            log_success "Superbar deployed from upstream."
        else
            log_warn "Could not obtain a valid Superbar extension from its upstream repository."
        fi
        rm -rf "${temp_clone_dir}"
    fi

    # 2. Automated downloader & installer for listed extensions
    if [[ -f "${CONFIG_DIR}/extensions-list.txt" ]]; then
        log_info "Verifying and downloading extensions from GNOME Extensions repository..."
        CONFIG_FILE="${CONFIG_DIR}/extensions-list.txt" EXT_DIR="${EXT_DEST_DIR}" python3 - <<'EOF'
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request

ext_dir = os.environ["EXT_DIR"]
config_file = os.environ["CONFIG_FILE"]

if not os.path.isfile(config_file):
    sys.exit(0)

with open(config_file) as f:
    uuids = [line.strip() for line in f if line.strip()]

headers = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0'}

def get_shell_version():
    """Return the GNOME Shell major version required by extensions.gnome.org."""
    try:
        output = subprocess.check_output(
            ["gnome-shell", "--version"], text=True, stderr=subprocess.DEVNULL
        )
    except (OSError, subprocess.CalledProcessError):
        return None

    match = re.search(r"(\d+)(?:\.\d+)*", output)
    return match.group(1) if match else None

shell_version = get_shell_version()
if shell_version:
    print(f"   Detected GNOME Shell {shell_version}; selecting compatible extension releases.")
else:
    print("   \033[38;2;235;203;139mℹ\033[0m Could not determine the GNOME Shell version; skipping repository downloads.")

def shell_has_extension(shell_cli, uuid):
    return bool(shell_cli and subprocess.run(
        [shell_cli, "info", uuid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    ).returncode == 0)

def wait_for_shell_registration(shell_cli, uuid, seconds=20):
    """Allow GNOME Shell to come back after a D-Bus disconnect/restart."""
    for _ in range(seconds):
        if shell_has_extension(shell_cli, uuid):
            return True
        time.sleep(1)
    return False

def install_with_live_shell(live_installer, uuid):
    return subprocess.run(
        [live_installer, "call", "--session", "--dest", "org.gnome.Shell.Extensions",
         "--object-path", "/org/gnome/Shell/Extensions", "--method",
         "org.gnome.Shell.Extensions.InstallRemoteExtension", uuid],
        text=True, capture_output=True,
    )

for uuid in uuids:
    target_path = os.path.join(ext_dir, uuid)
    shell_cli = shutil.which("gnome-extensions")
    shell_knows_extension = shell_has_extension(shell_cli, uuid)
    if (os.path.isdir(target_path) or os.path.islink(target_path)) and shell_knows_extension:
        print(f"   \033[38;2;163;190;140m✔\033[0m Extension '{uuid}' is already present.")
        continue
    if uuid == "superbar@Furkan-rgb.github.io" and os.path.isdir(target_path):
        print(f"   \033[38;2;235;203;139mℹ\033[0m Superbar is installed from upstream; GNOME Shell will discover it on its next session refresh.")
        continue
    if uuid == "liquid-glass-v2@thinkingcoding1231.gmail.com" and os.path.isdir(target_path):
        print(f"   \033[38;2;235;203;139mℹ\033[0m Liquid Glass V2 is installed from GitHub. GNOME Shell must refresh before it can be enabled.")
        continue
    
    if not shell_version:
        continue

    print(f"   \033[38;2;136;192;208m✦\033[0m Querying GNOME repository for '{uuid}'...")
    try:
        # extension-info is an exact UUID lookup.  The shell_version parameter is
        # essential: without it the API intentionally omits download_url.
        info_url = (
            "https://extensions.gnome.org/extension-info/?uuid="
            f"{urllib.parse.quote(uuid)}&shell_version={urllib.parse.quote(shell_version)}"
        )
        req = urllib.request.Request(info_url, headers=headers)
        with urllib.request.urlopen(req, timeout=8) as res:
            ext_info = json.loads(res.read().decode())

        if ext_info.get("uuid") != uuid:
            raise RuntimeError("repository returned a different extension")
        if not ext_info.get("download_url"):
            print(f"   \033[38;2;235;203;139mℹ\033[0m No release of {uuid} supports GNOME Shell {shell_version}; skipped.")
            continue

        # This is GNOME Shell's live installer. Unlike merely unpacking a ZIP,
        # it immediately adds the extension to the running Shell registry.
        live_installer = shutil.which("gdbus")
        installed_live = False
        if live_installer:
            result = install_with_live_shell(live_installer, uuid)
            installed_live = result.returncode == 0 and "successful" in result.stdout.lower()

            # Shell can briefly disconnect from D-Bus while it reloads after an
            # approved installation. Treat NoReply as an indeterminate result,
            # wait for the UUID to appear, then retry once if it did not.
            disconnected = "NoReply" in result.stderr or "Remote peer disconnected" in result.stderr
            if not installed_live and disconnected:
                print(f"   Waiting for GNOME Shell to recover after installing {uuid}...")
                installed_live = wait_for_shell_registration(shell_cli, uuid)
                if not installed_live:
                    retry = install_with_live_shell(live_installer, uuid)
                    installed_live = retry.returncode == 0 and "successful" in retry.stdout.lower()
                    result = retry

            if installed_live:
                installed_live = wait_for_shell_registration(shell_cli, uuid)

        if installed_live:
            pass
        else:
            reason = result.stderr.strip() if live_installer else "no active GNOME Shell session"
            status = result.stdout.strip() if live_installer else ""
            raise RuntimeError(
                "GNOME Shell did not register the live install"
                + (f" ({status})" if status else "")
                + (f": {reason}" if reason else "")
            )

        # Do not report success merely because GNOME Extensions returned a URL.
        metadata_path = os.path.join(target_path, "metadata.json")
        if not os.path.isfile(metadata_path):
            raise RuntimeError("GNOME did not create the extension directory")
        with open(metadata_path, encoding="utf-8") as metadata_file:
            if json.load(metadata_file).get("uuid") != uuid:
                raise RuntimeError("installed extension UUID does not match")
        print(f"   \033[38;2;163;190;140m✔\033[0m Installed and registered with GNOME Shell: {uuid}")
    except Exception as e:
        print(f"   \033[38;2;235;203;139mℹ\033[0m Could not download {uuid}: {e}")
EOF
    fi

}

compile_extension_schemas() {
    local ext_uuid="$1"
    local schemas_dir="${EXT_DEST_DIR}/${ext_uuid}/schemas"

    [[ -d "${schemas_dir}" ]] || return 0
    if ! find "${schemas_dir}" -maxdepth 1 -name '*.gschema.xml' -print -quit | grep -q .; then
        return 0
    fi
    if ! command -v glib-compile-schemas >/dev/null 2>&1; then
        log_warn "${ext_uuid} has schemas, but glib-compile-schemas is unavailable."
        return 0
    fi
    if ! glib-compile-schemas "${schemas_dir}"; then
        log_warn "Could not compile GSettings schemas for ${ext_uuid}."
    fi
}

enable_extensions() {
    log_info "Activating GNOME extensions..."
    local enabled_count=0 failed_count=0 ext_uuid enable_error
    if ! command -v gnome-extensions >/dev/null 2>&1; then
        log_warn "gnome-extensions is unavailable; extensions were not enabled."
        return
    fi
    local enabled_file="${ENABLED_EXTENSIONS_FILE}"
    [[ -f "${enabled_file}" ]] || enabled_file="${CONFIG_DIR}/extensions-list.txt"
    [[ -f "${enabled_file}" ]] || return

    while IFS= read -r ext_uuid || [[ -n "$ext_uuid" ]]; do
        ext_uuid="${ext_uuid//$'\r'/}"
        ext_uuid="${ext_uuid// /}"
        [[ -n "${ext_uuid}" ]] || continue
        if ! gnome-extensions info "${ext_uuid}" >/dev/null 2>&1; then
            ((failed_count += 1))
            log_warn "Skipping ${ext_uuid}: GNOME Shell has not registered it. Approve its install prompt and run setup again."
            continue
        fi
        compile_extension_schemas "${ext_uuid}"
        if enable_error="$(gnome-extensions enable "${ext_uuid}" 2>&1)"; then
            ((enabled_count += 1))
        else
            ((failed_count += 1))
            log_warn "Could not enable ${ext_uuid}: ${enable_error:-extension is missing or incompatible}"
        fi
    done < "${enabled_file}"

    if (( failed_count == 0 )); then
        log_success "Enabled ${enabled_count} configured extension(s)."
    else
        log_warn "Enabled ${enabled_count} extension(s); ${failed_count} could not be enabled."
    fi
}

# ==============================================================================
#  Step 5: Deploy MacTahoe Themes
# ==============================================================================
install_themes() {
    step_header "5" "Deploying MacTahoe Desktop, Cursor & Icon Themes"

    mkdir -p "${THEMES_DEST_DIR}" "${LOCAL_THEMES_DEST_DIR}" "${ICONS_DEST_DIR}" "${USER_ICONS_DIR}"

    # 1. MacTahoe GTK & Shell Themes
    if [[ ! -d "${THEME_REPO_DIR}" ]]; then
        log_info "Cloning MacTahoe GTK theme repository..."
        if ! git clone "${THEME_REPO_URL}" "${THEME_REPO_DIR}"; then
            log_warn "Failed to clone MacTahoe repository."
        fi
    fi

    if [[ -f "${THEME_REPO_DIR}/install.sh" ]]; then
        log_info "Installing MacTahoe theme variants and GTK 4 libadwaita styling..."
        if "${THEME_REPO_DIR}/install.sh" -c dark -t blue -l; then
            log_success "MacTahoe themes and libadwaita styling deployed successfully."
        else
            log_warn "MacTahoe theme installation script encountered an issue."
        fi
    else
        log_warn "MacTahoe theme installer script not found."
    fi

    # 2. macOS Mouse Cursor Theme
    if [[ -d "${CURSORS_SRC_DIR}" ]]; then
        log_info "Deploying macOS mouse cursors..."
        mkdir -p "${USER_ICONS_DIR}/macOS" "${ICONS_DEST_DIR}/macOS"
        cp -a "${CURSORS_SRC_DIR}/." "${USER_ICONS_DIR}/macOS/"
        cp -a "${CURSORS_SRC_DIR}/." "${ICONS_DEST_DIR}/macOS/"
        log_success "macOS mouse cursors deployed to ~/.icons/macOS and ~/.local/share/icons/macOS."
    fi

    # 3. MacTahoe Icon Theme
    if [[ ! -d "${ICONS_REPO_DIR}" ]]; then
        log_info "Cloning MacTahoe icon theme repository..."
        if ! git clone "${ICONS_REPO_URL}" "${ICONS_REPO_DIR}"; then
            log_warn "Failed to clone MacTahoe icon theme repository."
        fi
    fi

    if [[ -f "${ICONS_REPO_DIR}/install.sh" ]]; then
        log_info "Installing MacTahoe icon theme variants..."
        if "${ICONS_REPO_DIR}/install.sh" -t blue; then
            log_success "MacTahoe icon themes deployed to ~/.local/share/icons."
        else
            log_warn "MacTahoe icon theme installer encountered an issue."
        fi
    fi
}

install_libadwaita_override() {
    local override_source="${SCRIPT_DIR}/Libadwaita-Override/gtk-4.0/gtk.css"
    local gtk4_dest="${HOME}/.config/gtk-4.0"
    local gtk4_backup="${BACKUP_ROOT}/gtk-4.0-before-libadwaita-override"

    [[ -f "${override_source}" ]] || return 0

    if [[ ! -d "${gtk4_backup}" && -d "${gtk4_dest}" ]]; then
        mkdir -p "${gtk4_backup}"
        cp -a "${gtk4_dest}/." "${gtk4_backup}/" 2>/dev/null || true
        log_sub "Saved the previous GTK 4 override to ${gtk4_backup}"
    fi

    # If an extra override stylesheet is provided, apply it without Kiwi account-specific imports
    if [[ -f "${gtk4_dest}/gtk.css" ]]; then
        sed '/\/\* Kiwi (is not Apple) - managed imports: begin \*\//,/\/\* Kiwi (is not Apple) - managed imports: end \*\//d' \
            "${override_source}" > "${gtk4_dest}/gtk.css" 2>/dev/null || true
    fi
}

# ==============================================================================
#  Step 6: Apply Desktop & Extension Configurations
# ==============================================================================
apply_configurations() {
    step_header "6" "Applying dconf Configurations & Styling"

    # Load extension settings
    if [[ -f "${CONFIG_DIR}/extensions.dconf" ]]; then
        log_info "Loading extension configurations into dconf database..."
        dconf load /org/gnome/shell/extensions/ < "${CONFIG_DIR}/extensions.dconf"
        log_success "Extension settings imported."
    fi

    # Load interface settings
    if [[ -f "${CONFIG_DIR}/interface-settings.dconf" ]]; then
        log_info "Loading interface preferences..."
        dconf load /org/gnome/desktop/interface/ < "${CONFIG_DIR}/interface-settings.dconf"
    fi

    # Load window manager settings
    if [[ -f "${CONFIG_DIR}/wm-settings.dconf" ]]; then
        log_info "Loading window manager preferences..."
        dconf load /org/gnome/desktop/wm/ < "${CONFIG_DIR}/wm-settings.dconf"
    fi

    if [[ -f "${CONFIG_DIR}/shell-settings.dconf" ]]; then
        log_info "Loading GNOME Shell preferences..."
        dconf load /org/gnome/shell/ < "${CONFIG_DIR}/shell-settings.dconf"
    fi

    # Burn My Windows profiles live outside dconf. Copy the exported Standard
    # Profile and rewrite its path for the current user before enabling it.
    # The target profile directory is intentionally replaced so another saved
    # profile cannot remain selected or override this project's configuration.
    local burn_profile_source="${CONFIG_DIR}/burn-my-windows/profiles/standard.conf"
    if [[ -f "${burn_profile_source}" ]]; then
        local burn_profiles_dir="${HOME}/.config/burn-my-windows/profiles"
        local burn_profile_dest="${burn_profiles_dir}/standard.conf"
        rm -rf -- "${burn_profiles_dir}"
        mkdir -p "${burn_profiles_dir}"
        cp -a "${burn_profile_source}" "${burn_profile_dest}"
        dconf write /org/gnome/shell/extensions/burn-my-windows/active-profile "'${burn_profile_dest}'"
        log_success "Burn My Windows Standard Profile installed as the only profile."
    fi

    # Enable only UUIDs which the running Shell has registered. This prevents
    # a stale enabled-extensions setting from trying to start on-disk-only
    # extensions and makes every enable failure actionable.
    enable_extensions

    # Set theme properties explicitly
    log_info "Configuring GTK, Cursor, Icon, and User-Theme styling..."
    gsettings set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark-blue" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
    gsettings set org.gnome.shell.extensions.user-theme name "MacTahoe-Dark-blue" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme "macOS" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "MacTahoe-light" 2>/dev/null || true

    log_success "Theme, cursor, and icon styling preferences configured."
}

# ==============================================================================
#  Step 7: Completion, Tweaks Prompt & Session Logout
# ==============================================================================
show_completion() {
    step_header "7" "Setup Complete & Finalization"

    printf "\n"
    printf "  %s%s╭────────────────────────────────────────────────────────────────────────╮%s\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
    printf "  %s%s│%s   %s✔ Transformation successfully completed!%s                             %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
    printf "  %s%s│%s                                                                        %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
    printf "  %s%s│%s   %s• MacTahoe GTK & Shell themes deployed to ~/.themes%s                  %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_CYAN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
    printf "  %s%s│%s   %s• macOS mouse cursor theme deployed to ~/.icons/macOS%s                %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_CYAN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
    printf "  %s%s│%s   %s• MacTahoe icon theme deployed to ~/.local/share/icons%s               %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_CYAN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
    printf "  %s%s│%s   %s• Liquid Glass V2 & GNOME extensions installed & activated%s         %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_CYAN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
    printf "  %s%s│%s   %s• Desktop interface & extension configurations applied%s             %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_CYAN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
    printf "  %s%s╰────────────────────────────────────────────────────────────────────────╯%s\n\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"

    printf "  %s✦ GNOME Tweaks Appearance Settings:%s\n" "${COLOR_BOLD}${COLOR_CYAN}" "${COLOR_RESET}"
    printf "    %s• Applications (Legacy):%s %sMacTahoe-Dark-blue%s\n" "${COLOR_MUTED}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_RESET}"
    printf "    %s• Cursor / Mouse:%s        %smacOS%s\n" "${COLOR_MUTED}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_RESET}"
    printf "    %s• Icons:%s                 %sMacTahoe-light%s (or MacTahoe-dark)\n" "${COLOR_MUTED}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_RESET}"
    printf "    %s• Shell Theme:%s           %sMacTahoe-Dark-blue%s\n\n" "${COLOR_MUTED}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_RESET}"

    # Prompt to open GNOME Tweaks
    printf "  %s✦ Would you like to open GNOME Tweaks now to review theme settings?%s [Y/n]: " "${COLOR_CYAN}" "${COLOR_RESET}"
    read -r open_tweaks || open_tweaks="y"
    if [[ "${open_tweaks:-y}" =~ ^[Yy]$ || -z "${open_tweaks}" ]]; then
        log_info "Launching GNOME Tweaks in the background..."
        gnome-tweaks >/dev/null 2>&1 &
        disown
        log_success "GNOME Tweaks opened."
    fi

    printf "\n"
    log_info "${COLOR_BOLD}Session Notice:${COLOR_RESET} To apply all GNOME Shell blur shaders, panel modifications,"
    log_sub "and new window decorations completely, logging out and logging back in is recommended."

    printf "\n  %s✦ Would you like to log out now to finalize?%s [y/N]: " "${COLOR_PURPLE}" "${COLOR_RESET}"
    read -r do_logout || do_logout="n"
    if [[ "${do_logout}" =~ ^[Yy]$ ]]; then
        printf "\n  %sLogging out in 3 seconds... (See you on the other side!)%s\n" "${COLOR_GREEN}" "${COLOR_RESET}"
        sleep 3
        if ! gnome-session-quit --logout --no-prompt 2>/dev/null && ! gnome-session-quit --logout 2>/dev/null; then
            log_warn "Could not log out automatically. Please use the system menu."
        fi
    else
        printf "\n  %s✔ All set! You can log out anytime from the top-right system menu.%s\n\n" "${COLOR_GREEN}" "${COLOR_RESET}"
    fi
}

# ==============================================================================
#  Main Execution Flow
# ==============================================================================
main() {
    print_banner
    check_environment
    request_sudo
    install_system_packages
    backup_current_state
    sync_configurations
    install_extensions
    install_themes
    install_libadwaita_override
    apply_configurations
    show_completion
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
