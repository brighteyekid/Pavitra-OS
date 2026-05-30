#!/usr/bin/env bash
# =============================================================================
# build-base.sh — Pavitra OS Base System Construction
# Phase 2: Configure and kick off live-build for the Debian base filesystem
# =============================================================================
set -e
set -x

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/pavitra-build"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()  { echo -e "${CYAN}[build-base]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[build-base]${NC} $1"; }
log_error() { echo -e "${RED}[build-base]${NC} $1"; }

# =============================================================================
# 1. Pre-flight checks
# =============================================================================
check_prereqs() {
    log_info "Checking prerequisites..."

    [ "$EUID" -eq 0 ] || { log_error "Must run as root."; exit 1; }
    command -v lb &>/dev/null || { log_error "live-build (lb) not found. Run setup-build-env.sh first."; exit 1; }

    # Check RAM for Darling build
    TOTAL_RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
    if [ "$TOTAL_RAM_GB" -lt 8 ]; then
        log_info "WARNING: Only ${TOTAL_RAM_GB} GB RAM. Darling build may fail."
        log_info "To skip Darling, remove darling-setup.hook.chroot before building."
    fi

    # Check disk space (warn only — 20 GB recommended but not enforced)
    AVAIL_GB=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {gsub("G",""); print $4}')
    if [ "$AVAIL_GB" -lt 20 ]; then
        log_info "WARNING: Only ${AVAIL_GB} GB free. 20 GB recommended. Proceeding anyway."
    fi

    log_ok "Prerequisites passed."
}

