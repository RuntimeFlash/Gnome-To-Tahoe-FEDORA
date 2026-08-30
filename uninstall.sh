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

# Build the project-managed UUID set once. It is also used to remove them from
# GNOME's enabled-extensions setting before their files are removed.
managed_extensions=()
if [[ -f "${CONFIG_DIR}/extensions-list.txt" ]]; then
    while IFS= read -r uuid || [[ -n "${uuid}" ]]; do
        uuid="${uuid//$'\r'/}"
        uuid="${uuid// /}"
        [[ -n "${uuid}" ]] && managed_extensions+=("${uuid}")
    done < "${CONFIG_DIR}/extensions-list.txt"
fi
managed_extensions+=("liquid-glass-v2@thinkingcoding1231.gmail.com")

# The setting is authoritative. This succeeds even if the live Shell has not
# yet discovered an extension directory, unlike relying on the CLI alone.
current_enabled="$(gsettings get org.gnome.shell enabled-extensions)"
managed_serialized="$(printf '%s\n' "${managed_extensions[@]}")"
remaining_enabled="$(CURRENT_ENABLED="${current_enabled}" MANAGED_EXTENSIONS="${managed_serialized}" python3 - <<'PY'
import ast
import os

enabled = ast.literal_eval(os.environ['CURRENT_ENABLED'])
managed = set(filter(None, os.environ['MANAGED_EXTENSIONS'].splitlines()))
if not isinstance(enabled, list) or not all(isinstance(uuid, str) for uuid in enabled):
    raise ValueError('enabled-extensions is not a list of UUIDs')
print(repr([uuid for uuid in enabled if uuid not in managed]))
PY
)"
gsettings set org.gnome.shell enabled-extensions "${remaining_enabled}"
info "Disabled project extensions in GNOME settings."

if command -v gnome-extensions >/dev/null 2>&1; then
    for uuid in "${managed_extensions[@]}"; do
        gnome-extensions disable "${uuid}" >/dev/null 2>&1 || true
    done
fi

if [[ -n "${snapshot}" ]]; then
    # Restore only project-managed extensions. Extensions installed after setup
    # but unrelated to this project are left untouched.
    for uuid in "${managed_extensions[@]}"; do
        # UUIDs come from this repository; reject anything unsafe before acting.
        [[ "${uuid}" != */ && "${uuid}" != .* ]] || die "Unsafe extension UUID in configuration: ${uuid}"
        target="${EXT_DEST_DIR}/${uuid}"
        previous="${snapshot}/extensions/${uuid}"
        if [[ -e "${previous}" ]]; then
            # This extension existed before setup: restore its prior files.
            if [[ -e "${target}" ]]; then
                rm -rf -- "${target}"
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
    for uuid in "${managed_extensions[@]}"; do
        [[ "${uuid}" != */ && "${uuid}" != .* ]] || die "Unsafe extension UUID in configuration: ${uuid}"
        [[ -e "${EXT_DEST_DIR}/${uuid}" ]] && rm -rf -- "${EXT_DEST_DIR}/${uuid}"
    done
fi

for theme_name in MacTahoe-Dark-blue MacTahoe-Dark-blue-hdpi MacTahoe-Dark-blue-xhdpi; do
    [[ -e "${THEMES_DEST_DIR}/${theme_name}" ]] && rm -rf -- "${THEMES_DEST_DIR}/${theme_name}"
    [[ -e "${LOCAL_THEMES_DEST_DIR}/${theme_name}" ]] && rm -rf -- "${LOCAL_THEMES_DEST_DIR}/${theme_name}"
done

[[ -n "${snapshot}" ]] && rm -f -- "${BACKUP_LATEST_FILE}"
info "Uninstall complete. Log out and back in to fully reload GNOME Shell."
