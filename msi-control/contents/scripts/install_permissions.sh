#!/bin/bash
# MSI Control Center: Secure Permission Setup
# This script is run as root via pkexec (one-time only)
set -e

GROUP_NAME="msi-ec"
RULES_FILE="99-msi-ec.rules"
TARGET_RULES="/etc/udev/rules.d/$RULES_FILE"

# Detect the actual user (not root, since pkexec runs as root)
REAL_USER="${PKEXEC_UID:+$(id -nu "$PKEXEC_UID")}"
if [ -z "$REAL_USER" ]; then
    REAL_USER="${SUDO_USER:-$USER}"
fi

echo "=== MSI Control Center: Secure Policy Setup ==="
echo "Target user: $REAL_USER"

# 1. Driver Detection
if [ ! -d "/sys/devices/platform/msi-ec" ]; then
    echo "ERROR: 'msi-ec' driver not found. Please load the module first."
    echo "Try: sudo modprobe msi-ec"
    exit 1
fi

# 2. Create system group (idempotent)
if ! getent group "$GROUP_NAME" >/dev/null 2>&1; then
    echo "Creating system group: $GROUP_NAME..."
    groupadd --system "$GROUP_NAME"
else
    echo "Group '$GROUP_NAME' already exists."
fi

# 3. Add user to group (idempotent)
if id -nG "$REAL_USER" 2>/dev/null | grep -qw "$GROUP_NAME"; then
    echo "User '$REAL_USER' already in group '$GROUP_NAME'."
else
    echo "Adding user '$REAL_USER' to group '$GROUP_NAME'..."
    usermod -aG "$GROUP_NAME" "$REAL_USER"
fi

# 4. Install udev rules
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
if [ -f "$SCRIPT_DIR/$RULES_FILE" ]; then
    echo "Installing udev rules to $TARGET_RULES..."
    install -m 644 "$SCRIPT_DIR/$RULES_FILE" "$TARGET_RULES"
else
    echo "ERROR: $RULES_FILE not found in $SCRIPT_DIR"
    exit 1
fi

# 5. Reload & trigger udev
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger --subsystem-match=platform --attr-match=driver=msi-ec 2>/dev/null || true
udevadm trigger --subsystem-match=power_supply 2>/dev/null || true
udevadm trigger --subsystem-match=leds 2>/dev/null || true

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✓ Permissions configured successfully."
echo "  ⚠ Log out and log back in to activate."
echo "═══════════════════════════════════════════════"
