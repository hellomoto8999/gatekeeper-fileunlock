#!/bin/bash
#
#  install-finder-service.sh
#  Installs "Unlock app (Gatekeeper)" in the Finder right-click menu
#  (Services / Quick Actions) and copies the script to a stable location.
#
#  Usage:
#      ./install-finder-service.sh
#

set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="Unlock app"
SERVICE="$HOME/Library/Services/$SERVICE_NAME.workflow"
SUPPORT="$HOME/Library/Application Support/GatekeeperFileUnlock"

case "$(uname -s)" in
    Darwin) ;;
    *)
        printf 'This installer only runs on macOS.\n' >&2
        exit 1
        ;;
esac

for file in \
    "$SRC/unlock-gatekeeper.sh" \
    "$SRC/quick-action/Info.plist" \
    "$SRC/quick-action/workflow.json"
do
    if [ ! -f "$file" ]; then
        printf 'Missing file: %s\n' "$file" >&2
        printf 'Run this installer from the root of the project folder.\n' >&2
        exit 1
    fi
done

printf '› Installing the script to: %s\n' "$SUPPORT/unlock-gatekeeper.sh"
mkdir -p "$SUPPORT"
install -m 755 "$SRC/unlock-gatekeeper.sh" "$SUPPORT/unlock-gatekeeper.sh"

printf '› Creating the service: %s\n' "$SERVICE"
rm -rf "$SERVICE"
mkdir -p "$SERVICE/Contents"
cp "$SRC/quick-action/Info.plist" "$SERVICE/Contents/Info.plist"
plutil -convert xml1 -o "$SERVICE/Contents/document.wflow" "$SRC/quick-action/workflow.json"
xattr -cr "$SERVICE" 2>/dev/null || true

# Ask the system to reload the Services menu.
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true

printf '\n✔ Done.\n'
printf '  Now right-click a file or an app in Finder:\n'
printf '    Quick Actions ▸ Unlock app (Gatekeeper)\n'
printf '  (on older macOS versions the menu is called "Services").\n\n'
printf '  If the command does not appear right away, enable it in:\n'
printf '    System Settings ▸ General ▸ Login Items & Extensions ▸ Finder\n'
printf '  or restart Finder with: killall Finder\n'
