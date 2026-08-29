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
EXT_DEST_DIR="${HOME}/.local/share/gnome-shell/extensions"
THEMES_DEST_DIR="${HOME}/.themes"
LOCAL_THEMES_DEST_DIR="${HOME}/.local/share/themes"

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
    printf "\n  %s%s[%s/6]%s %s%s%s\n" "${COLOR_BOLD}" "${COLOR_PURPLE}" "${step_num}" "${COLOR_RESET}" "${COLOR_BOLD}" "${title}" "${COLOR_RESET}"
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
    if command -v extension-manager >/dev/null 2>&1 || flatpak list 2>/dev/null | grep -q "com.mattjakeman.ExtensionManager"; then
        log_success "Extension Manager is already installed."
    else
        log_info "Attempting to install Extension Manager via DNF..."
        if sudo dnf install -y gnome-shell-extension-manager 2>/dev/null || sudo dnf install -y extension-manager 2>/dev/null; then
            log_success "Extension Manager installed via DNF."
        elif command -v flatpak >/dev/null 2>&1; then
            log_info "Installing Extension Manager via Flathub Flatpak..."
            flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
            flatpak install -y flathub com.mattjakeman.ExtensionManager 2>/dev/null || true
            log_success "Extension Manager installed via Flatpak."
        else
            log_warn "Extension Manager package not found in repos; GNOME Tweaks and Extensions CLI will manage extensions."
        fi
    fi
}

# ==============================================================================
#  Step 2: Sync & Extract Configurations
# ==============================================================================
sync_configurations() {
    step_header "2" "Synchronizing GNOME Extension & Desktop Configurations"

    mkdir -p "${CONFIG_DIR}"

    # If configs don't exist yet, extract them
    if [[ ! -f "${CONFIG_DIR}/extensions.dconf" ]]; then
        log_info "Extracting active GNOME configurations to ${COLOR_MUTED}Extensions-Configs/${COLOR_RESET}..."
        dconf dump /org/gnome/shell/extensions/ > "${CONFIG_DIR}/extensions.dconf"
        dconf dump /org/gnome/desktop/interface/ > "${CONFIG_DIR}/interface-settings.dconf"
        dconf dump /org/gnome/desktop/wm/ > "${CONFIG_DIR}/wm-settings.dconf"
        dconf dump /org/gnome/shell/ > "${CONFIG_DIR}/shell-settings.dconf"
        gsettings get org.gnome.shell enabled-extensions > "${CONFIG_DIR}/enabled-extensions.txt"
        log_success "Configurations successfully extracted."
    else
        log_success "Found pre-existing configurations in ${COLOR_MUTED}Extensions-Configs/${COLOR_RESET}"
    fi

    # Format list for iterator
    if [[ -f "${CONFIG_DIR}/enabled-extensions.txt" && ! -f "${CONFIG_DIR}/extensions-list.txt" ]]; then
        python3 -c "
import ast
try:
    with open('${CONFIG_DIR}/enabled-extensions.txt') as f:
        exts = ast.literal_eval(f.read().strip())
    with open('${CONFIG_DIR}/extensions-list.txt', 'w') as out:
        for ext in exts:
            out.write(ext + '\n')
except Exception:
    pass
" 2>/dev/null || true
    fi
}

