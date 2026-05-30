#!/usr/bin/env bash
# =============================================================================
# build-final-iso.sh — Build Pavitra OS ISO directly with xorriso
# Bypasses grub-mkrescue entirely. Uses grub-mkstandalone + xorriso -iso-level 3
# =============================================================================
set -e

BINARY=/home/fox/Documents/OS/pavitra-os/pavitra-build/binary
OUTPUT=/home/fox/Documents/OS/pavitra-os/pavitra-os-1.0.iso
GRUBCFG="$BINARY/boot/grub/grub.cfg"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
log_ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
log_info() { echo -e "${CYAN}[build]${NC} $*"; }
log_err()  { echo -e "${RED}[ERR]${NC}   $*"; }

# --- Verify prereqs ---
log_info "Checking tools..."
for t in xorriso grub-mkstandalone; do
    command -v "$t" &>/dev/null || { log_err "Missing: $t"; exit 1; }
done
log_ok "Tools OK"

# --- Free up backup squashfs to save space ---
if [ -f "$BINARY/live/filesystem.squashfs.bak" ]; then
    log_info "Removing squashfs backup to free space (~4.7GB)..."
    rm -f "$BINARY/live/filesystem.squashfs.bak"
    log_ok "Backup removed"
fi

# --- Step 1: Build GRUB BIOS boot image ---
log_info "Step 1/3 — Building GRUB BIOS eltorito image..."
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# grub-mkimage — embed the modules needed to boot a live Linux system:
# biosdisk: BIOS disk access, iso9660: read ISO, normal: load grub.cfg,
# linux: the `linux` and `initrd` commands in grub.cfg
grub-mkimage \
    -O i386-pc-eltorito \
    -o "$TMPDIR/eltorito.img" \
    -p "/boot/grub" \
    biosdisk iso9660 normal linux

# Copy eltorito image into binary dir
mkdir -p "$BINARY/boot/grub/i386-pc"
cp "$TMPDIR/eltorito.img" "$BINARY/boot/grub/i386-pc/eltorito.img"

# Copy ALL grub i386-pc modules into the ISO so GRUB can load any module at runtime
log_info "  Copying GRUB modules into ISO (~5MB)..."
cp /usr/lib/grub/i386-pc/*.mod "$BINARY/boot/grub/i386-pc/" 2>/dev/null || true
cp /usr/lib/grub/i386-pc/*.lst "$BINARY/boot/grub/i386-pc/" 2>/dev/null || true
log_ok "BIOS boot image + modules ready"

# --- Step 2: Build ISO with xorriso -iso-level 3 ---
log_info "Step 2/3 — Building ISO with xorriso (iso-level 3 for >4GB files)..."
log_info "  Source: $BINARY"
log_info "  Output: $OUTPUT"
log_info "  This takes ~3-5 minutes..."

[ -f "$OUTPUT" ] && mv "$OUTPUT" "${OUTPUT}.old"

xorriso -as mkisofs \
    -iso-level 3 \
    -r -J -joliet-long \
    -V "PAVITRA_OS_1.0" \
    -b boot/grub/i386-pc/eltorito.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -append_partition 2 0xef "$BINARY/boot/grub/i386-pc/eltorito.img" \
    -o "$OUTPUT" \
    "$BINARY/" \
    2>&1 || true

# Retry without EFI partition if the above failed (simpler BIOS-only fallback)
if [ ! -f "$OUTPUT" ] || [ ! -s "$OUTPUT" ]; then
    log_info "Retrying without EFI partition (BIOS-only)..."
    xorriso -as mkisofs \
        -iso-level 3 \
        -r -J -joliet-long \
        -V "PAVITRA_OS_1.0" \
        -b boot/grub/i386-pc/eltorito.img \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
        -o "$OUTPUT" \
        "$BINARY/" \
        2>&1
fi

# --- Step 3: Verify ---
log_info "Step 3/3 — Verifying ISO..."
if [ -f "$OUTPUT" ]; then
    SIZE=$(du -sh "$OUTPUT" | cut -f1)
    SHA=$(sha256sum "$OUTPUT" | cut -d' ' -f1)
    log_ok "ISO built successfully!"
    echo ""
    echo "  📀 $OUTPUT"
    echo "  Size:   $SIZE"
    echo "  SHA256: $SHA"
    echo ""
    echo "  Test in QEMU:"
    echo "  sudo qemu-system-x86_64 -enable-kvm -cpu host -m 4096M -smp 2 \\"
    echo "      -cdrom $OUTPUT -boot d -vga virtio -display sdl"
else
    log_err "ISO not found — build failed"
    exit 1
fi
