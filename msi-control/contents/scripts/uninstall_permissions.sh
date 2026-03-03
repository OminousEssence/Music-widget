#!/bin/bash
# MSI Control Center: Secure Policy Uninstaller

GROUP_NAME="msi-ec"
TARGET_RULES="/etc/udev/rules.d/99-msi-ec.rules"

echo "=== MSI Control Center: Cleanup ==="

if [ -f "$TARGET_RULES" ]; then
    echo "Removing udev rules..."
    sudo rm "$TARGET_RULES"
fi

echo "Reloading udev policies..."
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=platform --attr-match=driver=msi-ec 2>/dev/null || true
sudo udevadm trigger --subsystem-match=power_supply 2>/dev/null || true

echo ""
echo "Policy removed."
echo "Note: The user group '$GROUP_NAME' remains on the system."
echo "If you want to remove it manually: sudo groupdel $GROUP_NAME"
echo "==================================="
