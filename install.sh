#!/bin/bash
#
# DNS Blocker Installation Script
# Forces Cloudflare Family DNS (1.1.1.3) system-wide on macOS
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   DNS Blocker - Cloudflare Family DNS Enforcer${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}✗ This script must be run with sudo${NC}"
  echo "  Usage: sudo ./install.sh"
  exit 1
fi

echo -e "${YELLOW}➜${NC} Checking repository structure..."

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_SRC="$REPO_DIR/force-dns.sh"
PLIST_SRC="$REPO_DIR/com.blocker.force-dns.plist"
PREFS_DIR="$REPO_DIR/managed-preferences"

if [ ! -f "$SCRIPT_SRC" ] || [ ! -f "$PLIST_SRC" ] || [ ! -d "$PREFS_DIR" ]; then
  echo -e "${RED}✗ Missing required files. Ensure you're running from the repo root.${NC}"
  exit 1
fi

echo -e "${GREEN}✓${NC} Repository structure verified"

# Step 1: Install the enforcement script
echo ""
echo -e "${YELLOW}➜${NC} Installing DNS enforcement script..."
mkdir -p /usr/local/sbin
cp "$SCRIPT_SRC" /usr/local/sbin/force-dns.sh
chown root:wheel /usr/local/sbin/force-dns.sh
chmod 755 /usr/local/sbin/force-dns.sh
echo -e "${GREEN}✓${NC} Installed to /usr/local/sbin/force-dns.sh"

# Step 2: Install the LaunchDaemon
echo ""
echo -e "${YELLOW}➜${NC} Installing LaunchDaemon..."
cp "$PLIST_SRC" /Library/LaunchDaemons/com.blocker.force-dns.plist
chown root:wheel /Library/LaunchDaemons/com.blocker.force-dns.plist
chmod 644 /Library/LaunchDaemons/com.blocker.force-dns.plist

# Validate plist
if ! plutil -lint /Library/LaunchDaemons/com.blocker.force-dns.plist >/dev/null 2>&1; then
  echo -e "${RED}✗ Invalid plist file${NC}"
  exit 1
fi
echo -e "${GREEN}✓${NC} Installed LaunchDaemon"

# Step 3: Install managed preferences for browsers
echo ""
echo -e "${YELLOW}➜${NC} Installing browser managed preferences..."
mkdir -p "/Library/Managed Preferences"

browser_count=0
for pref_file in "$PREFS_DIR"/*.plist; do
  if [ -f "$pref_file" ]; then
    filename=$(basename "$pref_file")
    cp "$pref_file" "/Library/Managed Preferences/$filename"
    chown root:wheel "/Library/Managed Preferences/$filename"
    chmod 644 "/Library/Managed Preferences/$filename"
    echo -e "${GREEN}  ✓${NC} Installed $filename"
    ((browser_count++))
  fi
done
echo -e "${GREEN}✓${NC} Installed $browser_count browser preference files"

# Step 4: Load and start the LaunchDaemon
echo ""
echo -e "${YELLOW}➜${NC} Activating LaunchDaemon..."

# Unload if already loaded (ignore errors)
launchctl bootout system /Library/LaunchDaemons/com.blocker.force-dns.plist 2>/dev/null || true

# Bootstrap and enable
launchctl bootstrap system /Library/LaunchDaemons/com.blocker.force-dns.plist
launchctl enable system/com.blocker.force-dns
launchctl kickstart -k system/com.blocker.force-dns

echo -e "${GREEN}✓${NC} LaunchDaemon activated"

# Step 5: Install VPN/Tor blocklist
echo ""
echo -e "${YELLOW}➜${NC} Installing VPN/Tor blocklist..."

BLOCKLIST_SRC="$REPO_DIR/blocklist-vpn-tor.txt"
HOSTS_FILE="/etc/hosts"
MARKER_START="# BEGIN DNS-BLOCKER VPN/TOR BLOCK"
MARKER_END="# END DNS-BLOCKER VPN/TOR BLOCK"

# Check if blocklist exists
if [ ! -f "$BLOCKLIST_SRC" ]; then
  echo -e "${YELLOW}⚠${NC} Blocklist not found, skipping VPN/Tor blocking"
else
  # Create directory for blocklist
  mkdir -p /usr/local/share/dns-blocker
  cp "$BLOCKLIST_SRC" /usr/local/share/dns-blocker/blocklist-vpn-tor.txt
  chown root:wheel /usr/local/share/dns-blocker/blocklist-vpn-tor.txt
  chmod 644 /usr/local/share/dns-blocker/blocklist-vpn-tor.txt
  echo -e "${GREEN}  ✓${NC} Copied blocklist to /usr/local/share/dns-blocker/"

  # Backup original hosts file (if not already backed up)
  if [ ! -f "$HOSTS_FILE.dns-blocker-backup" ]; then
    cp "$HOSTS_FILE" "$HOSTS_FILE.dns-blocker-backup"
    echo -e "${GREEN}  ✓${NC} Backed up original hosts file"
  fi

  # Remove old entries if they exist
  if grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
    # Use sed to remove everything between markers
    sed -i '' "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE"
    echo -e "${GREEN}  ✓${NC} Removed old blocklist entries"
  fi

  # Append new blocklist
  {
    echo ""
    echo "$MARKER_START"
    cat "$BLOCKLIST_SRC"
    echo "$MARKER_END"
  } >> "$HOSTS_FILE"

  # Flush DNS cache to apply changes
  dscacheutil -flushcache 2>/dev/null || true
  killall -HUP mDNSResponder 2>/dev/null || true

  # Count blocked domains
  blocked_count=$(grep -c "^0.0.0.0" "$BLOCKLIST_SRC" 2>/dev/null || echo "0")
  echo -e "${GREEN}✓${NC} Blocked $blocked_count VPN/Tor domains in /etc/hosts"
fi

# Step 6: Run the script immediately
echo ""
echo -e "${YELLOW}➜${NC} Applying DNS settings now..."
/usr/local/sbin/force-dns.sh
echo -e "${GREEN}✓${NC} DNS settings applied"

# Step 7: Verify
echo ""
echo -e "${YELLOW}➜${NC} Verifying installation..."

if launchctl print system/com.blocker.force-dns >/dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} LaunchDaemon is running"
else
  echo -e "${RED}✗${NC} LaunchDaemon failed to start"
  exit 1
fi

# Check DNS on Wi-Fi (if available)
wifi_dns=$(networksetup -getdnsservers "Wi-Fi" 2>/dev/null || echo "N/A")
if [[ "$wifi_dns" == *"1.1.1.3"* ]]; then
  echo -e "${GREEN}✓${NC} DNS configured correctly"
else
  echo -e "${YELLOW}⚠${NC} Could not verify Wi-Fi DNS (this is normal if Wi-Fi is not active)"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Installation complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Cloudflare Family DNS (1.1.1.3 / 1.0.0.3) is now enforced system-wide."
echo ""
echo "To verify:"
echo "  networksetup -getdnsservers Wi-Fi"
echo "  log show --predicate 'eventMessage CONTAINS \"force-dns\"' --last 5m"
echo ""
echo "To uninstall:"
echo "  sudo ./uninstall.sh"
echo ""

