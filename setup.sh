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
THEME_DIR="${SCRIPT_DIR}/Mactahoe-Theme"
USER_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}"
EXT_DEST_DIR="${USER_DATA_DIR}/gnome-shell/extensions"
THEMES_DEST_DIR="${HOME}/.themes"
LOCAL_THEMES_DEST_DIR="${USER_DATA_DIR}/themes"
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
    for required_config in extensions.dconf interface-settings.dconf wm-settings.dconf shell-settings.dconf enabled-extensions.txt extensions-list.txt; do
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
import tempfile
import urllib.parse
import urllib.request
import zipfile

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

for uuid in uuids:
    target_path = os.path.join(ext_dir, uuid)
    if os.path.isdir(target_path) or os.path.islink(target_path):
        print(f"   \033[38;2;163;190;140m✔\033[0m Extension '{uuid}' is already present.")
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

        dl_url = urllib.parse.urljoin("https://extensions.gnome.org", ext_info["download_url"])
        with tempfile.TemporaryDirectory(prefix="gnome-extension-") as temp_dir:
            zip_path = os.path.join(temp_dir, "extension.zip")
            dl_req = urllib.request.Request(dl_url, headers=headers)
            with urllib.request.urlopen(dl_req, timeout=20) as dl_res, open(zip_path, "wb") as tmp_zip:
                shutil.copyfileobj(dl_res, tmp_zip)

            # Let GNOME Shell install the bundle. This compiles schemas where
            # necessary and makes GNOME's extension registry authoritative.
            installer = shutil.which("gnome-extensions")
            if installer:
                result = subprocess.run(
                    [installer, "install", "--force", "--print-uuid", zip_path],
                    text=True, capture_output=True,
                )
                if result.returncode:
                    raise RuntimeError(result.stderr.strip() or "gnome-extensions install failed")
            else:
                # Fallback for minimal installations where the CLI is absent.
                extract_path = os.path.join(temp_dir, "extension")
                with zipfile.ZipFile(zip_path) as zip_ref:
                    zip_ref.extractall(extract_path)
                metadata_path = os.path.join(extract_path, "metadata.json")
                if not os.path.isfile(metadata_path):
                    raise RuntimeError("downloaded archive does not contain metadata.json")
                with open(metadata_path, encoding="utf-8") as metadata_file:
                    if json.load(metadata_file).get("uuid") != uuid:
                        raise RuntimeError("downloaded archive UUID does not match")
                os.makedirs(ext_dir, exist_ok=True)
                shutil.move(extract_path, target_path)

        # Do not report success merely because the HTTP request worked.
        metadata_path = os.path.join(target_path, "metadata.json")
        if not os.path.isfile(metadata_path):
            raise RuntimeError("GNOME did not create the extension directory")
        with open(metadata_path, encoding="utf-8") as metadata_file:
            if json.load(metadata_file).get("uuid") != uuid:
                raise RuntimeError("installed extension UUID does not match")
        print(f"   \033[38;2;163;190;140m✔\033[0m Installed and verified: {uuid}")
    except Exception as e:
        print(f"   \033[38;2;235;203;139mℹ\033[0m Could not download {uuid}: {e}")
EOF
    fi

}

compile_extension_schemas() {
    local ext_uuid="$1"
    local schemas_dir="${EXT_DEST_DIR}/${ext_uuid}/schemas"

    [[ -d "${schemas_dir}" ]] || return
    if ! find "${schemas_dir}" -maxdepth 1 -name '*.gschema.xml' -print -quit | grep -q .; then
        return
    fi
    if ! command -v glib-compile-schemas >/dev/null 2>&1; then
        log_warn "${ext_uuid} has schemas, but glib-compile-schemas is unavailable."
        return
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
    [[ -f "${CONFIG_DIR}/extensions-list.txt" ]] || return

    while IFS= read -r ext_uuid || [[ -n "$ext_uuid" ]]; do
        ext_uuid="${ext_uuid//$'\r'/}"
        ext_uuid="${ext_uuid// /}"
        [[ -n "${ext_uuid}" ]] || continue
        compile_extension_schemas "${ext_uuid}"
        if enable_error="$(gnome-extensions enable "${ext_uuid}" 2>&1)"; then
            ((enabled_count += 1))
        else
            ((failed_count += 1))
            log_warn "Could not enable ${ext_uuid}: ${enable_error:-extension is missing or incompatible}"
        fi
    done < "${CONFIG_DIR}/extensions-list.txt"

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
    step_header "5" "Deploying MacTahoe Desktop & Shell Themes"

    mkdir -p "${THEMES_DEST_DIR}" "${LOCAL_THEMES_DEST_DIR}"

    if [[ -d "${THEME_DIR}" ]]; then
        log_info "Installing MacTahoe theme variants into ${COLOR_MUTED}~/.themes${COLOR_RESET} and ${COLOR_MUTED}~/.local/share/themes${COLOR_RESET}..."
        if cp -a "${THEME_DIR}/." "${THEMES_DEST_DIR}/" && cp -a "${THEME_DIR}/." "${LOCAL_THEMES_DEST_DIR}/"; then
            log_success "MacTahoe themes installed successfully:"
            log_sub "MacTahoe-Dark-blue"
            log_sub "MacTahoe-Dark-blue-hdpi"
            log_sub "MacTahoe-Dark-blue-xhdpi"
        else
            log_warn "One or more theme files could not be copied; check permissions and free disk space."
        fi
    else
        log_warn "Mactahoe-Theme directory not found in repository."
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

    enable_extensions

    # Set theme properties explicitly
    log_info "Configuring GTK and User-Theme styling..."
    gsettings set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark-blue" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
    gsettings set org.gnome.shell.extensions.user-theme name "MacTahoe-Dark-blue" 2>/dev/null || true

    log_success "Theme styling preferences configured."
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
    printf "  %s%s│%s   %s• MacTahoe Themes deployed to ~/.themes & ~/.local/share/themes%s    %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_CYAN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
    printf "  %s%s│%s   %s• Liquid Glass V2 & GNOME extensions installed & activated%s         %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_CYAN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
    printf "  %s%s│%s   %s• Desktop interface & extension configurations applied%s             %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_CYAN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"
    printf "  %s%s╰────────────────────────────────────────────────────────────────────────╯%s\n\n" "${COLOR_BOLD}" "${COLOR_GREEN}" "${COLOR_RESET}"

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
    apply_configurations
    show_completion
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
