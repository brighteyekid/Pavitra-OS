#!/usr/bin/env bash
# =============================================================================
# inject-branding.sh — Pavitra OS Branding Injection
# Surgically replaces the Debian 12 Plymouth splash with Pavitra OS branding.
# Uses the existing squashfs — no full rebuild needed.
#
# Usage: sudo bash inject-branding.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_DIR="$SCRIPT_DIR/pavitra-build/binary/live"
SQUASHFS="$BINARY_DIR/filesystem.squashfs"
SQUASHFS_BAK="$BINARY_DIR/filesystem.squashfs.bak"
EXTRACT_DIR="/tmp/pavitra-squashfs-root"
THEME_DIR="$EXTRACT_DIR/usr/share/plymouth/themes/pavitra"
ASSETS_DIR="$SCRIPT_DIR/assets"
LOGO_SRC="$ASSETS_DIR/logo.png"
WALLPAPER_SRC="$ASSETS_DIR/wallpaper.png"
ISO_OUT="$SCRIPT_DIR/pavitra-os-1.0.iso"
BINARY_ROOT="$SCRIPT_DIR/pavitra-build/binary"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[inject]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_err()  { echo -e "${RED}[ERR]${NC}   $*"; }

# =============================================================================
# 0. Preflight checks
# =============================================================================
[ "$(id -u)" -eq 0 ] || { log_err "Must run as root: sudo bash inject-branding.sh"; exit 1; }
[ -f "$SQUASHFS" ]   || { log_err "squashfs not found: $SQUASHFS"; exit 1; }
[ -f "$LOGO_SRC" ]   || { log_err "Logo not found: $LOGO_SRC"; exit 1; }

AVAIL_GB=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {gsub("G",""); print $4}')
log_info "Disk space available: ${AVAIL_GB} GB"
if [ "$AVAIL_GB" -lt 18 ]; then
    log_warn "Low disk space (${AVAIL_GB} GB). Need ~18 GB for unsquash + resquash."
    log_warn "Continuing — may fail if disk fills up."
fi

# =============================================================================
# 1. Backup old squashfs
# =============================================================================
log_info "Step 1/6 — Backing up original squashfs..."
if [ ! -f "$SQUASHFS_BAK" ]; then
    cp "$SQUASHFS" "$SQUASHFS_BAK"
    log_ok "Backup created: filesystem.squashfs.bak"
else
    log_warn "Backup already exists — skipping copy."
fi

# =============================================================================
# 2. Extract squashfs
# =============================================================================
log_info "Step 2/6 — Extracting squashfs (this takes ~5-10 min)..."
rm -rf "$EXTRACT_DIR"
unsquashfs -d "$EXTRACT_DIR" "$SQUASHFS"
log_ok "Extracted to $EXTRACT_DIR"

# =============================================================================
# 3. Install Pavitra Plymouth theme
# =============================================================================
log_info "Step 3/6 — Installing Pavitra OS Plymouth theme..."
mkdir -p "$THEME_DIR"

# Copy logo — resize to fit nicely on boot screen (300px wide max)
log_info "  Copying logo..."
if command -v convert &>/dev/null; then
    convert "$LOGO_SRC" -resize 300x300 "$THEME_DIR/logo.png"
    log_ok "  Logo resized to 300x300 via ImageMagick"
else
    cp "$LOGO_SRC" "$THEME_DIR/logo.png"
    log_warn "  ImageMagick not found — using original logo size"
fi

# Create a simple pure-black background (1920x1080)
log_info "  Creating dark background..."
if command -v convert &>/dev/null; then
    convert -size 1920x1080 \
        radial-gradient:"#0A0A14-#000000" \
        "$THEME_DIR/background.png"
    log_ok "  Background created (dark radial gradient)"
else
    # Fallback: use wallpaper if no ImageMagick
    if [ -f "$WALLPAPER_SRC" ]; then
        cp "$WALLPAPER_SRC" "$THEME_DIR/background.png"
        log_ok "  Background: using wallpaper.png"
    else
        log_warn "  No background — Plymouth will use black"
    fi
fi

# Also copy logo into chroot overlay for LightDM/desktop
mkdir -p "$EXTRACT_DIR/usr/share/pavitra-os"
mkdir -p "$EXTRACT_DIR/usr/share/pixmaps"
cp "$LOGO_SRC" "$EXTRACT_DIR/usr/share/pavitra-os/logo.png"
cp "$LOGO_SRC" "$EXTRACT_DIR/usr/share/pixmaps/pavitra-os.png"
[ -f "$WALLPAPER_SRC" ] && cp "$WALLPAPER_SRC" "$EXTRACT_DIR/usr/share/pavitra-os/wallpaper.png"

