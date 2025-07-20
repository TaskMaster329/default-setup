#!/bin/bash

DEST_FILE="/etc/ssh/sshd_config"

echo "[*] Create backup file sshd_config..."
cp "$DEST_FILE" "${DEST_FILE}.bak_$(date +%s)"


echo "[*] Check params..."
if ! grep -q "^PermitRootLogin yes" "$DEST_FILE"; then
    echo "PermitRootLogin yes" >> "$DEST_FILE"
fi

# === Reboot SSH ===
echo "[*] Reboot SSH..."
systemctl restart sshd || systemctl restart ssh

echo "[+] Done!"