# =============================================================================
# 2. Set up live-build directory and run lb config
# =============================================================================
configure_livebuild() {
    log_info "Configuring live-build in $BUILD_DIR ..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Ubuntu's live-build reads LB_PARENT_MIRROR_CHROOT_SECURITY to decide which
    # security mirror to write into the chroot sources.list. Export it before lb config.
    export LB_PARENT_MIRROR_CHROOT_SECURITY="http://security.debian.org/debian-security"
    export LB_PARENT_MIRROR_BINARY_SECURITY="http://security.debian.org/debian-security"
    export LB_PARENT_MIRROR_CHROOT="http://deb.debian.org/debian"
    export LB_PARENT_MIRROR_BINARY="http://deb.debian.org/debian"
    export LB_PARENT_ARCHIVE_AREAS="main contrib non-free non-free-firmware"

    lb config \
        --architecture amd64 \
        --distribution bookworm \
        --debian-installer none \
        --bootloader grub-efi \
        --binary-images iso-hybrid \
        --iso-volume "Pavitra OS 1.0" \
        --iso-publisher "Pavitra OS Project" \
        --iso-application "Pavitra OS" \
        --memtest none \
        --apt-recommends true \
        --archive-areas "main contrib non-free non-free-firmware" \
        --mirror-bootstrap "http://deb.debian.org/debian" \
        --mirror-binary "http://deb.debian.org/debian" \
        --security true \
        --linux-packages "linux-image linux-headers" \
        --linux-flavours "amd64" \
        --initramfs live-boot \
        --compression xz

    log_ok "live-build configured."

    # === ROOT CAUSE FIX: config/bootstrap ===
    # Ubuntu's live-build writes LB_PARENT_MIRROR_CHROOT_SECURITY and
    # LB_MIRROR_CHROOT_SECURITY pointing to security.ubuntu.com.
    # lb_chroot_archives reads config/bootstrap at runtime — fix them here.
    BOOTSTRAP_CFG="$BUILD_DIR/config/bootstrap"
    if [ -f "$BOOTSTRAP_CFG" ]; then
        sed -i \
            's|LB_PARENT_MIRROR_CHROOT_SECURITY=.*|LB_PARENT_MIRROR_CHROOT_SECURITY="http://security.debian.org/debian-security"|' \
            "$BOOTSTRAP_CFG"
        sed -i \
            's|LB_MIRROR_CHROOT_SECURITY=.*|LB_MIRROR_CHROOT_SECURITY="http://security.debian.org/debian-security"|' \
            "$BOOTSTRAP_CFG"
        log_ok "config/bootstrap security mirrors patched to Debian."
    else
        log_info "WARNING: config/bootstrap not found."
    fi

    # === ROOT CAUSE FIX: config/common ===
    # Ubuntu live-build sets LB_MODE="ubuntu" which causes it to try installing
    # ubuntu-keyring, ubuntu-minimal, and other Ubuntu-only packages.
    # Also: defaults.sh hardcodes LB_KEYRING_PACKAGES="ubuntu-keyring".
    # Also: LB_INITSYSTEM defaults to "upstart" in ubuntu mode, making
    #   lb_chroot_live-packages try to install "live-config-upstart" which
    #   doesn't exist in Debian Bookworm. Must be "systemd".
    COMMON_CFG="$BUILD_DIR/config/common"
    if [ -f "$COMMON_CFG" ]; then
        sed -i 's|LB_MODE=.*|LB_MODE="debian"|' "$COMMON_CFG"
        log_ok "config/common LB_MODE patched to debian."

        # Fix init system: replace whatever is set with systemd
        if grep -q "LB_INITSYSTEM" "$COMMON_CFG"; then
            sed -i 's|LB_INITSYSTEM=.*|LB_INITSYSTEM="systemd"|' "$COMMON_CFG"
        else
            echo 'LB_INITSYSTEM="systemd"' >> "$COMMON_CFG"
        fi
        log_ok "config/common LB_INITSYSTEM patched to systemd."
    else
        log_info "WARNING: config/common not found."
    fi

    # === ROOT CAUSE FIX: config/chroot (keyring) ===
    # Ubuntu live-build writes config/chroot with:
    #   LB_KEYRING_PACKAGES="ubuntu-keyring"
    # lb_chroot_archives reads this and tries to apt-get install ubuntu-keyring
    # inside the Debian chroot — which doesn't exist. Fix: replace with the
    # correct Debian keyring package.
    CHROOT_CFG="$BUILD_DIR/config/chroot"
    if [ -f "$CHROOT_CFG" ]; then
        sed -i \
            's|LB_KEYRING_PACKAGES=.*|LB_KEYRING_PACKAGES="debian-archive-keyring"|' \
            "$CHROOT_CFG"
        log_ok "config/chroot LB_KEYRING_PACKAGES patched to debian-archive-keyring."
    else
        log_info "WARNING: config/chroot not found."
    fi

    # Fix volatile mirrors in config/bootstrap that still point at archive.ubuntu.com
    BOOTSTRAP_CFG2="$BUILD_DIR/config/bootstrap"
    if [ -f "$BOOTSTRAP_CFG2" ]; then
        sed -i \
            's|LB_MIRROR_CHROOT_VOLATILE="http://archive.ubuntu.com/ubuntu/"|LB_MIRROR_CHROOT_VOLATILE="http://deb.debian.org/debian"|' \
            "$BOOTSTRAP_CFG2"
        sed -i \
            's|LB_MIRROR_BINARY_VOLATILE="http://archive.ubuntu.com/ubuntu/"|LB_MIRROR_BINARY_VOLATILE="http://deb.debian.org/debian"|' \
            "$BOOTSTRAP_CFG2"
        log_ok "config/bootstrap volatile mirrors patched to deb.debian.org."
    fi

    # === ROOT CAUSE FIX: config/binary (debian-installer) ===
    # Ubuntu's live-build sets LB_DEBIAN_INSTALLER="none" in config/binary.
    # lb_binary_debian-installer only accepts "false" to skip the step —
    # "none" hits the wildcard case and causes: "flavour none not supported".
    BINARY_CFG="$BUILD_DIR/config/binary"
    if [ -f "$BINARY_CFG" ]; then
        sed -i 's|LB_DEBIAN_INSTALLER="none"|LB_DEBIAN_INSTALLER="false"|' "$BINARY_CFG"
        if ! grep -q "LB_DEBIAN_INSTALLER=" "$BINARY_CFG"; then
            echo 'LB_DEBIAN_INSTALLER="false"' >> "$BINARY_CFG"
        fi
        log_ok "config/binary LB_DEBIAN_INSTALLER patched to false (skip)."

        # === FIX: genisoimage has a 4GiB file size limit — our squashfs is ~4.5GiB.
        # Switch to iso-hybrid which triggers xorriso usage in newer live-build,
        # AND set iso application/volume labels.
        sed -i 's|LB_BINARY_IMAGE=.*|LB_BINARY_IMAGE="iso-hybrid"|' "$BINARY_CFG"
        if ! grep -q "LB_BINARY_IMAGE=" "$BINARY_CFG"; then
            echo 'LB_BINARY_IMAGE="iso-hybrid"' >> "$BINARY_CFG"
        fi
        log_ok "config/binary LB_BINARY_IMAGE patched to iso-hybrid."
    else
        log_info "WARNING: config/binary not found — will be created by lb config."
    fi
}