# --- Plymouth .plymouth descriptor ---
cat > "$THEME_DIR/pavitra.plymouth" << 'PLYMOUTH_EOF'
[Plymouth Theme]
Name=Pavitra OS
Description=Pavitra OS boot splash — pure, minimal, sacred geometry
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/pavitra
ScriptFile=/usr/share/plymouth/themes/pavitra/pavitra.script
PLYMOUTH_EOF

# --- Plymouth script (the actual animation) ---
cat > "$THEME_DIR/pavitra.script" << 'SCRIPT_EOF'
# =============================================================================
# Pavitra OS Plymouth Boot Script
# Sacred geometry eye logo, centered, with animated dot progress indicator
# =============================================================================

# ── Screen setup ──────────────────────────────────────────────────────────────
screen_width  = Window.GetWidth();
screen_height = Window.GetHeight();

# ── Background ────────────────────────────────────────────────────────────────
bg_image = Image("background.png");
if (bg_image) {
    bg_sprite = Sprite(bg_image);
    bg_sprite.SetX(0);
    bg_sprite.SetY(0);
    bg_sprite.SetZ(-100);
} else {
    # Solid black fallback
    bg = Image.New(screen_width, screen_height);
    bg.Fill(0, 0, 0, 1.0);
    bg_sprite = Sprite(bg);
    bg_sprite.SetX(0);
    bg_sprite.SetY(0);
    bg_sprite.SetZ(-100);
}

# ── Logo ──────────────────────────────────────────────────────────────────────
logo_image = Image("logo.png");
logo_sprite = Sprite(logo_image);

logo_w = logo_image.GetWidth();
logo_h = logo_image.GetHeight();

logo_x = Math.Int((screen_width  - logo_w) / 2);
logo_y = Math.Int((screen_height - logo_h) / 2) - 40;

logo_sprite.SetX(logo_x);
logo_sprite.SetY(logo_y);
logo_sprite.SetZ(10);
logo_sprite.SetOpacity(0);

# ── Dot progress indicator ────────────────────────────────────────────────────
NUM_DOTS   = 5;
DOT_SIZE   = 6;
DOT_GAP    = 14;
DOT_Y      = logo_y + logo_h + 32;
total_dots_w = NUM_DOTS * DOT_SIZE + (NUM_DOTS - 1) * (DOT_GAP - DOT_SIZE);
dot_start_x  = Math.Int((screen_width - total_dots_w) / 2);

for (i = 0; i < NUM_DOTS; i++) {
    dot_img = Image.New(DOT_SIZE, DOT_SIZE);
    dot_img.Fill(1, 1, 1, 0.2);
    dot_sprites[i] = Sprite(dot_img);
    dot_sprites[i].SetX(dot_start_x + i * DOT_GAP);
    dot_sprites[i].SetY(DOT_Y);
    dot_sprites[i].SetZ(20);
}

# ── Animation state ───────────────────────────────────────────────────────────
t         = 0;
logo_fade = 0;
active_dot = 0;
dot_counter = 0;

fun refresh_callback() {
    t = t + 1;

    # Fade in logo over first 40 frames
    if (logo_fade < 1.0) {
        logo_fade = logo_fade + 0.025;
        if (logo_fade > 1.0) { logo_fade = 1.0; }
        logo_sprite.SetOpacity(logo_fade);
    }

    # Advance active dot every 12 frames
    dot_counter = dot_counter + 1;
    if (dot_counter >= 12) {
        dot_counter = 0;
        active_dot = (active_dot + 1) % NUM_DOTS;

        for (j = 0; j < NUM_DOTS; j++) {
            if (j == active_dot) {
                dot_sprites[j].SetOpacity(1.0);
            } else if (j == (active_dot + NUM_DOTS - 1) % NUM_DOTS) {
                dot_sprites[j].SetOpacity(0.5);
            } else {
                dot_sprites[j].SetOpacity(0.2);
            }
        }
    }
}

Plymouth.SetRefreshFunction(refresh_callback);

# ── Password prompt (disk encryption) ─────────────────────────────────────────
fun display_password_callback(prompt, bullets) {
    # Re-use dot sprites to show bullet count
    for (k = 0; k < NUM_DOTS; k++) {
        if (k < bullets) {
            dot_sprites[k].SetOpacity(1.0);
        } else {
            dot_sprites[k].SetOpacity(0.2);
        }
    }
}

