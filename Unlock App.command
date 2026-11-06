#!/bin/bash
#
#  Unlock App.command
#  Double-click to unlock an app (or a file) without using the context menu.
#

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HOME/Library/Application Support/GatekeeperFileUnlock/unlock-gatekeeper.sh"

if [ ! -x "$SCRIPT" ]; then
    SCRIPT="$SELF_DIR/unlock-gatekeeper.sh"
fi

if [ ! -x "$SCRIPT" ]; then
    osascript -e 'display alert "Unlock app" message "unlock-gatekeeper.sh was not found. Run install-finder-service.sh first." as critical'
    exit 1
fi

exec "$SCRIPT" "$@"