# ==============================================================================
#  Step 3: Deploy Liquid Glass V2 & GNOME Extensions
# ==============================================================================
install_extensions() {
    step_header "3" "Deploying GNOME Extensions & Liquid Glass V2"

    mkdir -p "${EXT_DEST_DIR}"

    # 1. Liquid Glass V2 from GitHub
    log_info "Cloning and installing ${COLOR_BLUE}Liquid Glass V2${COLOR_RESET}..."
    local temp_clone_dir
    temp_clone_dir="$(mktemp -d)"

    if git clone --depth 1 "https://github.com/RuntimeFlash/Liquid-Glass-V2.git" "${temp_clone_dir}/Liquid-Glass-V2" 2>/dev/null; then
        local liquid_src="${temp_clone_dir}/Liquid-Glass-V2/liquid-glass-v2@thinkingcoding1231.gmail.com"
        if [[ -d "${liquid_src}" ]]; then
            cp -r "${liquid_src}" "${EXT_DEST_DIR}/"
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
        python3 - <<'EOF'
import os, sys, json, urllib.request, zipfile, tempfile, shutil

ext_dir = os.path.expanduser("~/.local/share/gnome-shell/extensions")
config_file = os.path.expanduser("Extensions-Configs/extensions-list.txt")

if not os.path.isfile(config_file):
    sys.exit(0)

with open(config_file) as f:
    uuids = [line.strip() for line in f if line.strip()]

headers = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0'}

for uuid in uuids:
    target_path = os.path.join(ext_dir, uuid)
    if os.path.isdir(target_path) or os.path.islink(target_path):
        print(f"   \033[38;2;163;190;140m✔\033[0m Extension '{uuid}' is already present.")
        continue
    
    print(f"   \033[38;2;136;192;208m✦\033[0m Querying GNOME repository for '{uuid}'...")
    try:
        query_url = f"https://extensions.gnome.org/extension-query/?search={urllib.parse.quote(uuid)}"
        req = urllib.request.Request(query_url, headers=headers)
        with urllib.request.urlopen(req, timeout=8) as res:
            res_data = json.loads(res.read().decode())
        
        matches = [e for e in res_data.get('extensions', []) if e.get('uuid') == uuid]
        if not matches and res_data.get('extensions'):
            matches = [res_data['extensions'][0]]
        
        if matches:
            ext_info = matches[0]
            dl_url = f"https://extensions.gnome.org{ext_info['download_url']}"
            with tempfile.NamedTemporaryFile(suffix=".zip", delete=False) as tmp_zip:
                dl_req = urllib.request.Request(dl_url, headers=headers)
                with urllib.request.urlopen(dl_req, timeout=12) as dl_res:
                    tmp_zip.write(dl_res.read())
                tmp_zip_path = tmp_zip.name

            os.makedirs(target_path, exist_ok=True)
            with zipfile.ZipFile(tmp_zip_path, 'r') as zip_ref:
                zip_ref.extractall(target_path)
            os.remove(tmp_zip_path)
            print(f"   \033[38;2;163;190;140m✔\033[0m Successfully downloaded and installed: {uuid}")
        else:
            print(f"   \033[38;2;235;203;139mℹ\033[0m Extension {uuid} will be activated if installed system-wide.")
    except Exception as e:
        print(f"   \033[38;2;235;203;139mℹ\033[0m Could not download {uuid}: {e}")
EOF
    fi

    # 3. Enable extensions
    log_info "Activating GNOME extensions..."
    if [[ -f "${CONFIG_DIR}/extensions-list.txt" ]]; then
        while IFS= read -r ext_uuid || [[ -n "$ext_uuid" ]]; do
            ext_uuid="$(echo "$ext_uuid" | tr -d '\r\n ')"
            if [[ -n "$ext_uuid" ]]; then
                gnome-extensions enable "$ext_uuid" 2>/dev/null || true
            fi
        done < "${CONFIG_DIR}/extensions-list.txt"
        log_success "All configured extensions enabled."
    fi
}

# ==============================================================================
#  Step 4: Deploy MacTahoe Themes
# ==============================================================================
install_themes() {
    step_header "4" "Deploying MacTahoe Desktop & Shell Themes"

    mkdir -p "${THEMES_DEST_DIR}" "${LOCAL_THEMES_DEST_DIR}"

    if [[ -d "${THEME_DIR}" ]]; then
        log_info "Installing MacTahoe theme variants into ${COLOR_MUTED}~/.themes${COLOR_RESET} and ${COLOR_MUTED}~/.local/share/themes${COLOR_RESET}..."
        cp -r "${THEME_DIR}/"* "${THEMES_DEST_DIR}/" 2>/dev/null || true
        cp -r "${THEME_DIR}/"* "${LOCAL_THEMES_DEST_DIR}/" 2>/dev/null || true
        log_success "MacTahoe themes installed successfully:"
        log_sub "MacTahoe-Dark-blue"
        log_sub "MacTahoe-Dark-blue-hdpi"
        log_sub "MacTahoe-Dark-blue-xhdpi"
    else
        log_warn "Mactahoe-Theme directory not found in repository."
    fi
}

# ==============================================================================
#  Step 5: Apply Desktop & Extension Configurations
# ==============================================================================
apply_configurations() {
    step_header "5" "Applying dconf Configurations & Styling"

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

    # Set theme properties explicitly
    log_info "Configuring GTK and User-Theme styling..."
    gsettings set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark-blue" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
    gsettings set org.gnome.shell.extensions.user-theme name "MacTahoe-Dark-blue" 2>/dev/null || true

    log_success "Theme styling preferences configured."
}

# ==============================================================================
#  Step 6: Completion, Tweaks Prompt & Session Logout
# ==============================================================================
show_completion() {
    step_header "6" "Setup Complete & Finalization"

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
        gnome-session-quit --logout --no-prompt 2>/dev/null || gnome-session-quit --logout 2>/dev/null || pkill -u "$USER" gnome-shell || true
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
    sync_configurations
    install_extensions
    install_themes
    apply_configurations
    show_completion
}

main "$@"
