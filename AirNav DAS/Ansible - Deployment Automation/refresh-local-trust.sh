#!/bin/sh
# refresh-local-trust.sh — laptop-side convenience tool, OUTSIDE the graded Ansible project.
#
# What this solves: the Root CA is already delivered automatically to control-vm3's
# system trust store by the client_trust role (Milestone 5) — that satisfies the
# assignment's actual requirement and needs no manual step, ever.
#
# This script exists only for a separate, optional convenience: if you personally
# want to view https://labapp.com in a GUI browser on YOUR OWN laptop (not vm3),
# that laptop is outside Ansible's inventory, so nothing configures its trust
# automatically. Every time control-vm3 is rebuilt from a clean snapshot, the
# pki_ca role mints a brand-new Root CA key pair (same name, different key — see
# Milestone 4's "Remaining limitations"), which silently invalidates whatever your
# laptop trusted before. This script re-syncs your laptop's trust to match.
#
# Scope: this only updates the SHARED NSS certificate database at ~/.pki/nssdb,
# which Chromium (and other NSS-aware apps) read directly — no GUI, no clicking.
# Firefox-family browsers (this includes Zen Browser) keep their OWN, separate
# per-profile certificate database and do NOT read ~/.pki/nssdb, so they still
# need the one-time manual import described in the note this script lives next to.
#
# Usage:  ./refresh-local-trust.sh [control-vm3-address]
# Requires: ssh key access to control-vm3, and `certutil` (nss-tools package).

set -eu

CONTROL_VM3="${1:-192.168.100.40}"
DEST_DIR="$HOME/Downloads"
DEST_FILE="$DEST_DIR/airnav-lab-root-ca.crt"
NSSDB="sql:$HOME/.pki/nssdb"
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

mkdir -p "$HOME/.pki/nssdb"

# Remove any previously trusted copy under this nickname first — if the CA was
# regenerated since last time, its key differs even though the name is identical,
# and NSS does not automatically replace an existing entry with the same nickname.
if certutil -d "$NSSDB" -L -n "$CERT_NICK" >/dev/null 2>&1; then
    echo "==> Removing the previously trusted (now stale) certificate under this name..."
    certutil -d "$NSSDB" -D -n "$CERT_NICK"
fi

echo "==> Importing the current Root CA into the shared NSS trust database..."
certutil -d "$NSSDB" -A -t "C,," -n "$CERT_NICK" -i "$DEST_FILE"

echo "==> Done. Chromium (and any other NSS-aware app on this account) now trusts"
echo "    the CURRENT labapp.com certificate — no browser restart normally required."
echo
echo "    Zen Browser keeps its own separate certificate store and is NOT updated"
echo "    by this script. See the note this script lives next to for the manual"
echo "    Zen import steps (Settings -> Privacy & Security -> Certificates)."