# =============================================================================
# 5b. Create the final ISO using grub-mkrescue (bypasses genisoimage 4GB limit)
#     Called after lb build completes the binary assembly stages.
#     grub-mkrescue creates a proper BIOS + UEFI dual-boot ISO with xorriso,
#     and correctly handles squashfs files larger than 4GiB.
# =============================================================================
create_iso() {
    log_info "Creating bootable ISO with grub-mkrescue..."
    BINARY_DIR="$BUILD_DIR/binary"
    ISO_OUT="$SCRIPT_DIR/pavitra-os-1.0.iso"

    if [ ! -d "$BINARY_DIR/live" ]; then
        log_info "ERROR: $BINARY_DIR/live not found — lb build may have failed."
        return 1
    fi

    # Ensure tools are present
    apt-get install -y xorriso grub-efi-amd64-bin grub-pc-bin 2>/dev/null || true

    # Create xorriso wrapper that injects -iso-level 3 into the mkisofs call.
    # grub-mkrescue respects the XORRISO env var and our squashfs is >4GiB.
    tee /usr/local/bin/xorriso-large << 'WRAPPER_EOF'
#!/bin/bash
args=()
prev=""
for arg in "$@"; do
    if [ "$prev" = "-as" ] && [ "$arg" = "mkisofs" ]; then
        args+=("$arg" "-iso-level" "3")
    else
        args+=("$arg")
    fi
    prev="$arg"
done
exec /usr/bin/xorriso "${args[@]}"
WRAPPER_EOF
    chmod +x /usr/local/bin/xorriso-large

    # Copy GRUB config into the binary tree
    mkdir -p "$BINARY_DIR/boot/grub"
    if [ -f "$BUILD_DIR/config/includes.binary/boot/grub/grub.cfg" ]; then
        cp "$BUILD_DIR/config/includes.binary/boot/grub/grub.cfg" \
           "$BINARY_DIR/boot/grub/grub.cfg"
        log_ok "GRUB config copied to binary/boot/grub/"
    fi

    # Build the ISO (no extra flags after -- : they go to xorriso native mode, not mkisofs)
    XORRISO=/usr/local/bin/xorriso-large grub-mkrescue \
        --output="$ISO_OUT" \
        "$BINARY_DIR" \
        2>&1

    if [ -f "$ISO_OUT" ]; then
        ISO_SIZE=$(du -sh "$ISO_OUT" | cut -f1)
        log_ok "ISO created: $ISO_OUT ($ISO_SIZE)"
    else
        log_info "ERROR: ISO not created. Check grub-mkrescue output above."
        return 1
    fi
}


