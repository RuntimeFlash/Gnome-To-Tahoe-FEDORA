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

# Exercise the same GNOME CLI installer used by setup.sh in a disposable HOME.
if command -v gnome-extensions >/dev/null 2>&1; then
    TEST_ROOT="$(mktemp -d)"
    trap 'rm -rf "${TEST_ROOT}"' EXIT
    python3 - <<'PY' "${TEST_ROOT}/extension.zip"
import json
import sys
import urllib.parse
import urllib.request

uuid = 'wiggly@mojarch'
info_url = (
    'https://extensions.gnome.org/extension-info/?uuid='
    + urllib.parse.quote(uuid) + '&shell_version=50'
)
request = urllib.request.Request(info_url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(request, timeout=20) as response:
    extension = json.load(response)
download_url = urllib.parse.urljoin('https://extensions.gnome.org', extension['download_url'])
with urllib.request.urlopen(urllib.request.Request(download_url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=20) as response:
    with open(sys.argv[1], 'wb') as archive:
        archive.write(response.read())
PY
    HOME="${TEST_ROOT}/home" XDG_DATA_HOME="${TEST_ROOT}/data" \
        gnome-extensions install --force --print-uuid "${TEST_ROOT}/extension.zip" >/dev/null
    test -f "${TEST_ROOT}/data/gnome-shell/extensions/wiggly@mojarch/metadata.json"
    printf 'PASS: GNOME CLI installs an extension in an isolated HOME\n'
fi

rg -q 'backup_current_state' setup.sh
rg -q 'dconf load /org/gnome/shell/' setup.sh
rg -q 'Could not enable' setup.sh
rg -q 'shell-settings.dconf' setup.sh
rg -q 'glib-compile-schemas' setup.sh
rg -q 'InstallRemoteExtension' setup.sh
test -f Extensions-Configs/enabled-extensions-list.txt
test -f Extensions-Configs/burn-my-windows/profiles/standard.conf
rg -q 'BACKUP_LATEST_FILE' uninstall.sh
printf 'PASS: installer safety checks\n'
