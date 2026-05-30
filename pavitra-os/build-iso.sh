#!/usr/bin/env bash
# =============================================================================
# build-iso.sh — Pavitra OS Master Build Script
# Runs the ENTIRE build from start to finish with one command:
#   sudo bash build-iso.sh
# Logs everything to build.log and prints SHA256 checksum of final ISO.
# =============================================================================
set -e
set -x

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/pavitra-build"
LOG_FILE="$SCRIPT_DIR/build.log"
ISO_NAME="pavitra-os-1.0.iso"
START_TIME=$(date +%s)

# Tee all output to build.log while also showing on console
exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${CYAN}[build-iso]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[build-iso]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[build-iso]${NC} $1"; }
log_error() { echo -e "${RED}[build-iso]${NC} $1"; }

# =============================================================================
# 1. Root check
# =============================================================================
[ "$EUID" -eq 0 ] || { log_error "Run as root: sudo bash build-iso.sh"; exit 1; }

log_info "==================================================="
log_info "  Pavitra OS 1.0 — Full ISO Build"
log_info "  Started: $(date)"
log_info "  Log: $LOG_FILE"
log_info "==================================================="

# =============================================================================
# 2. Run Phase 1 — Build environment setup
# =============================================================================
log_info "--- Phase 1: Setting up build environment ---"
bash "$SCRIPT_DIR/setup-build-env.sh"
log_ok "Phase 1 complete."

# =============================================================================
# 3. Run Phase 2 — Base system construction (live-build)
# =============================================================================
log_info "--- Phase 2: Building base system ---"
bash "$SCRIPT_DIR/build-base.sh"
log_ok "Phase 2 complete."

# =============================================================================
# 4. Locate the generated ISO from live-build
# =============================================================================
log_info "Locating generated ISO..."
GENERATED_ISO=$(find "$BUILD_DIR" -maxdepth 1 -name "*.iso" | head -1)

if [ -z "$GENERATED_ISO" ]; then
    log_error "No ISO file found in $BUILD_DIR after build!"
    log_error "Check $LOG_FILE for errors."
    exit 1
fi
log_ok "Found ISO: $GENERATED_ISO"

# =============================================================================
# 5. Rename to the canonical Pavitra OS ISO name
# =============================================================================
FINAL_ISO="$SCRIPT_DIR/$ISO_NAME"
log_info "Moving ISO to: $FINAL_ISO"
mv "$GENERATED_ISO" "$FINAL_ISO"

# =============================================================================
# 6. Verify ISO size (warn if over 4 GB)
# =============================================================================
ISO_SIZE_BYTES=$(stat -c%s "$FINAL_ISO")
ISO_SIZE_MB=$((ISO_SIZE_BYTES / 1024 / 1024))
ISO_SIZE_GB_FRAC=$(echo "scale=2; $ISO_SIZE_BYTES / 1024 / 1024 / 1024" | bc)

log_info "ISO size: ${ISO_SIZE_MB} MB (${ISO_SIZE_GB_FRAC} GB)"
if [ "$ISO_SIZE_MB" -gt 4096 ]; then
    log_warn "ISO exceeds 4 GB (${ISO_SIZE_GB_FRAC} GB). Consider removing Darling or reducing packages."
else
    log_ok "ISO size is within 4 GB limit."
fi

# =============================================================================
# 7. Compute SHA256 checksum
# =============================================================================
log_info "Computing SHA256 checksum..."
CHECKSUM=$(sha256sum "$FINAL_ISO" | awk '{print $1}')
echo "$CHECKSUM  $ISO_NAME" > "$SCRIPT_DIR/${ISO_NAME}.sha256"
log_ok "SHA256: $CHECKSUM"
log_ok "Checksum saved: $SCRIPT_DIR/${ISO_NAME}.sha256"

# =============================================================================
# 8. Print build time
# =============================================================================
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
ELAPSED_MIN=$((ELAPSED / 60))
ELAPSED_SEC=$((ELAPSED % 60))

# =============================================================================
# 9. Final success summary
# =============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         PAVITRA OS BUILD SUCCESSFUL! 🎉             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ISO File:    ${CYAN}$FINAL_ISO${NC}"
echo -e "  Size:        ${CYAN}${ISO_SIZE_MB} MB (${ISO_SIZE_GB_FRAC} GB)${NC}"
echo -e "  SHA256:      ${CYAN}$CHECKSUM${NC}"
echo -e "  Build time:  ${CYAN}${ELAPSED_MIN}m ${ELAPSED_SEC}s${NC}"
echo ""
echo -e "  To test in QEMU:  ${YELLOW}bash test-in-qemu.sh${NC}"
echo -e "  To write to USB:  ${YELLOW}sudo dd if=$FINAL_ISO of=/dev/sdX bs=4M status=progress && sync${NC}"
echo ""
