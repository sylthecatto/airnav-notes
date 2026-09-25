#!/bin/sh
# refresh-local-trust.sh — laptop-side convenience tool, OUTSIDE the graded Ansible project.
#
# What this solves: the Root CA is already delivered automatically to control-vm3's
# system trust store by the client_trust role (Milestone 5) — that satisfies the
# assignment's actual requirement and needs no manual step, ever.
#
# This script exists only for a separate, optional convenience: viewing
# https://labapp.com in a GUI browser on YOUR OWN laptop. That laptop is outside
# Ansible's inventory, so nothing configures its trust automatically, and every
# time control-vm3 is rebuilt from a clean snapshot, the pki_ca role mints a
# brand-new Root CA key pair (same name, different key — see Milestone 4's
# "Remaining limitations"), which silently invalidates whatever the browser
# trusted before. This script re-syncs that.
#
# PRIMARY TARGET: Zen Browser (a Firefox fork). Firefox-family browsers keep
# their own certificate database *per profile* — there is no single shared
# system location the way Chromium has one. This script finds every Zen
# profile it can and updates each one directly, using the same certutil tool
# Firefox itself relies on internally.
#
# IMPORTANT: close Zen Browser completely before running this. Firefox-family
# browsers hold their certificate database open while running; changes made
# to it while the browser is open can be silently discarded when you next
# close the browser normally.
#
# SECONDARY: if a shared NSS database also exists (used by Chromium and other
# NSS-aware apps), it is updated too, at no extra cost — harmless if you don't
# use such a browser.
#
# Usage:
#   ./refresh-local-trust.sh [control-vm3-address]
#   ZEN_PROFILE_DIR=/path/to/profile ./refresh-local-trust.sh   # manual override,
#     if this script cannot find your profile automatically (see the diagnostic
#     output it prints when that happens)
#
# Requires: ssh key access to control-vm3, and `certutil` (nss-tools package).

set -eu

CONTROL_VM3="${1:-192.168.100.40}"
DEST_DIR="$HOME/Downloads"
DEST_FILE="$DEST_DIR/airnav-lab-root-ca.crt"
CERT_NICK="AirNav DAS Lab Root CA"

command -v certutil >/dev/null 2>&1 || {
    echo "certutil not found (install the 'nss-tools' package) — aborting." >&2
    exit 1
}

mkdir -p "$DEST_DIR"

echo "==> Fetching the CURRENT Root CA from control-vm3 (${CONTROL_VM3})..."
scp -o BatchMode=yes "root@${CONTROL_VM3}:/root/lab-pki/root-ca.crt" "$DEST_FILE"

echo "==> Fingerprint of the certificate just fetched:"
openssl x509 -in "$DEST_FILE" -noout -fingerprint -sha256 -dates
echo

# ---------------------------------------------------------------------------
# Import into ONE NSS database directory (works for both a Firefox-family
# profile and the shared system database — the on-disk format is identical).
# ---------------------------------------------------------------------------
import_into() {
    profile_dir="$1"
    label="$2"

    if [ -f "$profile_dir/cert9.db" ]; then
        nssdb="sql:$profile_dir"
    elif [ -f "$profile_dir/cert8.db" ]; then
        nssdb="$profile_dir"          # legacy dbm format, no sql: prefix
    else
        echo "    (skipping $label — no cert9.db/cert8.db found in $profile_dir)"
        return 0
    fi

    if [ -f "$profile_dir/.parentlock" ] || [ -f "$profile_dir/lock" ]; then
        echo "    WARNING: $label looks like it may still be open (lock file present)."
        echo "             Close the browser fully and re-run this script if the import below fails."
    fi

    echo "==> Updating $label ($profile_dir)"
    if certutil -d "$nssdb" -L -n "$CERT_NICK" >/dev/null 2>&1; then
        echo "    Removing the previously trusted (now stale) certificate under this name..."
        certutil -d "$nssdb" -D -n "$CERT_NICK"
    fi
    certutil -d "$nssdb" -A -t "C,," -n "$CERT_NICK" -i "$DEST_FILE"
    echo "    Done — $label now trusts the current certificate."
}

# ---------------------------------------------------------------------------
# Discover every Zen Browser (Firefox-family) profile.
# ---------------------------------------------------------------------------
find_zen_profiles() {
    candidates="
        $HOME/.zen/profiles.ini
        $HOME/.var/app/app.zen_browser.zen/.zen/profiles.ini
        $HOME/.var/app/io.github.zen_browser.zen/.zen/profiles.ini
        $HOME/.mozilla/zen/profiles.ini
    "
    found_any=false
    for ini in $candidates; do
        [ -f "$ini" ] || continue
        found_any=true
        ini_dir=$(dirname "$ini")
        # Each [Profile*] block has Path=<relative-or-absolute> and IsRelative=0|1.
        awk -F= '
            /^\[Profile/ { path=""; relative=1 }
            /^Path=/     { path=substr($0, index($0,"=")+1) }
            /^IsRelative=/ { relative=substr($0, index($0,"=")+1) }
            /^\[/ && path != "" { print relative ":" path; path="" }
            END { if (path != "") print relative ":" path }
        ' "$ini" | while IFS=: read -r relative path; do
            if [ "$relative" = "1" ]; then
                echo "$ini_dir/$path"
            else
                echo "$path"
            fi
        done
    done
    if [ "$found_any" = false ]; then
        # Fall back to a direct filesystem search for the certificate database itself.
        find "$HOME" -maxdepth 8 -path "$HOME/.pki" -prune -o \
            \( -iname cert9.db -o -iname cert8.db \) -print 2>/dev/null \
            | xargs -r -n1 dirname | sort -u
    fi
}

echo "==> Looking for Zen Browser profile(s)..."
ZEN_PROFILES=""
if [ -n "${ZEN_PROFILE_DIR:-}" ]; then
    ZEN_PROFILES="$ZEN_PROFILE_DIR"
    echo "    Using manually specified profile: $ZEN_PROFILE_DIR"
else
    ZEN_PROFILES=$(find_zen_profiles)
fi

if [ -z "$ZEN_PROFILES" ]; then
    echo "    Could not find a Zen Browser profile automatically."
    echo
    echo "    To find it yourself: open Zen Browser -> type about:support in the address"
    echo "    bar -> find 'Profile Folder' -> click 'Open Folder'. That folder's path is"
    echo "    what this script needs. Then re-run this script as:"
    echo
    echo "        ZEN_PROFILE_DIR=\"<that path>\" $0 $CONTROL_VM3"
    echo
    echo "    (No changes were made to any browser trust store.)"
else
    echo "$ZEN_PROFILES" | while IFS= read -r p; do
        [ -n "$p" ] && [ -d "$p" ] && import_into "$p" "Zen Browser profile"
    done
fi

# ---------------------------------------------------------------------------
# Also refresh the shared system NSS database, if one already exists
# (harmless if it doesn't — e.g. no Chromium-family browser installed).
# ---------------------------------------------------------------------------
if [ -d "$HOME/.pki/nssdb" ]; then
    echo
    import_into "$HOME/.pki/nssdb" "shared NSS database (Chromium etc.)"
fi

echo
echo "==> Finished. If Zen Browser was open while this ran, close it completely"
echo "    and reopen it before checking https://labapp.com."
