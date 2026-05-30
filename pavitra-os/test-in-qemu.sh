#!/usr/bin/env bash
# =============================================================================
# test-in-qemu.sh — Pavitra OS QEMU Test Script
# Phase 11: Boot the built ISO in a QEMU virtual machine for manual testing
# =============================================================================
set -e
set -x

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ISO="$SCRIPT_DIR/pavitra-os-1.0.iso"
DISK_IMAGE="$SCRIPT_DIR/pavitra-test.qcow2"
DISK_SIZE="20G"
RAM_MB=4096
QEMU_DISPLAY="sdl"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${CYAN}[test-qemu]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[test-qemu]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[test-qemu]${NC} $1"; }
log_error() { echo -e "${RED}[test-qemu]${NC} $1"; }

# =============================================================================
# 1. Check if ISO exists
# =============================================================================
if [ ! -f "$ISO" ]; then
    log_error "ISO not found: $ISO"
    log_error "Build it first: sudo bash build-iso.sh"
    exit 1
fi
log_ok "Found ISO: $ISO"

# =============================================================================
# 2. Check for QEMU; install if missing
# =============================================================================
install_qemu() {
    log_info "Checking for QEMU..."
    if ! command -v qemu-system-x86_64 &>/dev/null; then
        log_warn "QEMU not found. Installing..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get install -y qemu-system-x86 qemu-utils ovmf
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y qemu-system-x86 qemu-img edk2-ovmf
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm qemu ovmf
        else
            log_error "Cannot auto-install QEMU on this system. Please install it manually."
            exit 1
        fi
    fi
    log_ok "QEMU found: $(command -v qemu-system-x86_64)"
}

# =============================================================================
# 3. Check for KVM acceleration
# =============================================================================
check_kvm() {
    KVM_FLAGS=""
    if [ -e /dev/kvm ] && [ -r /dev/kvm ]; then
        log_ok "KVM is available — using hardware acceleration."
        KVM_FLAGS="-enable-kvm -cpu host"
    else
        log_warn "KVM not available. Running in software emulation (slower)."
        log_warn "To enable KVM: sudo modprobe kvm_intel  (or kvm_amd)"
        KVM_FLAGS="-cpu qemu64"
    fi
}

# =============================================================================
# 4. Create the virtual disk if it doesn't exist
# =============================================================================
create_disk() {
    if [ -f "$DISK_IMAGE" ]; then
        log_info "Virtual disk already exists: $DISK_IMAGE"
    else
        log_info "Creating 20 GB virtual disk: $DISK_IMAGE ..."
        qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"
        log_ok "Virtual disk created."
    fi
}

# =============================================================================
# 5. Check for OVMF (UEFI firmware for EFI boot testing)
# =============================================================================
find_ovmf() {
    OVMF_FLAGS=""
    OVMF_PATHS=(
        "/usr/share/ovmf/OVMF.fd"
        "/usr/share/OVMF/OVMF_CODE.fd"
        "/usr/share/edk2/ovmf/OVMF_CODE.fd"
    )
    for f in "${OVMF_PATHS[@]}"; do
        if [ -f "$f" ]; then
            log_ok "Found OVMF firmware: $f (EFI boot enabled)"
            OVMF_FLAGS="-bios $f"
            break
        fi
    done
    if [ -z "$OVMF_FLAGS" ]; then
        log_warn "OVMF not found — will use legacy BIOS boot."
    fi
}

