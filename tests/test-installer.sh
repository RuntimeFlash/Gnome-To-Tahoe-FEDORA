#!/usr/bin/env bash
# Safe checks: no sudo, package installation, or writes to the real GNOME profile.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${SCRIPT_DIR}"

bash -n setup.sh
bash -n uninstall.sh

python3 - <<'PY'
import json
import urllib.parse
import urllib.request

uuid = 'user-theme@gnome-shell-extensions.gcampax.github.com'
url = (
    'https://extensions.gnome.org/extension-info/?uuid='
    + urllib.parse.quote(uuid) + '&shell_version=48'
)
request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(request, timeout=20) as response:
    extension = json.load(response)
assert extension['uuid'] == uuid
assert extension['download_url']
print('PASS: GNOME Extensions exact UUID download lookup')
PY

rg -q 'backup_current_state' setup.sh
rg -q 'dconf load /org/gnome/shell/' setup.sh
rg -q 'Could not enable' setup.sh
rg -q 'shell-settings.dconf' setup.sh
rg -q 'BACKUP_LATEST_FILE' uninstall.sh
printf 'PASS: installer safety checks\n'
