#!/bin/bash
#
#  unlock-gatekeeper.sh
#  Removes Gatekeeper's quarantine attribute from apps and files downloaded
#  from the internet, so macOS lets them open.
#
#  Usage:
#      ./unlock-gatekeeper.sh "/Applications/Some App.app"
#      ./unlock-gatekeeper.sh file1.app file2.dmg ...
#      ./unlock-gatekeeper.sh              (opens a file picker)
#      printf '%s\n' /path/to/app | ./unlock-gatekeeper.sh
#
#  Options:
#      -n, --no-open    do not open the app after unlocking it
#      -q, --quiet      no dialogs (log only)
#      -h, --help       show this help
#      -V, --version    show the version
#
#  Environment variables (same as the options above):
#      UNLOCK_OPEN=0    do not open the app after unlocking it
#      UNLOCK_QUIET=1   no dialogs (log only)
#
#  Log: ~/Library/Logs/GatekeeperFileUnlock.log
#

set -uo pipefail

VERSION="1.0.0"

QUARANTINE="com.apple.quarantine"

LOG_DIR="$HOME/Library/Logs"
LOG="$LOG_DIR/GatekeeperFileUnlock.log"

OPEN_AFTER="${UNLOCK_OPEN:-1}"
QUIET="${UNLOCK_QUIET:-0}"

# ---------------------------------------------------------------- messages --

log() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG" 2>/dev/null
}

notify() {
    log "$1"
    [ "$QUIET" = "1" ] && return 0
    osascript -e 'on run argv' \
              -e 'display notification (item 1 of argv) with title "Unlock Gatekeeper"' \
              -e 'end run' "$1" >/dev/null 2>&1 || true
}

fail() {
    log "ERROR: $1"
    if [ "$QUIET" = "1" ]; then
        printf 'ERROR: %s\n' "$1" >&2
    else
        osascript -e 'on run argv' \
                  -e 'display alert "Unlock Gatekeeper" message (item 1 of argv) as critical' \
                  -e 'end run' "$1" >/dev/null 2>&1 \
            || printf 'ERROR: %s\n' "$1" >&2
    fi
}

usage() {
    cat <<'EOF'
unlock-gatekeeper - remove Gatekeeper's quarantine from apps and files

Usage:
    unlock-gatekeeper.sh "/Applications/Some App.app"
    unlock-gatekeeper.sh file1.app file2.dmg ...
    unlock-gatekeeper.sh              (opens a file picker)
    printf '%s\n' /path/to/app | unlock-gatekeeper.sh

Options:
    -n, --no-open    do not open the app after unlocking it
    -q, --quiet      no dialogs (log only)
    -h, --help       show this help
    -V, --version    show the version

Environment variables:
    UNLOCK_OPEN=0    same as --no-open
    UNLOCK_QUIET=1   same as --quiet

Log: ~/Library/Logs/GatekeeperFileUnlock.log
EOF
}

# Runs a command with administrator privileges (asks for the password).
as_admin() {
    osascript -e 'on run argv' \
              -e 'do shell script (item 1 of argv) with administrator privileges' \
              -e 'end run' "$1" 2>&1
}

# ---------------------------------------------------------------- helpers ---

# Number of items (files or folders) that still carry the quarantine attribute.
count_quarantine() {
    xattr -r "$1" 2>/dev/null | grep -c -- "$QUARANTINE"
}

