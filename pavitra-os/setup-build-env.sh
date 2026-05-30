#!/usr/bin/env bash
# =============================================================================
# setup-build-env.sh — Pavitra OS Build Environment Setup
# Phase 1: Install all required host tools for building the ISO
# =============================================================================
set -e
set -x

# Color codes for readable output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# 1. Detect host OS — must be Debian/Ubuntu-based for apt to be available
# =============================================================================
detect_os() {
    log_info "Detecting host operating system..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        HOST_OS_ID="$ID"
        HOST_OS_LIKE="${ID_LIKE:-}"
        log_info "Host OS: $PRETTY_NAME"
    else
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    # Check for Debian or Ubuntu lineage
    if [[ "$HOST_OS_ID" != "debian" && "$HOST_OS_ID" != "ubuntu" && \
          "$HOST_OS_LIKE" != *"debian"* && "$HOST_OS_LIKE" != *"ubuntu"* ]]; then
        log_error "Pavitra OS must be built on a Debian or Ubuntu host system."
        log_error "Detected: $HOST_OS_ID (like: $HOST_OS_LIKE)"
        exit 1
    fi

    log_ok "Host OS is Debian-compatible. Proceeding."
}

# =============================================================================
# 2. Check for root privileges
# =============================================================================
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (or with sudo)."
        log_error "Usage: sudo bash setup-build-env.sh"
        exit 1
    fi
    log_ok "Running as root."
}

# =============================================================================
# 3. Check disk space — build requires at least 20 GB free
# =============================================================================
check_disk_space() {
    log_info "Checking available disk space..."
    AVAILABLE_KB=$(df -k . | awk 'NR==2 {print $4}')
    AVAILABLE_GB=$((AVAILABLE_KB / 1024 / 1024))
    log_info "Available disk space: ${AVAILABLE_GB} GB"

    if [ "$AVAILABLE_GB" -lt 20 ]; then
        log_warn "Low disk space: only ${AVAILABLE_GB} GB available (20 GB recommended)."
        log_warn "Proceeding anyway — build may fail if disk fills up during compilation."
        log_warn "To free space, remove the Darling hook or clear old build artifacts."
    else
        log_ok "Disk space check passed (${AVAILABLE_GB} GB available)."
    fi
}

# =============================================================================
# 4. Check RAM — Darling build requires at least 8 GB RAM
# =============================================================================
check_ram() {
    log_info "Checking available RAM..."
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
    log_info "Total RAM: ${TOTAL_RAM_GB} GB"

    if [ "$TOTAL_RAM_GB" -lt 8 ]; then
        log_warn "WARNING: Less than 8 GB RAM detected (${TOTAL_RAM_GB} GB)."
        log_warn "The Darling (macOS compatibility) build step may fail or be very slow."
        log_warn "Proceeding anyway — you may disable the Darling hook to skip macOS support."
    else
        log_ok "RAM check passed (${TOTAL_RAM_GB} GB)."
    fi
}

# =============================================================================
# 5. List of required tools to install
# =============================================================================
REQUIRED_PACKAGES=(
    live-build
    debootstrap
    squashfs-tools
    xorriso
    grub-pc-bin
    grub-efi-amd64-bin
    mtools
    dosfstools
    git
    curl
    wget
    python3
    build-essential
    isolinux
    syslinux-utils
    apt-transport-https
    ca-certificates
    gnupg
    lsb-release
)

# =============================================================================
# 6. Update apt cache and install missing packages
# =============================================================================
install_packages() {
    log_info "Updating apt package cache..."
    if ! apt-get update -y; then
        log_error "apt-get update failed. Check your internet connection and apt sources."
        exit 1
    fi
    log_ok "apt cache updated."

    log_info "Checking and installing required packages..."
    FAILED_PACKAGES=()

    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            log_ok "  [already installed] $pkg"
        else
            log_info "  Installing: $pkg ..."
            if apt-get install -y "$pkg"; then
                log_ok "  [installed] $pkg"
            else
                log_error "  [FAILED] Could not install: $pkg"
                FAILED_PACKAGES+=("$pkg")
            fi
        fi
    done

    # Report any failures
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        log_error "The following packages could not be installed:"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            log_error "  - $pkg"
        done
        log_error "Please resolve these issues and re-run setup-build-env.sh"
        exit 1
    fi

    log_ok "All required packages are installed."
}

# =============================================================================
# 7. Verify key binaries are actually executable after install
# =============================================================================
verify_tools() {
    log_info "Verifying tool binaries are accessible..."
    REQUIRED_BINS=(
        lb
        debootstrap
        mksquashfs
        xorriso
        grub-mkimage
        git
        curl
        wget
        python3
        gcc
    )

    for bin in "${REQUIRED_BINS[@]}"; do
        if command -v "$bin" &>/dev/null; then
            log_ok "  Found: $bin ($(command -v "$bin"))"
        else
            log_error "  MISSING binary: $bin — install of package may have failed."
            exit 1
        fi
    done
    log_ok "All tool binaries verified."
}

# =============================================================================
# 8. Print summary
# =============================================================================
print_summary() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Pavitra OS build environment is ready!   ${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "Next step: run  ${CYAN}sudo bash build-iso.sh${NC}"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    echo ""
    echo -e "${CYAN}====================================${NC}"
    echo -e "${CYAN}  Pavitra OS — Build Env Setup     ${NC}"
    echo -e "${CYAN}====================================${NC}"
    echo ""

    detect_os
    check_root
    check_disk_space
    check_ram
    install_packages
    verify_tools
    print_summary
}

main "$@"
