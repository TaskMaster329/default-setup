#!/bin/bash

DEST_FILE="/etc/ssh/sshd_config"

echo "[*] Creating backup of sshd_config..."
cp "$DEST_FILE" "${DEST_FILE}.bak_$(date +%s)"

echo "[*] Enabling root login if not already enabled..."
if ! grep -q "^PermitRootLogin yes" "$DEST_FILE"; then
    echo "PermitRootLogin yes" >> "$DEST_FILE"
fi

while true; do
  echo ""
  echo "Select authentication method:"
  echo "1) Password auth for existing user"
  echo "2) SSH key auth for existing user"
  echo "3) Create new user with auth method"
  read -p "Enter number (1, 2 or 3): " auth_method

  case "$auth_method" in
    1)
      read -p "Enter existing username: " user

      if ! id "$user" &>/dev/null; then
        echo "User '$user' does not exist. Try again."
        continue
      fi

      echo "[*] Enabling password authentication..."
      if grep -q "^PasswordAuthentication no" "$DEST_FILE"; then
          sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' "$DEST_FILE"
      elif ! grep -q "^PasswordAuthentication yes" "$DEST_FILE"; then
          echo "PasswordAuthentication yes" >> "$DEST_FILE"
      fi

      echo "[*] Setting password for user $user..."
      passwd "$user"
      break
      ;;

    2)
      read -p "Enter existing username: " user

      if ! id "$user" &>/dev/null; then
        echo "User '$user' does not exist. Try again."
        continue
      fi

      read -p "Paste the public SSH key (e.g., ssh-rsa ...): " pubkey

      HOME_DIR=$(eval echo "~$user")
      SSH_DIR="$HOME_DIR/.ssh"
      AUTH_KEYS="$SSH_DIR/authorized_keys"

      echo "[*] Configuring SSH key for $user..."

      mkdir -p "$SSH_DIR"
      chmod 700 "$SSH_DIR"
      echo "$pubkey" >> "$AUTH_KEYS"
      chmod 600 "$AUTH_KEYS"
      chown -R "$user:$user" "$SSH_DIR"

      echo "[*] Disabling password authentication..."
      if grep -q "^PasswordAuthentication yes" "$DEST_FILE"; then
          sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' "$DEST_FILE"
      elif ! grep -q "^PasswordAuthentication no" "$DEST_FILE"; then
          echo "PasswordAuthentication no" >> "$DEST_FILE"
      fi
      break
      ;;

    3)
      read -p "Enter new username: " new_user

      if id "$new_user" &>/dev/null; then
        echo "User '$new_user' already exists. Try again."
        continue
      fi

      useradd -m "$new_user"
      echo "User $new_user created."

      while true; do
        echo ""
        echo "Choose authentication method for $new_user:"
        echo "1) Password"
        echo "2) SSH Key"
        read -p "Enter 1 or 2: " new_auth

        case "$new_auth" in
          1)
            echo "[*] Setting password for $new_user..."
            passwd "$new_user"

            echo "[*] Enabling password authentication..."
            if grep -q "^PasswordAuthentication no" "$DEST_FILE"; then
                sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' "$DEST_FILE"
            elif ! grep -q "^PasswordAuthentication yes" "$DEST_FILE"; then
                echo "PasswordAuthentication yes" >> "$DEST_FILE"
            fi
            break
            ;;

          2)
            read -p "Paste the public SSH key for $new_user (e.g., ssh-rsa ...): " pubkey

            HOME_DIR=$(eval echo "~$new_user")
            SSH_DIR="$HOME_DIR/.ssh"
            AUTH_KEYS="$SSH_DIR/authorized_keys"

            mkdir -p "$SSH_DIR"
            chmod 700 "$SSH_DIR"
            echo "$pubkey" >> "$AUTH_KEYS"
            chmod 600 "$AUTH_KEYS"
            chown -R "$new_user:$new_user" "$SSH_DIR"

            echo "[*] Disabling password authentication..."
            if grep -q "^PasswordAuthentication yes" "$DEST_FILE"; then
                sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' "$DEST_FILE"
            elif ! grep -q "^PasswordAuthentication no" "$DEST_FILE"; then
                echo "PasswordAuthentication no" >> "$DEST_FILE"
            fi
            break
            ;;

          *)
            echo "Invalid selection. Please try again."
            ;;
        esac
      done
      break
      ;;

    *)
      echo "Invalid selection. Please try again."
      ;;
  esac
done

echo "[*] Restarting SSH service..."
systemctl restart sshd || systemctl restart ssh

echo "[+] Done!"