normalize() {
    local p="$1"
    case "$p" in
        "~"*) p="$HOME${p#\~}" ;;
    esac
    case "$p" in
        /*) ;;
        *) p="$PWD/$p" ;;
    esac
    # Strip trailing slashes (except for the root).
    while [ "${p%/}" != "$p" ] && [ "$p" != "/" ]; do p="${p%/}"; done
    printf '%s' "$p"
}

is_app() {
    case "$1" in
        *.[aA][pP][pP]) return 0 ;;
        *) return 1 ;;
    esac
}

# ---------------------------------------------------------------- unlock ----

unlock() {
    local p had left
    p="$(normalize "$1")"

    if [ ! -e "$p" ]; then
        fail "File not found: $p"
        return 1
    fi

    if [ ! -w "$p" ] && [ ! -w "$(dirname "$p")" ]; then
        log "Insufficient permissions on $p: trying administrator authorization."
        if ! as_admin "/usr/bin/xattr -dr $QUARANTINE $(printf '%q' "$p")" >/dev/null 2>&1; then
            fail "I don't have permission to modify:\n$p\nMove the file to a folder you own (e.g. Downloads) and try again."
            return 1
        fi
    fi

    had="$(count_quarantine "$p")"
    log "Unlocking: $p (quarantine attributes: $had)"

    # 1. Remove quarantine recursively.
    xattr -dr "$QUARANTINE" "$p" 2>/dev/null

    # 2. If something is left (permissions), retry as administrator.
    left="$(count_quarantine "$p")"
    if [ "$left" -gt 0 ]; then
        log "$left attributes left: retrying with administrator authorization."
        as_admin "/usr/bin/xattr -dr $QUARANTINE $(printf '%q' "$p")" >/dev/null 2>&1
        left="$(count_quarantine "$p")"
    fi

    if [ "$left" -gt 0 ]; then
        fail "Could not remove quarantine from:\n$p\n(attributes left: $left)"
        return 1
    fi

    # 3. For apps, make sure the signature is still valid after the change.
    if [ -d "$p" ] && is_app "$p"; then
        if ! codesign --verify --deep --strict "$p" >/dev/null 2>&1; then
            log "Invalid signature on $p: applying an ad-hoc signature."
            codesign --force --deep --sign - --preserve-metadata=entitlements "$p" >/dev/null 2>&1 \
                || codesign --force --deep --sign - "$p" >/dev/null 2>&1 \
                || log "Ad-hoc signing failed (the app may still open)."
        fi
    fi

    # 4. Open the app if requested.
    if [ "$OPEN_AFTER" = "1" ] && [ -d "$p" ] && is_app "$p"; then
        open "$p" >/dev/null 2>&1 || true
    fi

    log "Unlocked: $p"
    return 0
}

# ---------------------------------------------------------------- entry -----

FILES=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -V|--version)
            printf 'unlock-gatekeeper %s\n' "$VERSION"
            exit 0
            ;;
        -n|--no-open)
            OPEN_AFTER=0
            shift
            ;;
        -q|--quiet)
            QUIET=1
            shift
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                FILES+=("$1")
                shift
            done
            ;;
        -*)
            fail "Unknown option: $1"
            exit 2
            ;;
        *)
            FILES+=("$1")
            shift
            ;;
    esac
done

# No arguments but data on stdin (pipe or Finder service): each line is a path.
if [ "${#FILES[@]}" -eq 0 ] && [ ! -t 0 ]; then
    while IFS= read -r line; do
        [ -n "$line" ] && FILES+=("$line")
    done
fi

if [ "${#FILES[@]}" -eq 0 ]; then
    # No arguments: ask the user which files to unlock.
    if [ "$QUIET" = "1" ]; then
        fail "No files specified."
        exit 1
    fi
    CHOICE="$(osascript -e 'on run argv' \
        -e 'set picks to choose file with prompt "Choose the app or file to unlock" with multiple selections allowed' \
        -e 'set output to ""' \
        -e 'repeat with pick in picks' \
        -e 'set output to output & (POSIX path of pick) & linefeed' \
        -e 'end repeat' \
        -e 'return output' \
        -e 'end run' 2>/dev/null)" || exit 0   # cancelled

    [ -n "$CHOICE" ] || exit 0
    while IFS= read -r line; do
        [ -n "$line" ] && FILES+=("$line")
    done <<< "$CHOICE"
fi

OK=0
KO=0
for item in "${FILES[@]}"; do
    if unlock "$item"; then
        OK=$((OK + 1))
    else
        KO=$((KO + 1))
    fi
done

if [ "$KO" -eq 0 ]; then
    if [ "$OK" -eq 1 ]; then
        notify "Unlocked. The file can now be opened normally."
    else
        notify "$OK items unlocked. They can now be opened normally."
    fi
    exit 0
else
    if [ "$OK" -gt 0 ]; then
        notify "$OK unlocked, $KO failed. Check the log: ~/Library/Logs/GatekeeperFileUnlock.log"
    fi
    exit 1
fi
