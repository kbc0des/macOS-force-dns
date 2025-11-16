#!/bin/bash
#
# DNS Blocker Uninstallation Script
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   DNS Blocker - Uninstaller${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}✗ This script must be run with sudo${NC}"
  echo "  Usage: sudo ./uninstall.sh"
  exit 1
fi

echo -e "${YELLOW}➜${NC} Stopping LaunchDaemon..."
launchctl bootout system /Library/LaunchDaemons/com.blocker.force-dns.plist 2>/dev/null || true
echo -e "${GREEN}✓${NC} LaunchDaemon stopped"

echo ""
echo -e "${YELLOW}➜${NC} Removing files..."

rm -f /usr/local/sbin/force-dns.sh
echo -e "${GREEN}✓${NC} Removed /usr/local/sbin/force-dns.sh"

rm -f /Library/LaunchDaemons/com.blocker.force-dns.plist
echo -e "${GREEN}✓${NC} Removed LaunchDaemon"

# Remove managed preferences
removed_count=0
for pref_file in "/Library/Managed Preferences/com.google.Chrome.plist" \
                  "/Library/Managed Preferences/org.mozilla.firefox.plist" \
                  "/Library/Managed Preferences/com.brave.Browser.plist" \
                  "/Library/Managed Preferences/com.microsoft.Edge.plist" \
                  "/Library/Managed Preferences/com.operasoftware.Opera.plist" \
                  "/Library/Managed Preferences/com.vivaldi.Vivaldi.plist" \
                  "/Library/Managed Preferences/com.apple.Safari.plist"; do
  if [ -f "$pref_file" ]; then
    rm -f "$pref_file"
    echo -e "${GREEN}  ✓${NC} Removed $(basename "$pref_file")"
    ((removed_count++))
  fi
done

if [ $removed_count -eq 0 ]; then
  echo -e "${YELLOW}⚠${NC} No managed preferences found"
else
  echo -e "${GREEN}✓${NC} Removed $removed_count browser preference files"
fi

# Remove VPN/Tor blocklist from hosts file
echo ""
echo -e "${YELLOW}➜${NC} Removing VPN/Tor blocklist from hosts file..."

HOSTS_FILE="/etc/hosts"
MARKER_START="# BEGIN DNS-BLOCKER VPN/TOR BLOCK"
MARKER_END="# END DNS-BLOCKER VPN/TOR BLOCK"

if grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
  # Remove entries between markers
  sed -i '' "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE"
  
  # Flush DNS cache
  dscacheutil -flushcache 2>/dev/null || true
  killall -HUP mDNSResponder 2>/dev/null || true
  
  echo -e "${GREEN}✓${NC} Removed VPN/Tor blocklist from hosts file"
  
  if [ -f "$HOSTS_FILE.dns-blocker-backup" ]; then
    echo -e "${GREEN}  ℹ${NC} Backup available at $HOSTS_FILE.dns-blocker-backup"
  fi
else
  echo -e "${YELLOW}⚠${NC} No blocklist found in hosts file"
fi

# Remove blocklist directory
if [ -d /usr/local/share/dns-blocker ]; then
  rm -rf /usr/local/share/dns-blocker
  echo -e "${GREEN}✓${NC} Removed blocklist directory"
fi

# Clean up logs
echo ""
echo -e "${YELLOW}➜${NC} Cleaning up logs..."
rm -f /var/log/force-dns.out /var/log/force-dns.err
echo -e "${GREEN}✓${NC} Logs removed"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Uninstallation complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "The DNS enforcement has been removed."
echo "Your network DNS settings will remain as they were last set."
echo ""
echo "To reset DNS to automatic (DHCP):"
echo "  sudo networksetup -setdnsservers Wi-Fi Empty"
echo ""

