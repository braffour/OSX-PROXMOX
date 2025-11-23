# Westmere/Nehalem CPU Setup Guide - MacPro6,1 SMBIOS

**Reference EFI: LongQT OpenCore-ISO + MacPro6,1 SMBIOS**

This guide provides a comprehensive checklist for setting up macOS VMs on Proxmox using Westmere/Nehalem CPUs (e.g., Intel Xeon X5650) with LongQT's OpenCore ISO and MacPro6,1 SMBIOS configuration.

---

## 0. Reference URLs

### OpenCore-ISO (Base EFI/Boot ISO)
- **Repository:** https://github.com/LongQT-sea/OpenCore-ISO
- **Releases:** https://github.com/LongQT-sea/OpenCore-ISO/releases
  - Download: `LongQT-OpenCore-vX.Y.iso`

### OpenCore-ISO Documentation
- **README (Proxmox VM setup, CPU table, disk & NIC recommendations, post-install):**
  - https://github.com/LongQT-sea/OpenCore-ISO#readme
- **QEMU CPU Tuning Reference:**
  - https://github.com/LongQT-sea/qemu-cpu-guide

### Dortania Guides (Correctness + SMBIOS + Hardware Limits)
- **OpenCore Install Guide:** https://dortania.github.io/OpenCore-Install-Guide/
- **Hardware Limits (AVX2 requirement for macOS 13+):**
  - https://dortania.github.io/OpenCore-Install-Guide/macos-limits.html
- **macOS 12 Monterey Notes:**
  - https://dortania.github.io/OpenCore-Install-Guide/extras/monterey.html
- **SMBIOS Support Table (MacPro6,1 range):**
  - https://dortania.github.io/OpenCore-Install-Guide/extras/smbios-support.html
- **Nehalem / Westmere Intel HEDT Config:**
  - https://dortania.github.io/OpenCore-Install-Guide/config-HEDT/nehalem.html
- **iServices SMBIOS / ROM Guide:**
  - https://dortania.github.io/OpenCore-Install-Guide/extras/iservices.html

### Important Notes
- **AVX2 Requirement:** macOS 13+ (Ventura and newer) require AVX2 instruction set support
- **Westmere/Nehalem CPUs:** Do NOT have AVX2 support
- **Maximum macOS Version:** macOS 12 Monterey is the latest version supported on Westmere/Nehalem CPUs

---

## 1. Host Reality Check (Westmere/Nehalem Box)

### Verify CPU Model and Generation

On your **Proxmox host**, run:

```bash
# Check CPU model
lscpu | grep -i "Model name"

# Check CPU flags (verify SSE4.2 is present, AVX2 is NOT)
grep -m1 "^flags" /proc/cpuinfo | tr ' ' '\n' | grep -E "sse4_2|avx2"

# Expected output for Westmere:
# - Should have: sse4_2, ssse3, popcnt, aes, xsave
# - Should NOT have: avx2, fma

# Alternative check
grep -m1 -o 'sse4_2' /proc/cpuinfo || echo "no sse4.2"
grep -m1 -o 'avx2' /proc/cpuinfo || echo "no avx2"  # Should output "no avx2"
```

### Verify TSC (Timestamp Counter) - Required for macOS Monterey+

```bash
dmesg | grep -i -e tsc -e clocksource
```

**Expected Output (working host):**
```
clocksource: Switched to clocksource tsc
```

**Problematic Output (broken host):**
```
tsc: Marking TSC unstable due to check_tsc_sync_source failed
clocksource: Switched to clocksource hpet
```

If TSC is unstable, see troubleshooting section below.

### Verify CPU Family

```bash
lscpu | grep -i "CPU family"
```

- **Westmere:** Family 6, Model 44/47 (Xeon 5600 series, Core i7-9xx)
- **Nehalem:** Family 6, Model 26/46 (Xeon 5500 series, Core i7-8xx)

---

## 2. Proxmox Host Prerequisites Setup

### Install OSX-PROXMOX Script

```bash
curl -fsSL https://raw.githubusercontent.com/braffour/OSX-PROXMOX/refs/heads/main/install.sh | bash
```

The installer will:
- Detect your CPU generation automatically (Westmere/Nehalem will be identified)
- Configure GRUB with IOMMU settings
- Set up prerequisite packages

### Verify CPU Detection

After installation, when you run `/root/OSX-PROXMOX/setup`, you should see in the menu:
```
CPU Platform: INTEL (WESTMERE)
Note: Westmere/Nehalem CPU detected - Maximum macOS: Monterey (12)
```

---

## 3. Download OpenCore ISO (LongQT Reference)

### Automatic Download via Setup Menu

Run the setup script:
```bash
/root/OSX-PROXMOX/setup
```

Select option **201 - Update OpenCore ISO**

