#!/usr/bin/env bash
# ==============================================================================
#  GNOME to macOS Setup - Configuration Backup Tool
#  Exports current GNOME extension configurations and desktop settings.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/Extensions-Configs"

# --- Visual Styling ---
COLOR_RESET=$'\033[0m'
COLOR_CYAN=$'\033[38;2;136;192;208m'
COLOR_BLUE=$'\033[38;2;129;161;193m'
COLOR_GREEN=$'\033[38;2;163;190;140m'
COLOR_MUTED=$'\033[38;2;120;135;155m'
COLOR_BOLD=$'\033[1m'

log_info() {
    printf " %s✦%s %s\n" "${COLOR_CYAN}" "${COLOR_RESET}" "$1"
}

log_success() {
    printf " %s✔%s %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$1"
}

printf "\n"
printf "  %s%s╭────────────────────────────────────────────────────────────╮%s\n" "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}"
printf "  %s%s│%s   %s✦ GNOME to macOS — Configuration Exporter ✦%s            %s%s│%s\n" "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}" "${COLOR_CYAN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}"
printf "  %s%s╰────────────────────────────────────────────────────────────╯%s\n\n" "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}"

log_info "Ensuring configuration directory exists at: ${COLOR_MUTED}${CONFIG_DIR}${COLOR_RESET}"
mkdir -p "${CONFIG_DIR}"

log_info "Exporting /org/gnome/shell/extensions/ dconf database..."
dconf dump /org/gnome/shell/extensions/ > "${CONFIG_DIR}/extensions.dconf"
log_success "Saved extension preferences to: ${COLOR_MUTED}Extensions-Configs/extensions.dconf${COLOR_RESET}"

log_info "Exporting /org/gnome/desktop/interface/ settings..."
dconf dump /org/gnome/desktop/interface/ > "${CONFIG_DIR}/interface-settings.dconf"
log_success "Saved interface preferences to: ${COLOR_MUTED}Extensions-Configs/interface-settings.dconf${COLOR_RESET}"

log_info "Exporting /org/gnome/desktop/wm/ settings..."
dconf dump /org/gnome/desktop/wm/ > "${CONFIG_DIR}/wm-settings.dconf"
log_success "Saved window manager settings to: ${COLOR_MUTED}Extensions-Configs/wm-settings.dconf${COLOR_RESET}"

log_info "Exporting /org/gnome/shell/ settings..."
dconf dump /org/gnome/shell/ > "${CONFIG_DIR}/shell-settings.dconf"
log_success "Saved shell settings to: ${COLOR_MUTED}Extensions-Configs/shell-settings.dconf${COLOR_RESET}"

log_info "Exporting enabled extensions list..."
gsettings get org.gnome.shell enabled-extensions > "${CONFIG_DIR}/enabled-extensions.txt"

# Create a clean line-separated list for easy scripting
python3 -c "
import ast
try:
    with open('${CONFIG_DIR}/enabled-extensions.txt') as f:
        exts = ast.literal_eval(f.read().strip())
    with open('${CONFIG_DIR}/extensions-list.txt', 'w') as out:
        for ext in exts:
            out.write(ext + '\n')
except Exception as e:
    print('Warning: could not parse enabled-extensions array:', e)
" 2>/dev/null || true

# Keep a line-separated enabled list for setup.sh. Unlike extensions-list.txt,
# this only controls which installed extensions are turned on automatically.
python3 -c "
import ast
try:
    with open('${CONFIG_DIR}/enabled-extensions.txt') as f:
        exts = ast.literal_eval(f.read().strip())
    with open('${CONFIG_DIR}/enabled-extensions-list.txt', 'w') as out:
        for ext in exts:
            out.write(ext + '\n')
except Exception as e:
    print('Warning: could not parse enabled-extensions array:', e)
" 2>/dev/null || true

# Burn My Windows stores selected effect profiles outside dconf. Preserve the
# active profile too, so it can be restored on another user account.
burn_profile="$(dconf read /org/gnome/shell/extensions/burn-my-windows/active-profile 2>/dev/null || true)"
burn_profile="${burn_profile#\'}"
burn_profile="${burn_profile%\'}"
if [[ -f "${burn_profile}" ]]; then
    mkdir -p "${CONFIG_DIR}/burn-my-windows/profiles"
    cp -a "${burn_profile}" "${CONFIG_DIR}/burn-my-windows/profiles/macos.conf"
    log_success "Saved active Burn My Windows profile."
fi

log_success "Saved enabled extensions to: ${COLOR_MUTED}Extensions-Configs/extensions-list.txt${COLOR_RESET}"

printf "\n  %s✔ Configurations successfully backed up!%s\n\n" "${COLOR_GREEN}" "${COLOR_RESET}"
