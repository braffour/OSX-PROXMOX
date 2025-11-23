<div align="center">
  
# 🚀 OSX-PROXMOX - Run macOS on ANY Computer (AMD & Intel)

![GitHub stars](https://img.shields.io/github/stars/luchina-gabriel/osx-proxmox?style=flat-square)
![GitHub forks](https://img.shields.io/github/forks/luchina-gabriel/OSX-PROXMOX?style=flat-square)
![GitHub license](https://img.shields.io/github/license/luchina-gabriel/osx-proxmox?style=flat-square)
![GitHub issues](https://img.shields.io/github/issues/luchina-gabriel/osx-proxmox?style=flat-square)

</div>

![v15 - Sequoia](https://github.com/user-attachments/assets/4efd8874-dbc8-48b6-a485-73f7c38a5e06)
Easily install macOS on Proxmox VE with just a few steps! This guide provides the simplest and most effective way to set up macOS on Proxmox, whether you're using AMD or Intel hardware.

---

## 🛠 Installation Guide

1. Install a **FRESH/CLEAN** version of Proxmox VE (7.x or 8.x – preliminary 9.x support) and finish the basic wizard.
2. Log in to the **Proxmox Web Console**, open `Datacenter > YOUR_HOST_NAME > Shell`, and elevate to `root` (the installer exits if you are not root).
3. Download and run the installer script that lives in **this repository**:

```bash
curl -fsSL https://raw.githubusercontent.com/braffour/OSX-PROXMOX/refs/heads/main/install.sh -o install-osx-proxmox.sh
chmod +x install-osx-proxmox.sh
./install-osx-proxmox.sh
```

> 💡 Replace the URL above with the raw `install.sh` from your fork if you maintain one.

### What the script does

- Cleans up old `/etc/apt/sources.list.d/*` entries, installs `git`, and clones the repo into `/root/OSX-PROXMOX`.
- Streams all output to `/root/install-osx-proxmox.log` so you can `tail -f` it from another session if desired.
- Runs the interactive `setup` menu, where you will:
  - Select the storage that will hold ISO/recovery media.
  - Install prerequisite packages, configure GRUB/IOMMU/VFIO, and optionally reboot if the host still needs those changes.
  - Download at least one `recovery-<version>.iso` (options `101/102` inside the menu) and refresh the bundled OpenCore ISO (option `201`) so macOS can boot.
- Verifies (via `ensure_boot_media_ready`) that `${ISODIR}` now contains `opencore-osx-proxmox-vm.iso` **and** at least one `recovery-*.iso`. If either artifact is missing, the installer tells you exactly which menu option to re-run and exits safely.

### Menu quick reference

- Options **1–8**: create macOS VMs (High Sierra → Sequoia). You will set VM ID, name, storage, bridge, CPU/RAM, and disk size.
- Option **200**: add the Proxmox no-subscription repository.
- Option **201**: download/update the OpenCore ISO (required once per host or whenever you want the latest EFI).
- Option **202**: delete all cached recovery ISOs.
- Option **203**: remove the “No Subscription” nag banner from the UI.
- Option **204**: add/configure extra Proxmox bridges (used for cloud-style deployments).
- Option **205**: customize OpenCore `config.plist` (SMBIOS, boot-args, SIP, etc.).

If the installer stops with “Boot media missing,” just re-run `/root/OSX-PROXMOX/setup`, choose option `201`, then the recovery option for your macOS version, and rerun the installer script. Once boot media is detected, it will finish automatically and you can immediately create VMs from the menu.

🎉 After the menu completes without errors, you are ready to install macOS!
![osx-terminal](https://github.com/user-attachments/assets/ea81b920-f3e2-422e-b1ff-0d9045adc55e)
---

## 🔧 Additional Configuration

### Install EFI Package in macOS (Disable Gatekeeper First)

```bash
sudo spctl --master-disable
```

---

## 🍏 macOS Versions Supported
✅ macOS High Sierra - 10.13  
✅ macOS Mojave - 10.14  
✅ macOS Catalina - 10.15  
✅ macOS Big Sur - 11  
✅ macOS Monterey - 12  
✅ macOS Ventura - 13  
✅ macOS Sonoma - 14  
✅ macOS Sequoia - 15  

---

## 🖥 Proxmox VE Versions Supported
✅ v7.0.XX ~ 8.4.XX

### 🔄 OpenCore Version
- **April/2025 - 1.0.4** → with SIP Enabled, DMG only signed by Apple and all features of securities

---

## ☁️ Cloud Support (Run Hackintosh in the Cloud!)
- [🌍 VultR](https://www.vultr.com/?ref=9035565-8H)
- [📺 Video Tutorial](https://youtu.be/8QsMyL-PNrM) (Enable captions for better understanding)
- Now has configurable bridges, and can add as many bridges and specify the subnet for them.

---

## ⚠️ Disclaimer

🚨 **FOR DEVELOPMENT, STUDENT, AND TESTING PURPOSES ONLY.**

I am **not responsible** for any issues, damage, or data loss. Always back up your system before making any changes.

---

## 📌 Requirements

Since macOS Monterey, your host must have a **working TSC (timestamp counter)**. Otherwise, if you assign multiple cores to the VM, macOS may **crash due to time inconsistencies**. To check if your host is compatible, run the following command in Proxmox:

```bash
dmesg | grep -i -e tsc -e clocksource
```

### ✅ Expected Output (for working hosts):
```
clocksource: Switched to clocksource tsc
```

### ❌ Problematic Output (for broken hosts):
```
tsc: Marking TSC unstable due to check_tsc_sync_source failed
clocksource: Switched to clocksource hpet
```

### 🛠 Possible Fixes
1. Disable "ErP mode" and **all C-state power-saving modes** in your BIOS. Then power off your machine completely and restart.
2. Try forcing TSC in GRUB:
   - Edit `/etc/default/grub` and add:
     ```bash
     clocksource=tsc tsc=reliable
     ```
   - Run `update-grub` and reboot (This may cause instability).
3. Verify the TSC clock source:
   ```bash
   cat /sys/devices/system/clocksource/clocksource0/current_clocksource
   ```
   The output **must be `tsc`**.

[Read More](https://www.nicksherlock.com/2022/10/installing-macos-13-ventura-on-proxmox/comment-page-1/#comment-55532)

---

## 🔍 Troubleshooting

### ❌ High Sierra & Below - *Recovery Server Could Not Be Contacted*

If you encounter this error, you need to switch from **HTTPS** to **HTTP** in the installation URL:

1. When the error appears, leave the window open.
2. Open **Installer Log** (`Window > Installer Log`).
3. Search for "Failed to load catalog" → Copy the log entry.
4. Close the error message and return to `macOS Utilities`.
5. Open **Terminal**, paste the copied data, and **remove everything except the URL** (e.g., `https://example.sucatalog`).
6. Change `https://` to `http://`.
7. Run the command:

   ```bash
   nvram IASUCatalogURL="http://your-http-url.sucatalog"
   ```

8. Quit Terminal and restart the installation.

[Reference & More Details](https://mrmacintosh.com/how-to-fix-the-recovery-server-could-not-be-contacted-error-high-sierra-recovery-is-still-online-but-broken/)

### ❌ Problem for GPU Passthrough

If you see an Apple logo and the bar doesn’t move on your external display, you need to disable “above 4g decoding” in the motherboard’s BIOS.

In some environments it is necessary to segment the IOMMU Groups to be able to pass the GPU to the VM.

1. Add the content `pcie_acs_override=downstream,multifunction pci=nommconf` in the file `/etc/default/grub` at the end of the line `GRUB_CMDLINE_LINUX_DEFAULT`;
2. After changing the grub file, run the command `update-grub` and reboot your PVE.

---

## 🎥 Demonstration (in Portuguese)

📽️ [Watch on YouTube](https://youtu.be/dil6iRWiun0)  
*(Enable auto-translate captions for English subtitles!)*

---

## 🎖 Credits

- **OpenCore/Acidanthera Team** - Open-source bootloader
- **Corpnewt** - Tools (ProperTree, GenSMBIOS, etc.)
- **Apple** - macOS
- **Proxmox** - Fantastic virtualization platform & documentation

---

## 🌎 Join Our Community - Universo Hackintosh Discord

💬 [**Join Here!**](https://discord.universohackintosh.com.br)