This will:
- Download `LongQT-OpenCore-v0.5.iso` (or latest version)
- Prompt you to configure SMBIOS (recommend MacPro6,1 for Westmere)
- Apply appropriate boot-args including `-nehalem_error_disable`

### Manual Verification

Verify the ISO is in your ISO storage:
```bash
ls -lh /path/to/iso/storage/template/iso/LongQT-OpenCore-v*.iso
```

---

## 4. Configure SMBIOS (MacPro6,1)

### Automatic Configuration (Recommended)

When the setup script detects Westmere/Nehalem CPU, it will:
- **Auto-suggest MacPro6,1** as the default SMBIOS
- Generate unique serial numbers via GenSMBIOS
- Save SMBIOS data to `${ISODIR}/.smbios.json`

### Manual Configuration via Setup Menu

1. Run `/root/OSX-PROXMOX/setup`
2. Select option **205 - Customize OpenCore config.plist**
3. When prompted for System Product Name, you should see:
   ```
   Enter System Product Name (press Enter to keep current): MacPro6,1
   ```
   - Press Enter to accept MacPro6,1 (recommended for Westmere)
   - Or enter a different SMBIOS if needed (manual override)

4. The script will:
   - Generate unique SMBIOS data (Serial, MLB, UUID, ROM)
   - Apply `-nehalem_error_disable` boot-arg automatically
   - Save configuration to OpenCore ISO

### Verify SMBIOS Configuration

After configuration, verify:
```bash
# Mount the OpenCore ISO
mount -o loop /path/to/LongQT-OpenCore-v*.iso /mnt/opencore

# Check config.plist (requires xmlstarlet)
xmlstarlet sel -t -v "//key[text()='SystemProductName']/following-sibling::*[1]" \
  /mnt/opencore/EFI/OC/config.plist

# Should output: MacPro6,1

# Check boot-args
xmlstarlet sel -t -v "//key[text()='boot-args']/following-sibling::*[1]" \
  /mnt/opencore/EFI/OC/config.plist

# Should contain: -nehalem_error_disable

umount /mnt/opencore
```

---

## 5. Download macOS Recovery Image (Monterey Maximum)

### Important: macOS Version Limitation

**Westmere/Nehalem CPUs support up to macOS 12 Monterey only.**

- ✅ **Supported:** macOS 10.13 through macOS 12 (Monterey)
- ❌ **NOT Supported:** macOS 13+ (Ventura, Sonoma, Sequoia) - Requires AVX2

### Download via Setup Menu

Run `/root/OSX-PROXMOX/setup` and select:
- **Option 5 - macOS Monterey - 12**

The setup script will:
- Download recovery image for Monterey
- Create `recovery-monterey.iso` in your ISO storage

### Verify Recovery Image

```bash
ls -lh /path/to/iso/storage/template/iso/recovery-monterey.iso
```

---

## 6. Create macOS VM

### Via Setup Menu (Recommended)

1. Run `/root/OSX-PROXMOX/setup`
2. Select **Option 5 - macOS Monterey - 12**
3. The script will:
   - Detect Westmere CPU and apply appropriate CPU args
   - Use Penryn-based CPU model (no AVX2)
   - Warn if you try to install Ventura+ (will allow override with confirmation)
   - Configure VM with recommended settings

### VM Configuration Applied Automatically

When Westmere/Nehalem is detected, the VM will use:

**CPU Arguments:**
```
-cpu Penryn,kvm=on,vendor=GenuineIntel,+kvm_pv_unhalt,+kvm_pv_eoi,+hypervisor,+invtsc,+ssse3,+sse4.2,+popcnt,+aes,+xsave,+xsaveopt
```

**Key Points:**
- Uses `Penryn` CPU model (Westmere-compatible)
- Includes: `+ssse3,+sse4.2,+popcnt,+aes` (Westmere has these)
- Excludes: `+avx2,+fma` (Westmere lacks these)

**Boot Arguments (in OpenCore config):**
- `-nehalem_error_disable` (automatically added for MacPro6,1)

---

## 7. Boot & Install macOS

### Start VM

1. In Proxmox web UI, start the VM
2. Boot from OpenCore ISO (should be default)
3. Select macOS Recovery from OpenCore boot menu

### Installation Steps

1. **macOS Recovery:**
   - Select your language
   - Open Disk Utility
   - Erase the disk (format as APFS)
   - Close Disk Utility

2. **Install macOS:**
   - Select "Install macOS Monterey"
   - Follow on-screen instructions
   - Installation will take 30-60 minutes

3. **Post-Install Setup:**
   - Configure macOS initial setup
   - Sign in to iCloud (if using valid SMBIOS)
   - Complete system setup

---

## 8. Post-Install Verification

### Verify CPU Compatibility

```bash
# In macOS terminal
sysctl -n machdep.cpu.brand_string

# Should show something like:
# Intel(R) Core(TM) i7-980X CPU @ 3.33GHz (Penryn-based)
```

