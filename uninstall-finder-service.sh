#!/bin/bash
#
#  uninstall-finder-service.sh
#  Removes the Finder service and the installed helper script.
#
#  Usage:
#      ./uninstall-finder-service.sh           keep the log file
#      ./uninstall-finder-service.sh --purge   also remove the log file
#

set -euo pipefail

SERVICE_NAME="Unlock app"
SERVICE="$HOME/Library/Services/$SERVICE_NAME.workflow"
SUPPORT="$HOME/Library/Application Support/GatekeeperFileUnlock"
LOG="$HOME/Library/Logs/GatekeeperFileUnlock.log"

PURGE=0
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        -h|--help)
            sed -n '2,11p' "$0" | sed 's/^#  \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$arg" >&2
            exit 2
            ;;
    esac
done

printf '› Removing the service: %s\n' "$SERVICE"
rm -rf "$SERVICE"

printf '› Removing the helper script: %s\n' "$SUPPORT"
rm -rf "$SUPPORT"

if [ "$PURGE" = "1" ]; then
    printf '› Removing the log: %s\n' "$LOG"
    rm -f "$LOG"
fi

/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true

printf '\n✔ Uninstalled.\n'
if [ "$PURGE" != "1" ]; then
    printf '  The log file was kept at: %s\n' "$LOG"
    printf '  Remove it with: rm "%s"\n' "$LOG"
fi
printf '  Restart Finder to refresh the menu: killall Finder\n'
