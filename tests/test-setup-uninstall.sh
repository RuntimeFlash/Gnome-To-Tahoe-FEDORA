#!/usr/bin/env bash
# Integration test for setup's backup and uninstall's restoration paths.
# Everything runs beneath a temporary HOME with stubbed GNOME commands.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT

export HOME="${TEST_ROOT}/home"
export XDG_STATE_HOME="${TEST_ROOT}/state"
export PATH="${TEST_ROOT}/bin:${PATH}"
mkdir -p "${HOME}/.local/share/gnome-shell/extensions/original@test" "${HOME}/.themes" "${HOME}/.local/share/themes" "${TEST_ROOT}/bin"
printf 'original extension\n' > "${HOME}/.local/share/gnome-shell/extensions/original@test/metadata.json"

cat > "${TEST_ROOT}/bin/dconf" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == dump ]]; then
    printf '[test]\nvalue=true\n'
elif [[ "$1" == load ]]; then
    cat >/dev/null
else
    exit 2
fi
EOF
cat > "${TEST_ROOT}/bin/gsettings" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == get ]]; then
    printf "['original@test']\n"
elif [[ "$1" == set ]]; then
    printf '%s\n' "$*" >> "${XDG_STATE_HOME}/gsettings-calls"
else
    exit 2
fi
EOF
cat > "${TEST_ROOT}/bin/gnome-extensions" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${XDG_STATE_HOME}/gnome-extensions-calls"
EOF
chmod +x "${TEST_ROOT}/bin/dconf" "${TEST_ROOT}/bin/gsettings" "${TEST_ROOT}/bin/gnome-extensions"

# setup.sh is sourceable for testability; this calls its backup function only.
source "${REPO_DIR}/setup.sh"
backup_current_state >/dev/null
snapshot="$(<"${XDG_STATE_HOME}/gnome-to-macos/latest")"
[[ -f "${snapshot}/extensions/original@test/metadata.json" ]]
[[ "$(<"${snapshot}/enabled-extensions.txt")" == "['original@test']" ]]
printf 'PASS: setup snapshot contains extensions and GNOME settings\n'

# Simulate project changes made after the snapshot, then restore them.
mkdir -p "${HOME}/.local/share/gnome-shell/extensions/project@test"
printf 'project extension\n' > "${HOME}/.local/share/gnome-shell/extensions/project@test/metadata.json"
mkdir -p "${HOME}/.themes/MacTahoe-Dark-blue" "${HOME}/.local/share/themes/MacTahoe-Dark-blue"

printf 'y\n' | "${REPO_DIR}/uninstall.sh" >/dev/null
[[ -f "${HOME}/.local/share/gnome-shell/extensions/original@test/metadata.json" ]]
[[ ! -e "${HOME}/.local/share/gnome-shell/extensions/project@test" ]]
[[ -f "${XDG_STATE_HOME}/gsettings-calls" ]]
rg -q 'set org.gnome.shell enabled-extensions' "${XDG_STATE_HOME}/gsettings-calls"
[[ -e "${HOME}/.themes/MacTahoe-Dark-blue.gnome-to-macos-removed" ]]
[[ -e "${HOME}/.local/share/themes/MacTahoe-Dark-blue.gnome-to-macos-removed" ]]
printf 'PASS: uninstall restores the snapshot and preserves removed project files\n'
