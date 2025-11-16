# 🛡️ DNS Blocker - Cloudflare Family DNS Enforcer

**Force Cloudflare Family DNS (1.1.1.3 / 1.0.0.3) system-wide on macOS**  
Blocks adult content, malware, and prevents DNS-over-HTTPS (DoH) bypasses.

---

## 🎯 What This Does

- ✅ Enforces **Cloudflare Family DNS** (1.1.1.3 / 1.0.0.3) on all network interfaces
- ✅ Persists across reboots and network changes
- ✅ Disables DNS-over-HTTPS in Chrome, Firefox, Brave, Edge, Opera, Vivaldi, Safari
- ✅ Disables Safari iCloud Private Relay (prevents DNS bypass)
- ✅ Blocks VPN and Tor domains via `/etc/hosts` (60+ sites)
- ✅ Applies system-wide to all users (admin installs for non-admin users)
- ✅ Re-checks and re-applies DNS every 20 seconds
- ✅ Self-healing: automatically restores settings if tampered with
- ✅ Works on macOS Ventura (13.x) through Sequoia (15.x)

---

## 📋 System Requirements

- macOS 13.0 (Ventura) or later
- Administrator/sudo privileges
- Active internet connection

---

## 🚀 Quick Install

```bash
git clone https://github.com/yourusername/dns-blocker.git
cd dns-blocker
sudo ./install.sh
```

---

## 🔍 What Gets Installed

| File | Location | Purpose |
|------|----------|---------|
| `force-dns.sh` | `/usr/local/sbin/` | Script that enforces DNS settings & hosts file |
| `com.blocker.force-dns.plist` | `/Library/LaunchDaemons/` | Auto-runs script on boot & network changes |
| `blocklist-vpn-tor.txt` | `/usr/local/share/dns-blocker/` | VPN/Tor domain blocklist |
| `com.google.Chrome.plist` | `/Library/Managed Preferences/` | Disables DoH in Chrome |
| `org.mozilla.firefox.plist` | `/Library/Managed Preferences/` | Disables DoH in Firefox |
| `com.brave.Browser.plist` | `/Library/Managed Preferences/` | Disables DoH in Brave |
| `com.microsoft.Edge.plist` | `/Library/Managed Preferences/` | Disables DoH in Edge |
| `com.operasoftware.Opera.plist` | `/Library/Managed Preferences/` | Disables DoH in Opera |
| `com.vivaldi.Vivaldi.plist` | `/Library/Managed Preferences/` | Disables DoH in Vivaldi |
| `com.apple.Safari.plist` | `/Library/Managed Preferences/` | Disables iCloud Private Relay in Safari |
| `VPN/Tor blocklist` | `/etc/hosts` | Appends blocklist entries (self-healing) |

---

## ✅ Verify Installation

### Check DNS Settings
```bash
networksetup -getdnsservers Wi-Fi
# Expected output:
# 1.1.1.3
# 1.0.0.3
# 2606:4700:4700::1113
# 2606:4700:4700::1003
```

### Check LaunchDaemon Status
```bash
sudo launchctl print system/com.blocker.force-dns | head -n 10
```

### View Logs
```bash
log show --predicate 'eventMessage CONTAINS "force-dns"' --last 5m
```

---

## 🗑️ Uninstall

```bash
sudo ./uninstall.sh
```

To restore automatic DNS (from DHCP/router):
```bash
sudo networksetup -setdnsservers Wi-Fi Empty
```

---

## 🔧 How It Works

1. **LaunchDaemon** runs at boot and every 20 seconds
2. **Watches** system network config files for changes
3. **Applies** Cloudflare Family DNS to all active network services
4. **Managed Preferences** disable DoH in major browsers
5. **Persists** across reboots, user switches, and network changes

---

## 🧪 Manual Testing

```bash
# Run the script manually
sudo /usr/local/sbin/force-dns.sh

# Check all active network services
for svc in $(networksetup -listallnetworkservices | sed '1d' | sed '/^\*/d'); do
  echo "=== $svc ==="
  networksetup -getdnsservers "$svc"
done

# Test DNS resolution
dig +short @1.1.1.3 example.com
nslookup example.com 1.1.1.3

# Verify VPN/Tor blocking
ping nordvpn.com  # Should fail (0.0.0.0)
ping torproject.org  # Should fail (0.0.0.0)
curl -I https://expressvpn.com  # Should fail to connect

# Check hosts file
tail -100 /etc/hosts | grep "DNS-BLOCKER"

# Verify Safari Private Relay is disabled
defaults read /Library/Managed\ Preferences/com.apple.Safari.plist PrivateRelayEnabled
# Should return: 0 (disabled)
```

