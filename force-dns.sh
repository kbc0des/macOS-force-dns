#!/bin/bash
set -eu
export PATH="/usr/sbin:/usr/bin:/bin:/usr/local/sbin:/usr/local/bin"

DNSV4_1="1.1.1.3"
DNSV4_2="1.0.0.3"
DNSV6_1="2606:4700:4700::1113"
DNSV6_2="2606:4700:4700::1003"

NETWORKSETUP="/usr/sbin/networksetup"
SED="/usr/bin/sed"
TR="/usr/bin/tr"
DSCACHEUTIL="/usr/bin/dscacheutil"
KILLALL="/usr/bin/killall"
LOGGER="/usr/bin/logger"

# Get all enabled network services (skip header, drop disabled)
# Using process substitution to avoid subshell and ensure exit 1 works correctly
while IFS= read -r svc; do
  [ -z "$svc" ] && continue

  current="$("$NETWORKSETUP" -getdnsservers "$svc" 2>/dev/null || true | "$TR" '\n' ' ')"

  if [[ "$current" != *"$DNSV4_1"* || "$current" != *"$DNSV6_1"* ]]; then
    if "$NETWORKSETUP" -setdnsservers "$svc" "$DNSV4_1" "$DNSV4_2" "$DNSV6_1" "$DNSV6_2"; then
      "$LOGGER" -t force-dns "Set DNS on '$svc' -> $DNSV4_1 $DNSV4_2 $DNSV6_1 $DNSV6_2"
    else
      "$LOGGER" -t force-dns "FAILED setting DNS on '$svc'"
      exit 1
    fi
  fi
done < <("$NETWORKSETUP" -listallnetworkservices | "$SED" '1d' | "$SED" '/^\*/d')

"$DSCACHEUTIL" -flushcache 2>/dev/null || true
"$KILLALL" -HUP mDNSResponder 2>/dev/null || true

# Verify hosts file hasn't been tampered with
HOSTS_FILE="/etc/hosts"
MARKER_START="# BEGIN DNS-BLOCKER VPN/TOR BLOCK"
MARKER_END="# END DNS-BLOCKER VPN/TOR BLOCK"
BLOCKLIST_PATH="/usr/local/share/dns-blocker/blocklist-vpn-tor.txt"

if [ -f "$BLOCKLIST_PATH" ]; then
  if ! /usr/bin/grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
    # Blocklist removed, restore it
    {
      echo ""
      echo "$MARKER_START"
      /bin/cat "$BLOCKLIST_PATH"
      echo "$MARKER_END"
    } >> "$HOSTS_FILE"
    "$LOGGER" -t force-dns "Restored VPN/Tor blocklist to hosts file"
    "$DSCACHEUTIL" -flushcache 2>/dev/null || true
  fi
fi

"$LOGGER" -t force-dns "DNS enforcement run complete"
