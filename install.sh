```bash
#!/usr/bin/env bash
set -eo pipefail

echo "Pi 4 Hardware Monitor Installer"

# Must be root
if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo"
  exit 1
fi

# Ensure running from project root
if [ ! -f Makefile ] || [ ! -f package.json ] || [ ! -d src ]; then
  echo "Run this from the project root folder"
  exit 1
fi

echo "[INFO] Installing required dependencies..."
apt-get update
apt-get install -y nodejs npm make cockpit-bridge python3

# Validate cockpit
echo "[INFO] Validating Cockpit..."
if ! cockpit-bridge --packages >/dev/null 2>&1; then
  echo "[ERROR] cockpit-bridge not functioning correctly"
  exit 1
fi

# Validate vcgencmd (important for Pi telemetry)
echo "[INFO] Validating vcgencmd..."
if ! command -v vcgencmd >/dev/null 2>&1; then
  echo "[WARNING] vcgencmd not found (firmware tools missing)"
else
  vcgencmd measure_temp || echo "[WARNING] vcgencmd failed (root context)"
fi

# Build plugin
echo "[INFO] Building plugin..."
make

# Install plugin
echo "[INFO] Installing plugin..."
make install

# Verify plugin registered in cockpit
echo "[INFO] Verifying Cockpit registration..."
if cockpit-bridge --packages | grep -q "pi-monitor"; then
  echo "[OK] Plugin registered in Cockpit"
else
  echo "[WARNING] Plugin not found in cockpit package list"
fi

# Install history collector
echo "[INFO] Installing history collector..."

install -d -m 0755 /usr/local/bin /etc/systemd/system /var/lib/pi-monitor

install -m 0755 ./pi-monitor-history /usr/local/bin/pi-monitor-history
install -m 0644 ./pi-monitor-history.service /etc/systemd/system/
install -m 0644 ./pi-monitor-history.timer /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now pi-monitor-history.timer
systemctl start pi-monitor-history.service

# Validate history
echo "[INFO] Validating history collector..."
/usr/local/bin/pi-monitor-history

if [ -s /var/lib/pi-monitor/history.ndjson ]; then
  echo "[OK] History file created"
else
  echo "[WARNING] History file missing or empty"
fi

echo ""
echo "========================================"
echo " Install Complete"
echo "========================================"
echo "Open Cockpit → Pi 4 Hardware Monitor"
echo ""
```