### Verify macOS Version

```bash
sw_vers

# Should show:
# ProductName:    macOS
# ProductVersion: 12.x.x
# BuildVersion:   21xxx
```

### Verify SMBIOS

```bash
system_profiler SPHardwareDataType | grep -E "Model Name|Model Identifier|Serial Number"

# Should show:
# Model Identifier: MacPro6,1
# Serial Number: (your generated serial)
```

### Verify Boot Args

```bash
nvram boot-args

# Should contain: -nehalem_error_disable
```

---

## 9. Troubleshooting

### TSC Unstable Warning

**Problem:** `clocksource: Switched to clocksource hpet`

**Solution:**
1. Disable "ErP mode" and all C-state power-saving modes in BIOS
2. Power off machine completely (not reboot) and restart
3. If still unstable, try forcing TSC in GRUB:
   ```bash
   # Edit /etc/default/grub
   # Add to GRUB_CMDLINE_LINUX_DEFAULT:
   clocksource=tsc tsc=reliable
   
   # Update GRUB
   update-grub
   
   # Reboot
   reboot
   ```
   **Warning:** This may cause system instability. Use with caution.

4. Verify TSC is active:
   ```bash
   cat /sys/devices/system/clocksource/clocksource0/current_clocksource
   # Should output: tsc
   ```

### VM Crashes During Boot

**Symptoms:** Kernel panic or immediate crash

**Solutions:**
1. Verify CPU args exclude AVX2
2. Ensure `-nehalem_error_disable` is in boot-args
3. Check VM logs: `tail -f /var/log/pve/tasks/active`
4. Verify TSC stability (see above)

### Installation Fails with "Unsupported CPU" Error

**Problem:** macOS installer rejects the CPU

**Solution:**
1. Verify you're installing macOS 12 Monterey (not Ventura+)
2. Check CPU args match Westmere configuration
3. Ensure OpenCore config uses MacPro6,1 SMBIOS

### macOS Runs but Applications Crash

**Problem:** Applications requiring AVX2 crash

**Solution:**
1. This is expected behavior - some apps require AVX2
2. Use macOS 12 Monterey compatible applications only
3. Avoid apps that require macOS 13+ features

### Boot-args Not Applied

**Problem:** `-nehalem_error_disable` missing from boot-args

**Solution:**
1. Re-run OpenCore customization: Option 205
2. Verify MacPro6,1 SMBIOS is set
3. The script should auto-add the flag for MacPro6,1

### Recovery Server Could Not Be Contacted (High Sierra only)

**Problem:** High Sierra recovery download fails

**Solution:**
See main README.md troubleshooting section for High Sierra HTTP/HTTPS workaround.

---

## 10. Additional Resources

### CPU Compatibility Reference

| CPU Generation | AVX2 Support | Max macOS | Recommended SMBIOS |
|---------------|--------------|-----------|-------------------|
| Westmere      | ❌ No        | Monterey (12) | MacPro6,1      |
| Nehalem       | ❌ No        | Monterey (12) | MacPro6,1      |
| Haswell+      | ✅ Yes       | Latest    | iMacPro1,1     |

### Recommended VM Settings (Westmere)

- **CPU:** Penryn-based (automatically configured)
- **RAM:** 4GB minimum, 8GB+ recommended
- **Disk:** VirtIO SCSI (automatically configured)
- **Network:** vmxnet3 (automatically configured)
- **Machine:** q35 (automatically configured)

### SMBIOS Compatibility

MacPro6,1 is recommended because:
- Supports macOS 10.13 through macOS 12
- Compatible with Westmere/Nehalem CPUs
- Requires `-nehalem_error_disable` boot-arg (auto-applied)

---

## Summary Checklist

- [ ] Verified CPU is Westmere/Nehalem (no AVX2)
- [ ] Verified TSC stability (clocksource = tsc)
- [ ] Installed OSX-PROXMOX script
- [ ] CPU generation detected correctly (WESTMERE/NEHALEM)
- [ ] Downloaded LongQT OpenCore ISO
- [ ] Configured SMBIOS to MacPro6,1
- [ ] Generated unique serial numbers
- [ ] Verified `-nehalem_error_disable` in boot-args
- [ ] Downloaded macOS 12 Monterey recovery image
- [ ] Created VM with Westmere-optimized CPU args
- [ ] Successfully booted macOS Recovery
- [ ] Installed macOS Monterey
- [ ] Verified macOS version (12.x.x)
- [ ] Verified SMBIOS (MacPro6,1)
- [ ] Verified boot-args (contains -nehalem_error_disable)

---

**Last Updated:** Based on OSX-PROXMOX setup script v2025.07.23  
**OpenCore Version:** 1.0.4  
**Compatible macOS Versions:** 10.13 - 12 (Monterey maximum for Westmere)