# =============================================================================
# 6. Print manual testing checklist
# =============================================================================
print_test_instructions() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         PAVITRA OS — QEMU MANUAL TEST CHECKLIST        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Please verify the following manually in the QEMU window:${NC}"
    echo ""
    echo "  1. GRUB BOOT MENU"
    echo "     ✓ The GRUB menu appears with dark background"
    echo "     ✓ Five entries are visible: Boot, Safe Mode, Check Disk, Reboot, Power Off"
    echo "     ✓ The 5-second countdown timer counts down correctly"
    echo "     ✓ Arrow keys select entries, Enter boots the selected entry"
    echo ""
    echo "  2. DESKTOP ENVIRONMENT"
    echo "     ✓ Desktop loads to XFCE4 (not a TTY)"
    echo "     ✓ LightDM login screen shows 'Pavitra OS' branding"
    echo "     ✓ Log in as user: pavitra  /  password: pavitra"
    echo "     ✓ Custom wallpaper (dark circuit board with PAVITRA OS text) is shown"
    echo "     ✓ Top panel: App menu, window list, clock"
    echo "     ✓ Bottom dock: File Manager, Terminal, Firefox, Settings, App Runner, Software"
    echo "     ✓ GTK theme is Greybird-dark"
    echo "     ✓ Icon theme is Papirus-Dark"
    echo ""
    echo "  3. WELCOME SCREEN"
    echo "     ✓ Pavitra Welcome window appears automatically on first login"
    echo "     ✓ All 6 app format cards are shown"
    echo "     ✓ macOS experimental warning is displayed"
    echo "     ✓ 'Get Started' button closes the window"
    echo "     ✓ 'Don't show again' checkbox works (re-login to verify)"
    echo ""
    echo "  4. WINDOWS APP COMPATIBILITY (Wine)"
    echo "     ✓ Open terminal and run: wine notepad"
    echo "       (notepad.exe is built into Wine's prefix)"
    echo "     ✓ Windows Notepad opens in a window"
    echo "     ✓ Run: run-windows-app ~/.wine/drive_c/windows/notepad.exe"
    echo "     ✓ Create a test .exe: download any portable Windows app and try opening"
    echo ""
    echo "  5. DEBIAN PACKAGE INSTALL"
    echo "     ✓ Download a .deb file (e.g., htop or any simple package)"
    echo "     ✓ Double-click it in Thunar — gdebi-gtk should open"
    echo "     ✓ Or run: install-deb /path/to/package.deb"
    echo "     ✓ Package installs successfully"
    echo ""
    echo "  6. APPIMAGE SUPPORT"
    echo "     ✓ Download a test AppImage (e.g., from https://appimage.github.io/)"
    echo "     ✓ Run: appimage-run /path/to/App.AppImage"
    echo "     ✓ App launches without errors"
    echo ""
    echo "  7. FIREFOX"
    echo "     ✓ Click Firefox in the dock"
    echo "     ✓ Firefox opens (may take 30s on first launch)"
    echo "     ✓ Navigate to https://debian.org — page loads"
    echo ""
    echo "  8. AUDIO"
    echo "     ✓ Open pavucontrol from the app menu"
    echo "     ✓ Sound card is detected"
    echo "     ✓ Play a video in VLC — audio plays through speakers"
    echo ""
    echo -e "${GREEN}Tip:${NC} Press Ctrl+Alt+G to release mouse from QEMU window"
    echo -e "${GREEN}Tip:${NC} Press Ctrl+Alt+F to toggle fullscreen"
    echo ""
}

# =============================================================================
# 7. Launch QEMU
# =============================================================================
launch_qemu() {
    log_info "Launching QEMU with ${RAM_MB} MB RAM..."
    log_info "ISO: $ISO"
    log_info "Disk: $DISK_IMAGE"
    echo ""

    # Build QEMU command
    QEMU_CMD=(
        qemu-system-x86_64
        $KVM_FLAGS
        -m ${RAM_MB}M
        -smp 2
        -drive "file=$DISK_IMAGE,format=qcow2,if=virtio"
        -cdrom "$ISO"
        -boot d
        -vga virtio
        -display ${QEMU_DISPLAY}
        -device virtio-net-pci,netdev=net0
        -netdev user,id=net0
        -device intel-hda
        -device hda-duplex
        $OVMF_FLAGS
    )

    log_info "Running: ${QEMU_CMD[*]}"
    "${QEMU_CMD[@]}"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    install_qemu
    check_kvm
    create_disk
    find_ovmf
    print_test_instructions
    launch_qemu
}

main "$@"