Plymouth.SetDisplayPasswordFunction(display_password_callback);

fun display_normal_callback() {
    # Nothing special needed
}
Plymouth.SetDisplayNormalFunction(display_normal_callback);
SCRIPT_EOF

log_ok "Plymouth theme files created"

# =============================================================================
# 4. Set Pavitra theme as default + update alternatives inside chroot
# =============================================================================
log_info "Step 4/6 — Configuring Plymouth default theme inside chroot..."

# Set default theme in plymouthd.conf
PLYMOUTH_CONF="$EXTRACT_DIR/etc/plymouth/plymouthd.conf"
mkdir -p "$(dirname "$PLYMOUTH_CONF")"
cat > "$PLYMOUTH_CONF" << 'CONF_EOF'
[Daemon]
Theme=pavitra
ShowDelay=0
DeviceTimeout=5
CONF_EOF
log_ok "  /etc/plymouth/plymouthd.conf → Theme=pavitra"

# Write an update-alternatives symlink for the default theme
DEFAULT_THEME_LINK="$EXTRACT_DIR/usr/share/plymouth/themes/default.plymouth"
ln -sfn /usr/share/plymouth/themes/pavitra/pavitra.plymouth "$DEFAULT_THEME_LINK"
log_ok "  default.plymouth → pavitra"

# Remove Debian-specific plymouth theme branding from initramfs
DEBIAN_SPINNER="$EXTRACT_DIR/usr/share/plymouth/themes/spinner"
if [ -d "$DEBIAN_SPINNER" ]; then
    # Keep spinner dir but remove the Debian logo
    find "$DEBIAN_SPINNER" -name "*.png" -delete 2>/dev/null || true
    log_ok "  Cleaned Debian spinner images"
fi

# Also patch LightDM config to remove Debian greeter branding
LIGHTDM_CONF="$EXTRACT_DIR/etc/lightdm/lightdm-gtk-greeter.conf"
if [ -f "$LIGHTDM_CONF" ]; then
    # Replace Debian logo with our logo
    sed -i 's|^logo\s*=.*|logo=/usr/share/pavitra-os/logo.png|' "$LIGHTDM_CONF"
    # Remove debian-specific background if present
    sed -i 's|^background\s*=.*|background=/usr/share/pavitra-os/wallpaper.png|' "$LIGHTDM_CONF"
    log_ok "  LightDM greeter config updated"
else
    # Create it fresh
    mkdir -p "$(dirname "$LIGHTDM_CONF")"
    cat > "$LIGHTDM_CONF" << 'LDM_EOF'
[greeter]
background=/usr/share/pavitra-os/wallpaper.png
logo=/usr/share/pavitra-os/logo.png
theme-name=Arc-Dark
icon-theme-name=Papirus-Dark
font-name=Inter 11
LDM_EOF
    log_ok "  LightDM greeter config created"
fi

# Patch /etc/os-release to show Pavitra OS everywhere (removes "Debian" labels)
OS_RELEASE="$EXTRACT_DIR/etc/os-release"
cat > "$OS_RELEASE" << 'OS_EOF'
PRETTY_NAME="Pavitra OS 1.0"
NAME="Pavitra OS"
VERSION_ID="1.0"
VERSION="1.0"
VERSION_CODENAME=pavitra
ID=pavitra
ID_LIKE=debian
HOME_URL="https://pavitra-os.local"
SUPPORT_URL="https://pavitra-os.local"
BUG_REPORT_URL="https://pavitra-os.local"
LOGO=pavitra-os
OS_EOF
log_ok "  /etc/os-release → Pavitra OS 1.0"

# Patch /etc/issue and /etc/issue.net (TTY welcome message)
echo "Pavitra OS 1.0 — Run Everything. Pure Linux." > "$EXTRACT_DIR/etc/issue"
echo "Pavitra OS 1.0" > "$EXTRACT_DIR/etc/issue.net"
log_ok "  /etc/issue updated"

# Patch /etc/hostname 
echo "pavitra" > "$EXTRACT_DIR/etc/hostname"
log_ok "  hostname → pavitra"

# Also update the initramfs inside the chroot so Plymouth loads our theme at boot
# We do this by running update-initramfs inside a chroot bind-mount
log_info "  Updating initramfs (chroot) to embed Pavitra Plymouth theme..."

# Bind mounts needed for chroot
mount --bind /dev  "$EXTRACT_DIR/dev"  2>/dev/null || true
mount --bind /proc "$EXTRACT_DIR/proc" 2>/dev/null || true
mount --bind /sys  "$EXTRACT_DIR/sys"  2>/dev/null || true

