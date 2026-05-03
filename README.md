# Pi 4 Hardware Monitor

![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi%204-blue)
![AllStarLink](https://img.shields.io/badge/AllStarLink%203-Compatible-purple)
![Cockpit](https://img.shields.io/badge/Cockpit-Plugin-green)
![Status](https://img.shields.io/badge/Status-Stable-brightgreen)

Cockpit plugin for monitoring Raspberry Pi 4 hardware, power, clocks, storage, and system status.

---

## 🚀 Install

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/ke2hni/pi4-hardware-monitor.git
cd pi4-hardware-monitor
sudo ./install.sh
```

---

## 🔄 Upgrade

```bash
cd ~/pi4-hardware-monitor
git pull
sudo ./install.sh
```

---

## 🗑️ Uninstall

```bash
cd ~/pi4-hardware-monitor
sudo ./uninstall.sh
```

---

## ⚙️ Features

* CPU temperature
* Power and throttling status
* Clock speeds
* Storage detection (SD / USB)
* System summary and status
* Clean Cockpit UI layout

---

## 🖥️ Requirements

* Raspberry Pi 4B
* Cockpit (`cockpit-bridge`)
* systemd
* nodejs / npm
* python3
* make
* vcgencmd
* git

---

## 📦 Installed Locations

* /usr/local/share/cockpit/pi-monitor

---

## 📝 Notes

* Raspberry Pi 4 only
* No Cockpit restart required
* Hardware sections appear only when detected
* Safe to re-run installer

---

## 📊 Status

* Stable
* Live data working
* UI fully functional

---

## 📸 Screenshots

(Add screenshots here once captured from Pi 4)

---
