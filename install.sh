#!/usr/bin/env bash

set -e


echo "Pi 4 Hardware Monitor Installer"


# Must be root

if [ "$EUID" -ne 0 ]; then

  echo "Run with sudo"

  exit 1

fi


# Check required files

if [ ! -f Makefile ] || [ ! -f package.json ] || [ ! -d src ]; then

  echo "Run this from the project root folder"

  exit 1

fi


# Install dependencies (minimal)

apt update

apt install -y nodejs npm make cockpit-bridge python3


# Build + install plugin

echo "Building plugin..."

make


echo "Installing plugin..."

make install


# Install history script + services

echo "Installing history collector..."


install -d -m 0755 /usr/local/bin /etc/systemd/system /var/lib/pi-monitor


install -m 0755 ./pi-monitor-history /usr/local/bin/pi-monitor-history

install -m 0644 ./pi-monitor-history.service /etc/systemd/system/

install -m 0644 ./pi-monitor-history.timer /etc/systemd/system/


systemctl daemon-reload

systemctl enable --now pi-monitor-history.timer


echo "Done."

echo "Open Cockpit → Pi 4 Hardware Monitor"