# Run update-alternatives + update-initramfs inside chroot
chroot "$EXTRACT_DIR" /bin/bash -c "
set -e
# Register our theme with update-alternatives if the tool exists
if command -v update-alternatives &>/dev/null; then
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth \
        default.plymouth \
        /usr/share/plymouth/themes/pavitra/pavitra.plymouth 200 \
        2>/dev/null || true
    update-alternatives --set default.plymouth \
        /usr/share/plymouth/themes/pavitra/pavitra.plymouth \
        2>/dev/null || true
fi

# Find the kernel version present
KVER=\$(ls /lib/modules/ | head -1)
echo \"Kernel version in chroot: \$KVER\"

# Rebuild initramfs with our Plymouth theme embedded
if command -v update-initramfs &>/dev/null && [ -n \"\$KVER\" ]; then
    update-initramfs -u -k \"\$KVER\" 2>&1 | tail -5
    echo 'initramfs updated'
else
    echo 'WARNING: update-initramfs not available — Plymouth may not load at boot'
fi
" && log_ok "  initramfs updated inside chroot" || log_warn "  initramfs update had issues (non-fatal)"

# Unmount binds
umount "$EXTRACT_DIR/dev"  2>/dev/null || true
umount "$EXTRACT_DIR/proc" 2>/dev/null || true
umount "$EXTRACT_DIR/sys"  2>/dev/null || true

# =============================================================================
# 5. Repack squashfs
# =============================================================================
log_info "Step 5/6 — Repacking squashfs (this takes ~15-20 min)..."
rm -f "$SQUASHFS"
mksquashfs "$EXTRACT_DIR" "$SQUASHFS" \
    -comp xz \
    -Xdict-size 100% \
    -noappend \
    -no-progress 2>&1 | tail -3
log_ok "Squashfs repacked: $(du -sh "$SQUASHFS" | cut -f1)"

# Copy new initramfs from chroot if it was updated
KVER=$(ls "$EXTRACT_DIR/lib/modules/" 2>/dev/null | head -1)
if [ -n "$KVER" ] && [ -f "$EXTRACT_DIR/boot/initrd.img-${KVER}" ]; then
    cp "$EXTRACT_DIR/boot/initrd.img-${KVER}" "$BINARY_DIR/initrd.img-${KVER}"
    cp "$EXTRACT_DIR/boot/initrd.img-${KVER}" "$BINARY_DIR/initrd.img"
    log_ok "Initramfs updated in binary/live/ (${KVER})"
else
    log_warn "Could not copy updated initramfs (non-fatal — using existing)"
fi

# Cleanup extracted root to recover disk space
log_info "  Cleaning up extracted filesystem (recovering disk space)..."
rm -rf "$EXTRACT_DIR"
log_ok "  Cleaned up $EXTRACT_DIR"

# =============================================================================
# 6. Rebuild ISO with xorriso
# =============================================================================
log_info "Step 6/6 — Rebuilding ISO with Pavitra OS branding..."

ISO_BAK="${ISO_OUT%.iso}-pre-brand.iso"
[ -f "$ISO_OUT" ] && mv "$ISO_OUT" "$ISO_BAK" && log_info "  Old ISO moved to $(basename $ISO_BAK)"

xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "PAVITRA_OS_1.0" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin 2>/dev/null \
    -eltorito-boot boot/grub/i386-pc/eltorito.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --eltorito-catalog boot/grub/boot.cat \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img 2>/dev/null \
    -eltorito-alt-boot \
    -e EFI/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "$ISO_OUT" \
    "$BINARY_ROOT" 2>&1 | tail -10

if [ -f "$ISO_OUT" ]; then
    SIZE=$(du -sh "$ISO_OUT" | cut -f1)
    log_ok "====================================================="
    log_ok " Pavitra OS ISO rebuilt: $ISO_OUT"
    log_ok " Size: $SIZE"
    log_ok "====================================================="
    # Remove pre-brand backup now that we succeeded
    rm -f "$ISO_BAK"
else
    log_err "ISO not created — trying simpler xorriso command..."
    grub-mkrescue -o "$ISO_OUT" "$BINARY_ROOT" 2>&1 | tail -5
    [ -f "$ISO_OUT" ] && log_ok "ISO created via grub-mkrescue: $(du -sh $ISO_OUT | cut -f1)" \
                      || { log_err "ISO creation failed"; exit 1; }
fi

log_ok ""
log_ok "Done! Test with:"
log_ok "  sudo bash test-in-qemu.sh"