# =============================================================================
# 3. Inject a clean Debian sources.list into config/archives/
#    Ubuntu's live-build generates a sources.list that mixes Ubuntu security
#    mirrors with Debian codenames (bookworm), causing 404 errors.
#    Placing our own .list file in config/archives/ overrides that.
# =============================================================================
inject_debian_sources() {
    log_info "Injecting Debian sources and apt error-mode fix..."
    mkdir -p "$BUILD_DIR/config/archives"
    mkdir -p "$BUILD_DIR/config/apt/apt.conf.d"
    mkdir -p "$BUILD_DIR/auto"

    # Layer 1: archives/*.list.chroot → placed in chroot/etc/apt/sources.list.d/
    cat > "$BUILD_DIR/config/archives/debian.list.chroot" << 'SOURCES_EOF'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
SOURCES_EOF

    cat > "$BUILD_DIR/config/archives/debian.list.binary" << 'SOURCES_EOF'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
SOURCES_EOF

    # Layer 2a: config/apt/apt.conf — lb_chroot_apt copies this file into the
    # chroot BEFORE lb_chroot_archives runs apt-get update.
    # APT::Update::Error-Mode "any" makes the Ubuntu security mirror 404 non-fatal.
    # We include Install-Recommends because providing this file means lb won't
    # generate its own apt.conf, so we carry all required settings here.
    cat > "$BUILD_DIR/config/apt/apt.conf" << 'APT_EOF'
APT::Install-Recommends "true";
APT::Update::Error-Mode "any";
APT_EOF

    # Layer 2b: apt.conf.d with .conf extension — Ubuntu live-build globs *.conf
    cat > "$BUILD_DIR/config/apt/apt.conf.d/99-pavitra.conf" << 'APT_EOF'
APT::Update::Error-Mode "any";
APT_EOF

    # Layer 3: auto/build — wraps lb build and patches the host's lb_chroot_archives
    # script to sed out security.ubuntu.com from sources.list right after it is
    # written, before apt-get update runs. This is the definitive safety net.
    cat > "$BUILD_DIR/auto/build" << 'AUTO_EOF'
#!/bin/bash
# auto/build for Pavitra OS
# Removes any broken MARKER previously inserted into lb_chroot_archives,
# then uses a background watcher to continuously strip security.ubuntu.com
# from the chroot's sources.list before apt-get update sees it.

CHROOT_ARCHIVES=/usr/lib/live/build/lb_chroot_archives
MARKER="PAVITRA_UBUNTU_SEC_PATCHED"

# 1. Remove any previously (broken) inserted lines from lb_chroot_archives
if grep -q "$MARKER" "$CHROOT_ARCHIVES" 2>/dev/null; then
    echo "P: Pavitra — removing old broken patch from lb_chroot_archives..."
    sed -i "/$MARKER/d" "$CHROOT_ARCHIVES" 2>/dev/null || true
fi

# 2. Start a background watcher that removes security.ubuntu.com from
#    chroot/etc/apt/sources.list every 100ms while lb build runs.
#    This is the definitive fix: the bad line is deleted before apt-get update.
SRCLIST="$(pwd)/chroot/etc/apt/sources.list"
(
    while true; do
        if [ -f "$SRCLIST" ] && grep -q "security\.ubuntu\.com" "$SRCLIST" 2>/dev/null; then
            sed -i '/security\.ubuntu\.com/d' "$SRCLIST" 2>/dev/null || true
        fi
        sleep 0.1
    done
) &
WATCHER_PID=$!

# Ensure watcher is killed when this script exits (for any reason)
trap "kill $WATCHER_PID 2>/dev/null || true" EXIT INT TERM

echo "P: Pavitra — sources.list watcher started (PID $WATCHER_PID)"

# 3. Patch lb_chroot_archives to use bookworm-security instead of bookworm/updates
# Ubuntu's lb_chroot_archives uses ${LB_PARENT_DISTRIBUTION}/updates for the
# security suite (Ubuntu-era format). Debian Bookworm uses bookworm-security.
# We sed the relevant lines — only the security mirror echo lines, not the
# volatile/updates mirror lines which correctly use ${distribution}-updates.
CHROOT_ARCHIVES=/usr/lib/live/build/lb_chroot_archives
SEC_MARKER="PAVITRA_SEC_SUITE_PATCHED"
if [ -f "$CHROOT_ARCHIVES" ] && ! grep -q "$SEC_MARKER" "$CHROOT_ARCHIVES"; then
    echo "P: Pavitra — patching lb_chroot_archives: /updates → -security suite..."
    # The security mirror lines contain both the mirror URL and /updates suite.
    # Replace the suite suffix on lines that reference SECURITY mirrors.
    sed -i "s|\${LB_PARENT_DISTRIBUTION}/updates \${LB_PARENT_ARCHIVE_AREAS}|\${LB_PARENT_DISTRIBUTION}-security \${LB_PARENT_ARCHIVE_AREAS} # $SEC_MARKER|g" \
        "$CHROOT_ARCHIVES" 2>/dev/null || true
    sed -i "s|\${_DISTRIBUTION}/updates \${LB_ARCHIVE_AREAS}|\${_DISTRIBUTION}-security \${LB_ARCHIVE_AREAS} # $SEC_MARKER|g" \
        "$CHROOT_ARCHIVES" 2>/dev/null || true
    echo "P: Pavitra — lb_chroot_archives patched."
fi

# 4. Run the actual lb build (noauto prevents recursive auto/build calls)
lb build noauto "$@"
EXIT_CODE=$?

kill $WATCHER_PID 2>/dev/null || true
exit $EXIT_CODE
AUTO_EOF
    chmod +x "$BUILD_DIR/auto/build"

    log_ok "Sources fix applied: apt.conf + apt.conf.d/99-pavitra.conf + auto/build patcher."
}

