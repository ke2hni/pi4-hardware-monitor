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

## 📸 Screenshots (Right after install with no history data also no PWM Fan Present)

<img width="1600" height="900" alt="Screenshot 2026-06-01 230646" src="https://github.com/user-attachments/assets/1a818f7b-cbfb-4a81-8a4e-d2e4dd5a181d" />
<img width="1600" height="900" alt="Screenshot 2026-06-01 230700" src="https://github.com/user-attachments/assets/82262bb4-b28a-4b07-b942-085b795aabd4" />
<img width="1600" height="900" alt="Screenshot 2026-06-01 230707" src="https://github.com/user-attachments/assets/d5f28b5b-4b29-4fca-af62-b9919620569c" />
<img width="1600" height="900" alt="Screenshot 2026-06-01 230712" src="https://github.com/user-attachments/assets/6857aaf0-75d1-4e71-b37e-3cb9d6b56000" />

---

## 📸 Screenshots (After history data had been collected & a PWN Fan installed)

<img width="1600" height="900" alt="Screenshot 2026-06-01 231422" src="https://github.com/user-attachments/assets/e666a4cb-7c55-4a87-ab01-6daf9b221392" />
<img width="1600" height="900" alt="Screenshot 2026-06-01 231431" src="https://github.com/user-attachments/assets/2beef88e-4102-409d-af56-71103fd0d37f" />
<img width="1600" height="900" alt="Screenshot 2026-06-01 231439" src="https://github.com/user-attachments/assets/cd79c98e-0082-4a50-b6ed-72d0623cdf56" />
<img width="1600" height="900" alt="Screenshot 2026-06-01 231447" src="https://github.com/user-attachments/assets/48681fbf-0b87-4ece-9959-b08e6633c50b" />