---

## 🛠️ Troubleshooting

### LaunchDaemon not running?
```bash
# Reload the daemon
sudo launchctl bootout system /Library/LaunchDaemons/com.blocker.force-dns.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.blocker.force-dns.plist
sudo launchctl enable system/com.blocker.force-dns
sudo launchctl kickstart -k system/com.blocker.force-dns
```

### DNS settings reverting?
Check logs for errors:
```bash
tail -f /var/log/force-dns.err
```

### Browser still using DoH?
Restart the browser after installation. Check browser settings:
- **Chrome**: chrome://settings/security → "Use secure DNS" should be OFF
- **Firefox**: about:preferences#general → "Enable DNS over HTTPS" should be OFF

---

## ⚠️ Important Notes

- **Target Users**: Designed for admins to install system-wide for **non-admin users**. Non-admin users cannot bypass these restrictions.
- **VPN/Tor Blocking**: Blocks 60+ VPN and Tor domains via `/etc/hosts`. Prevents installation, authentication, and updates of VPN clients.
- **Admin Users**: Admin users can temporarily override settings, but they will auto-revert within 20 seconds.
- **Network Services**: Script applies to all active services (Wi-Fi, Ethernet, Thunderbolt, etc.)
- **Safari Private Relay**: Automatically disabled to prevent DNS bypass via iCloud+.
- **No App Breakage**: Conservative blocklist designed to not interfere with Slack, Zoom, or other legitimate apps.

---

## 📂 Repository Structure

```
blocker-script/
├── README.md
├── install.sh
├── uninstall.sh
├── force-dns.sh
├── com.blocker.force-dns.plist
├── blocklist-vpn-tor.txt
└── managed-preferences/
    ├── com.google.Chrome.plist
    ├── org.mozilla.firefox.plist
    ├── com.brave.Browser.plist
    ├── com.microsoft.Edge.plist
    ├── com.operasoftware.Opera.plist
    ├── com.vivaldi.Vivaldi.plist
    └── com.apple.Safari.plist
```

---

## 🔐 Security Features

- **Forces Cloudflare Family DNS** which filters adult content and malware
- **Disables DoH/DoT** to prevent DNS bypass at the application level
- **Blocks VPN/Tor domains** via self-healing `/etc/hosts` entries (60+ domains)
- **Disables Safari Private Relay** to prevent iCloud+ DNS bypass
- **System-wide enforcement** that persists across network changes
- **Automatic monitoring** detects and reverts unauthorized DNS changes every 20 seconds
- **Self-healing**: Restores `/etc/hosts` blocklist if tampered with
- **Runs with root privileges** to prevent non-admin users from bypassing
- **Conservative blocking**: Won't break Slack, Zoom, or other legitimate apps

---

## 📜 License

MIT License - See LICENSE file for details

---

## 🙏 Credits

Cloudflare Family DNS: https://1.1.1.1/family/

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

---

## ❓ FAQ

### Q: Who is this for?
A: Admins who want to enforce DNS filtering for **non-admin users** (e.g., parents, employers, educators). Non-admin users cannot bypass these restrictions without root access.

### Q: Will this block VPNs and Tor?
A: Yes! It blocks 60+ VPN and Tor provider domains via `/etc/hosts`, preventing:
- VPN client downloads and updates
- VPN authentication
- Tor Browser downloads
- Web-based proxy sites

**Note:** Already-installed VPN clients that connect via IP addresses may still work, but most require domain-based authentication which will be blocked.

### Q: Can non-admin users disable this?
A: **No.** Non-admin users cannot:
- Edit `/etc/hosts` (requires root)
- Modify DNS settings permanently (auto-reverts in 20s)
- Disable the LaunchDaemon (requires root)
- Bypass managed browser preferences (system-level)

### Q: Will this break Slack, Zoom, or other apps?
A: **No.** The blocklist is conservative and only targets VPN/Tor/proxy domains. It does not interfere with:
- Video conferencing (Zoom, Teams, Google Meet)
- Business apps (Slack, Discord, messaging)
- Cloud services (Dropbox, Google Drive)
- Streaming services (Netflix, Spotify)

### Q: What about Safari Private Relay?
A: It's automatically disabled via managed preference. Non-admin users cannot re-enable it.

### Q: What if I want to use different DNS servers?
A: Edit the `force-dns.sh` file and change the `DNSV4_1`, `DNSV4_2`, `DNSV6_1`, and `DNSV6_2` variables to your preferred DNS servers.

### Q: Does this affect network performance?
A: Cloudflare DNS (1.1.1.3) is one of the fastest DNS providers globally. You should not notice any performance degradation.

