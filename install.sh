#!/bin/bash

#########################################################################################################################
#
# Script: install
# Purpose: Install OSX-PROXMOX
# Source: https://luchina.com.br
#
#########################################################################################################################

# Exit on any error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
	echo "This script must be run as root."
	exit 1
fi

# Define log file
LOG_FILE="/root/install-osx-proxmox.log"

# Function to log messages
log_message() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function to check command success
check_status() {
    if [ $? -ne 0 ]; then
        log_message "Error: $1"
        exit 1
    fi
}

# Paths and artefacts managed by setup
SCRIPT_ROOT="/root/OSX-PROXMOX"
LOG_DIR="${SCRIPT_ROOT}/logs"
OPENCORE_ISO="LongQT-OpenCore-v0.5.iso"

# Discover ISO directory from setup logs
detect_iso_dir() {
    local iso_dir=""
    local log_file
    for log_file in \
        "${LOG_DIR}/iso-storage-detection.log" \
        "${LOG_DIR}/main.log"; do
        if [ -f "$log_file" ]; then
            iso_dir=$(grep -E "ISODIR set to" "$log_file" | tail -1 | sed -E 's/.*ISODIR set to:?[[:space:]]+//')
            [ -n "$iso_dir" ] && break
        fi
    done
    echo "$iso_dir"
}

# Ensure OpenCore and at least one recovery ISO exist before declaring success
ensure_boot_media_ready() {
    local iso_dir
    iso_dir=$(detect_iso_dir)

    if [ -z "$iso_dir" ]; then
        log_message "Unable to determine ISO directory from setup logs. Re-run '/root/OSX-PROXMOX/setup' and finish ISO storage selection."
        return 1
    fi

    if [ ! -d "$iso_dir" ]; then
        log_message "ISO directory '$iso_dir' does not exist. Verify the storage path selected in setup."
        return 1
    fi

    if [ ! -f "${iso_dir}/${OPENCORE_ISO}" ]; then
        log_message "Missing ${OPENCORE_ISO} in '$iso_dir'. Run setup option '201 - Update Opencore ISO file' and retry."
        return 1
    fi

    if ! compgen -G "${iso_dir}/recovery-*.iso" >/dev/null 2>&1; then
        log_message "No recovery ISO found in '$iso_dir'. Run setup option '101/102 - Download & Create Recovery Image' for your macOS version."
        return 1
    fi

    log_message "Boot media verified in '$iso_dir'."
    return 0
}

# Clear screen
clear

# Clean up existing files
log_message "Cleaning up existing files..."
[ -d "$SCRIPT_ROOT" ] && rm -rf "$SCRIPT_ROOT"
[ -f "/etc/apt/sources.list.d/pve-enterprise.list" ] && rm -f "/etc/apt/sources.list.d/pve-enterprise.list"
[ -f "/etc/apt/sources.list.d/ceph.list" ] && rm -f "/etc/apt/sources.list.d/ceph.list"
[ -f "/etc/apt/sources.list.d/pve-enterprise.sources" ] && rm -f "/etc/apt/sources.list.d/pve-enterprise.sources"
[ -f "/etc/apt/sources.list.d/ceph.sources" ] && rm -f "/etc/apt/sources.list.d/ceph.sources"

log_message "Preparing to install OSX-PROXMOX..."

# Update package lists
log_message "Updating package lists..."
apt-get update >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    log_message "Initial apt-get update failed. Attempting to fix sources..."
    
    # Use main Debian mirror instead of country-specific
    sed -i 's/ftp\.[a-z]\{2\}\.debian\.org/ftp.debian.org/g' /etc/apt/sources.list
    
    log_message "Retrying apt-get update..."
    apt-get update >> "$LOG_FILE" 2>&1
    check_status "Failed to update package lists after source modification"
fi

# Install git
log_message "Installing git..."
apt-get install -y git >> "$LOG_FILE" 2>&1
check_status "Failed to install git"

# Clone repository
log_message "Cloning OSX-PROXMOX repository..."
git clone --recurse-submodules https://github.com/braffour/OSX-PROXMOX.git --branch cursor/analyse-the-code-repository-gpt-5.1-codex-high-3378 "$SCRIPT_ROOT" >> "$LOG_FILE" 2>&1
check_status "Failed to clone repository"

# Ensure directory exists and setup is executable
if [ -f "${SCRIPT_ROOT}/setup" ]; then
    chmod +x "${SCRIPT_ROOT}/setup"
    log_message "Running setup script..."
    "${SCRIPT_ROOT}/setup" 2>&1 | tee -a "$LOG_FILE"
    check_status "Failed to run setup script"
else
    log_message "Error: Setup script not found in /root/OSX-PROXMOX"
    exit 1
fi

# Verify boot media artefacts before finishing
if ! ensure_boot_media_ready; then
    log_message "Setup exited without provisioning boot media. Resolve the messages above and rerun this installer."
    exit 1
fi

log_message "Installation completed successfully"
