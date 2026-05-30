#!/usr/bin/env bash
# =============================================================================
# rebuild-iso-branded.sh — Rebuild the Pavitra OS ISO after branding injection
# The squashfs has already been repacked with the Pavitra Plymouth theme.
# Note: set -euo pipefail is intentionally relaxed around cpio to avoid
# SIGPIPE (exit 141) that occurs when cpio closes stdin before cat finishes.
# This script:
#   1. Updates the initramfs (binary/live/initrd.img) to embed Plymouth theme
#   2. Rebuilds the ISO using grub-mkrescue
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_DIR="$SCRIPT_DIR/pavitra-build/binary/live"
BINARY_ROOT="$SCRIPT_DIR/pavitra-build/binary"
SQUASHFS="$BINARY_DIR/filesystem.squashfs"
INITRD="$BINARY_DIR/initrd.img"
ISO_OUT="$SCRIPT_DIR/pavitra-os-1.0.iso"
TMP_INITRD="/tmp/pavitra-initrd-work"
THEME_PAYLOAD="/tmp/pavitra-plymouth-payload"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[rebuild]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()  { echo -e "${RED}[ERR]${NC}   $*"; }

[ "$(id -u)" -eq 0 ] || { log_err "Must run as root: sudo bash rebuild-iso-branded.sh"; exit 1; }
[ -f "$SQUASHFS" ] || { log_err "Squashfs not found: $SQUASHFS"; exit 1; }
[ -f "$INITRD" ]   || { log_err "initrd.img not found: $INITRD"; exit 1; }

# =============================================================================
# Step 1 — Inject Plymouth theme into the initramfs
# =============================================================================
log_info "Step 1/2 — Injecting Pavitra Plymouth theme into initramfs..."

INITRD_SIZE_BEFORE=$(du -sh "$INITRD" | cut -f1)
log_info "  initrd.img size before: $INITRD_SIZE_BEFORE"

# Work dirs
rm -rf "$TMP_INITRD" "$THEME_PAYLOAD"
mkdir -p "$TMP_INITRD"
mkdir -p "$THEME_PAYLOAD/usr/share/plymouth/themes/pavitra"
mkdir -p "$THEME_PAYLOAD/etc/plymouth"

# Grab the Pavitra theme from the repacked squashfs
log_info "  Extracting Plymouth theme from repacked squashfs..."
SQUASH_THEME_DIR="/tmp/pavitra-squashfs-root/usr/share/plymouth/themes/pavitra"

