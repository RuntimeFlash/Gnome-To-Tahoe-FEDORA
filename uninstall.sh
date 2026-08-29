#!/usr/bin/env bash
# Remove this project's extensions and themes, then restore the latest snapshot
# made by setup.sh. Run as the regular desktop user, never with sudo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/Extensions-Configs"
USER_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}"
EXT_DEST_DIR="${USER_DATA_DIR}/gnome-shell/extensions"
THEMES_DEST_DIR="${HOME}/.themes"
LOCAL_THEMES_DEST_DIR="${USER_DATA_DIR}/themes"
BACKUP_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}/gnome-to-macos"
BACKUP_LATEST_FILE="${BACKUP_ROOT}/latest"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
info() { printf '• %s\n' "$*"; }

[[ ${EUID} -ne 0 ]] || die "Run this script as your regular desktop user, without sudo."
command -v dconf >/dev/null 2>&1 || die "dconf is required to restore GNOME settings."
command -v gsettings >/dev/null 2>&1 || die "gsettings is required to restore enabled extensions."

snapshot=""
if [[ -f "${BACKUP_LATEST_FILE}" ]]; then
    IFS= read -r snapshot < "${BACKUP_LATEST_FILE}" || true
fi
if [[ -n "${snapshot}" && ! -d "${snapshot}" ]]; then
    die "The recorded backup no longer exists: ${snapshot}"
fi

printf 'This removes the GNOME extensions and MacTahoe themes installed by this project.\n'
if [[ -n "${snapshot}" ]]; then
    printf 'Your pre-install extensions and GNOME settings will then be restored from:\n%s\n' "${snapshot}"
else
    printf 'No pre-install snapshot was found; only this project’s files will be removed.\n'
fi
read -r -p 'Continue? [y/N]: ' response
[[ "${response}" =~ ^[Yy]$ ]] || { info "Cancelled."; exit 0; }

# Disable listed extensions before removing their files. Failures are harmless:
# an extension might already be absent or incompatible with the current shell.
if command -v gnome-extensions >/dev/null 2>&1 && [[ -f "${CONFIG_DIR}/extensions-list.txt" ]]; then
    while IFS= read -r uuid || [[ -n "${uuid}" ]]; do
        uuid="${uuid//$'\r'/}"
        uuid="${uuid// /}"
        [[ -n "${uuid}" ]] && gnome-extensions disable "${uuid}" >/dev/null 2>&1 || true
    done < "${CONFIG_DIR}/extensions-list.txt"
fi
if command -v gnome-extensions >/dev/null 2>&1; then
    gnome-extensions disable 'liquid-glass-v2@thinkingcoding1231.gmail.com' >/dev/null 2>&1 || true
fi

if [[ -n "${snapshot}" ]]; then
    # Restore only project-managed extensions. Extensions installed after setup
    # but unrelated to this project are left untouched.
    managed_extensions=()
    if [[ -f "${CONFIG_DIR}/extensions-list.txt" ]]; then
        while IFS= read -r uuid || [[ -n "${uuid}" ]]; do
            uuid="${uuid//$'\r'/}"
            uuid="${uuid// /}"
            [[ -n "${uuid}" ]] && managed_extensions+=("${uuid}")
        done < "${CONFIG_DIR}/extensions-list.txt"
    fi
    managed_extensions+=("liquid-glass-v2@thinkingcoding1231.gmail.com")

    for uuid in "${managed_extensions[@]}"; do
        # UUIDs come from this repository; reject anything unsafe before acting.
        [[ "${uuid}" != */ && "${uuid}" != .* ]] || die "Unsafe extension UUID in configuration: ${uuid}"
        target="${EXT_DEST_DIR}/${uuid}"
        previous="${snapshot}/extensions/${uuid}"
        if [[ -e "${previous}" ]]; then
            # This extension existed before setup: restore its prior files.
            if [[ -e "${target}" ]]; then
                mv "${target}" "${target}.gnome-to-macos-replaced-$(date +%Y%m%d%H%M%S)"
            fi
            mkdir -p "${EXT_DEST_DIR}"
            cp -a "${previous}" "${target}"
            info "Restored the previous ${uuid} extension files."
        elif [[ -e "${target}" ]]; then
            # This copy was introduced by setup, so remove it completely.
            rm -rf -- "${target}"
            info "Deleted newly installed ${uuid}."
        fi
    done

    # Reset extension settings first so keys introduced by newly installed
    # extensions are removed, then restore the pre-install configuration.
    dconf reset -f /org/gnome/shell/extensions/
    dconf load /org/gnome/shell/extensions/ < "${snapshot}/extensions.dconf"
    dconf load /org/gnome/desktop/interface/ < "${snapshot}/interface-settings.dconf"
    dconf load /org/gnome/desktop/wm/ < "${snapshot}/wm-settings.dconf"
    dconf load /org/gnome/shell/ < "${snapshot}/shell-settings.dconf"
    enabled_extensions="$(<"${snapshot}/enabled-extensions.txt")"
    gsettings set org.gnome.shell enabled-extensions "${enabled_extensions}"
    info "Restored the pre-install extensions and GNOME settings."
else
    if [[ -f "${CONFIG_DIR}/extensions-list.txt" ]]; then
        while IFS= read -r uuid || [[ -n "${uuid}" ]]; do
            uuid="${uuid//$'\r'/}"
            uuid="${uuid// /}"
            [[ -n "${uuid}" && -e "${EXT_DEST_DIR}/${uuid}" ]] && mv "${EXT_DEST_DIR}/${uuid}" "${EXT_DEST_DIR}/${uuid}.gnome-to-macos-removed"
        done < "${CONFIG_DIR}/extensions-list.txt"
    fi
    [[ -e "${EXT_DEST_DIR}/liquid-glass-v2@thinkingcoding1231.gmail.com" ]] && mv "${EXT_DEST_DIR}/liquid-glass-v2@thinkingcoding1231.gmail.com" "${EXT_DEST_DIR}/liquid-glass-v2@thinkingcoding1231.gmail.com.gnome-to-macos-removed"
fi

for theme_name in MacTahoe-Dark-blue MacTahoe-Dark-blue-hdpi MacTahoe-Dark-blue-xhdpi; do
    [[ -e "${THEMES_DEST_DIR}/${theme_name}" ]] && mv "${THEMES_DEST_DIR}/${theme_name}" "${THEMES_DEST_DIR}/${theme_name}.gnome-to-macos-removed"
    [[ -e "${LOCAL_THEMES_DEST_DIR}/${theme_name}" ]] && mv "${LOCAL_THEMES_DEST_DIR}/${theme_name}" "${LOCAL_THEMES_DEST_DIR}/${theme_name}.gnome-to-macos-removed"
done

info "Uninstall complete. Log out and back in to fully reload GNOME Shell."