# =============================================================================
# 3. Set up GRUB configuration
# =============================================================================
configure_grub() {
    log_info "Writing GRUB boot menu configuration..."
    mkdir -p "$BUILD_DIR/config/includes.binary/boot/grub"

    cat > "$BUILD_DIR/config/includes.binary/boot/grub/grub.cfg" << 'GRUBCFG'
# =============================================================================
# Pavitra OS GRUB2 Boot Menu
# =============================================================================
set default=0
set timeout=5
set timeout_style=menu

# Load theme
insmod gfxterm
insmod vbe
terminal_output gfxterm
set gfxmode=auto

# Theme path (inside ISO)
set theme=/boot/grub/themes/pavitra/theme.txt
export theme

# --- Menu Entries ---

menuentry "Boot Pavitra OS" --class pavitra --class gnu-linux {
    linux   /live/vmlinuz boot=live quiet splash
    initrd  /live/initrd.img
}

menuentry "Boot Pavitra OS (Safe Mode — nomodeset)" --class pavitra {
    linux   /live/vmlinuz boot=live nomodeset quiet splash
    initrd  /live/initrd.img
}

menuentry "Check Disk for Defects" {
    linux   /live/vmlinuz boot=live integrity-check quiet
    initrd  /live/initrd.img
}

menuentry "Reboot" {
    reboot
}

menuentry "Power Off" {
    halt
}
GRUBCFG

    log_ok "GRUB configuration written."
}

# =============================================================================
# 4. Ensure all hook scripts are executable (live-build silently ignores them if not)
# =============================================================================
mark_hooks_executable() {
    log_info "Making hook scripts executable..."
    HOOKS_DIR="$BUILD_DIR/config/hooks"
    if [ -d "$HOOKS_DIR" ]; then
        chmod +x "$HOOKS_DIR"/*.hook.chroot 2>/dev/null || true
        log_ok "Hooks marked executable."
    else
        log_info "No hooks directory found — skipping."
    fi
}

# =============================================================================
# 5. Run the actual live-build build
# =============================================================================
run_build() {
    log_info "Starting live-build (this takes 30-90 minutes)..."

    # Inject real logo + wallpaper assets into includes.chroot so the
    # desktop-setup hook finds them at /usr/share/pavitra-os/ inside the chroot.
    ASSETS_DIR="$SCRIPT_DIR/assets"
    CHROOT_ASSETS="$BUILD_DIR/config/includes.chroot/usr/share/pavitra-os"
    CHROOT_PIXMAPS="$BUILD_DIR/config/includes.chroot/usr/share/pixmaps"
    mkdir -p "$CHROOT_ASSETS" "$CHROOT_PIXMAPS" 2>/dev/null || true
    if [ -f "$ASSETS_DIR/wallpaper.png" ]; then
        cp "$ASSETS_DIR/wallpaper.png" "$CHROOT_ASSETS/wallpaper.png"
        log_ok "Bundled wallpaper injected into includes.chroot."
    fi
    if [ -f "$ASSETS_DIR/logo.png" ]; then
        cp "$ASSETS_DIR/logo.png" "$CHROOT_ASSETS/logo.png"
        cp "$ASSETS_DIR/logo.png" "$CHROOT_PIXMAPS/pavitra-os.png"
        log_ok "Bundled logo injected into includes.chroot."
    fi

    cd "$BUILD_DIR"
    lb build 2>&1
    log_ok "live-build completed."
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    log_info "=== Pavitra OS — Base System Build ==="
    check_prereqs
    configure_livebuild
    inject_debian_sources
    configure_grub
    mark_hooks_executable
    run_build
    log_ok "live-build chroot and binary stages complete."
    create_iso
    log_ok "Pavitra OS build finished! ISO: $SCRIPT_DIR/pavitra-os-1.0.iso"
}

main "$@"