if [ -d "$SQUASH_THEME_DIR" ]; then
    cp -r "$SQUASH_THEME_DIR"/* "$THEME_PAYLOAD/usr/share/plymouth/themes/pavitra/"
    log_ok "  Theme found in extracted squashfs dir (still present)"
else
    log_warn "  Squashfs extract dir gone — pulling theme from squashfs directly..."
    # Extract just the theme dir from the squashfs
    unsquashfs -d /tmp/pavitra-theme-only \
        "$SQUASHFS" \
        "usr/share/plymouth/themes/pavitra/*" \
        "etc/plymouth/*" 2>/dev/null || true

    if [ -d "/tmp/pavitra-theme-only/usr/share/plymouth/themes/pavitra" ]; then
        cp -r /tmp/pavitra-theme-only/usr/share/plymouth/themes/pavitra/* \
              "$THEME_PAYLOAD/usr/share/plymouth/themes/pavitra/"
        cp -r /tmp/pavitra-theme-only/etc/plymouth/* \
              "$THEME_PAYLOAD/etc/plymouth/" 2>/dev/null || true
        rm -rf /tmp/pavitra-theme-only
        log_ok "  Theme extracted from squashfs"
    else
        log_warn "  Could not extract theme — using assets directly"
        # Last resort: build the theme from assets
        LOGO_SRC="$SCRIPT_DIR/assets/logo.png"
        convert "$LOGO_SRC" -resize 300x300 \
            "$THEME_PAYLOAD/usr/share/plymouth/themes/pavitra/logo.png"
        convert -size 1920x1080 radial-gradient:"#0A0A14-#000000" \
            "$THEME_PAYLOAD/usr/share/plymouth/themes/pavitra/background.png"
        rm -rf /tmp/pavitra-theme-only
    fi
fi

# Write plymouthd.conf into payload
cat > "$THEME_PAYLOAD/etc/plymouth/plymouthd.conf" << 'CONF'
[Daemon]
Theme=pavitra
ShowDelay=0
DeviceTimeout=5
CONF

# Write the .plymouth descriptor if not copied
if [ ! -f "$THEME_PAYLOAD/usr/share/plymouth/themes/pavitra/pavitra.plymouth" ]; then
cat > "$THEME_PAYLOAD/usr/share/plymouth/themes/pavitra/pavitra.plymouth" << 'PEOF'
[Plymouth Theme]
Name=Pavitra OS
Description=Pavitra OS boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/pavitra
ScriptFile=/usr/share/plymouth/themes/pavitra/pavitra.script
PEOF
fi

# Write Plymouth script if not present
if [ ! -f "$THEME_PAYLOAD/usr/share/plymouth/themes/pavitra/pavitra.script" ]; then
cat > "$THEME_PAYLOAD/usr/share/plymouth/themes/pavitra/pavitra.script" << 'SEOF'
screen_width  = Window.GetWidth();
screen_height = Window.GetHeight();
bg_image = Image("background.png");
if (bg_image) {
    bg_sprite = Sprite(bg_image);
    bg_sprite.SetX(0); bg_sprite.SetY(0); bg_sprite.SetZ(-100);
}
logo_image = Image("logo.png");
logo_sprite = Sprite(logo_image);
logo_w = logo_image.GetWidth(); logo_h = logo_image.GetHeight();
logo_x = Math.Int((screen_width - logo_w) / 2);
logo_y = Math.Int((screen_height - logo_h) / 2) - 40;
logo_sprite.SetX(logo_x); logo_sprite.SetY(logo_y);
logo_sprite.SetZ(10); logo_sprite.SetOpacity(0);
NUM_DOTS=5; DOT_SIZE=6; DOT_GAP=14;
DOT_Y = logo_y + logo_h + 32;
total_w = NUM_DOTS * DOT_SIZE + (NUM_DOTS - 1) * (DOT_GAP - DOT_SIZE);
dot_start_x = Math.Int((screen_width - total_w) / 2);
for (i = 0; i < NUM_DOTS; i++) {
    d = Image.New(DOT_SIZE, DOT_SIZE); d.Fill(1,1,1,0.2);
    dot_sprites[i] = Sprite(d);
    dot_sprites[i].SetX(dot_start_x + i * DOT_GAP);
    dot_sprites[i].SetY(DOT_Y); dot_sprites[i].SetZ(20);
}
t=0; logo_fade=0; active_dot=0; dot_counter=0;
fun refresh_callback() {
    t = t + 1;
    if (logo_fade < 1.0) { logo_fade = logo_fade + 0.025; logo_sprite.SetOpacity(logo_fade); }
    dot_counter = dot_counter + 1;
    if (dot_counter >= 12) {
        dot_counter = 0; active_dot = (active_dot + 1) % NUM_DOTS;
        for (j = 0; j < NUM_DOTS; j++) {
            if (j == active_dot) { dot_sprites[j].SetOpacity(1.0); }
            else if (j == (active_dot + NUM_DOTS - 1) % NUM_DOTS) { dot_sprites[j].SetOpacity(0.5); }
            else { dot_sprites[j].SetOpacity(0.2); }
        }
    }
}
Plymouth.SetRefreshFunction(refresh_callback);
SEOF
fi

# --- Inject theme into initramfs ---
# initramfs may be gzip or lz4 compressed; detect and handle
log_info "  Detecting initramfs compression..."
INITRD_MAGIC=$(file "$INITRD" | head -1)
log_info "  initramfs type: $INITRD_MAGIC"

# Extract the initramfs — use input redirection to avoid SIGPIPE
# (cat | cpio causes exit 141 when cpio closes stdin before cat finishes)
cd "$TMP_INITRD"
set +e  # Disable pipefail for cpio block — cpio exits non-zero on warnings
if echo "$INITRD_MAGIC" | grep -qi "gzip"; then
    log_info "  Format: gzip"
    zcat "$INITRD" | cpio -id --quiet 2>/dev/null; true
elif echo "$INITRD_MAGIC" | grep -qi "Zstandard"; then
    log_info "  Format: zstd"
    zstdcat "$INITRD" | cpio -id --quiet 2>/dev/null; true
elif echo "$INITRD_MAGIC" | grep -qi "XZ"; then
    log_info "  Format: xz"
    xzcat "$INITRD" | cpio -id --quiet 2>/dev/null; true
elif echo "$INITRD_MAGIC" | grep -qi "LZ4"; then
    log_info "  Format: lz4"
    lz4cat "$INITRD" | cpio -id --quiet 2>/dev/null; true
elif echo "$INITRD_MAGIC" | grep -qi "cpio"; then
    log_info "  Format: raw cpio (uncompressed) — using input redirect"
    cpio -id --quiet < "$INITRD" 2>/dev/null; true
else
    log_warn "  Unknown format — attempting raw cpio with redirect"
    cpio -id --quiet < "$INITRD" 2>/dev/null; true
fi
set -e  # Re-enable strict mode

log_ok "  initramfs extracted ($(ls | wc -l) top-level entries)"

# Copy theme payload into extracted initramfs
cp -r "$THEME_PAYLOAD"/* "$TMP_INITRD/"
log_ok "  Plymouth theme injected into initramfs"

# Also set default theme link inside initramfs
mkdir -p "$TMP_INITRD/usr/share/plymouth/themes"
ln -sfn /usr/share/plymouth/themes/pavitra/pavitra.plymouth \
    "$TMP_INITRD/usr/share/plymouth/themes/default.plymouth" 2>/dev/null || true

# Repack initramfs — match original format
# Use process substitution to avoid SIGPIPE from cpio writer being killed early
log_info "  Repacking initramfs..."
set +e  # cpio returns non-zero exit codes on warnings
if echo "$INITRD_MAGIC" | grep -qi "gzip"; then
    ( find . | sort | cpio -o --format=newc --quiet 2>/dev/null | gzip -9 ) > "$INITRD"
    log_info "  Repacked as gzip cpio"
elif echo "$INITRD_MAGIC" | grep -qi "cpio"; then
    # Raw cpio — write directly without compression
    ( find . | sort | cpio -o --format=newc --quiet 2>/dev/null ) > "$INITRD"
    log_info "  Repacked as raw cpio"
else
    ( find . | sort | cpio -o --format=newc --quiet 2>/dev/null ) > "$INITRD"
    log_info "  Repacked as raw cpio (default)"
fi
set -e
INITRD_SIZE_AFTER=$(du -sh "$INITRD" | cut -f1)
log_ok "  initramfs repacked: $INITRD_SIZE_BEFORE → $INITRD_SIZE_AFTER"

cd /
rm -rf "$TMP_INITRD" "$THEME_PAYLOAD"

# =============================================================================
# Step 2 — Rebuild ISO
# =============================================================================
log_info "Step 2/2 — Rebuilding Pavitra OS ISO..."

# Move old ISO aside
[ -f "$ISO_OUT" ] && mv "$ISO_OUT" "${ISO_OUT%.iso}-old.iso"

# Use grub-mkrescue — same method that worked before
grub-mkrescue \
    --output="$ISO_OUT" \
    "$BINARY_ROOT" \
    -- -volid "PAVITRA_OS_1.0" \
    2>&1 | tail -5

if [ -f "$ISO_OUT" ]; then
    SIZE=$(du -sh "$ISO_OUT" | cut -f1)
    # Remove old backup
    rm -f "${ISO_OUT%.iso}-old.iso"
    log_ok "=============================================="
    log_ok " ✅ Pavitra OS ISO ready!"
    log_ok "    $ISO_OUT"
    log_ok "    Size: $SIZE"
    log_ok "=============================================="
    log_ok ""
    log_ok " Test with:"
    log_ok "   sudo bash $SCRIPT_DIR/test-in-qemu.sh"
else
    log_err "grub-mkrescue failed — trying xorriso fallback..."
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "PAVITRA_OS_1.0" \
        -o "$ISO_OUT" \
        "$BINARY_ROOT" 2>&1 | tail -5

    [ -f "$ISO_OUT" ] \
        && { rm -f "${ISO_OUT%.iso}-old.iso"; log_ok "ISO created via xorriso: $(du -sh $ISO_OUT | cut -f1)"; } \
        || { log_err "Both methods failed"; exit 1; }
fi
