#!/bin/bash

DEST_FILE="/etc/ssh/sshd_config"

echo "[*] Creating backup of sshd_config..."
cp "$DEST_FILE" "${DEST_FILE}.bak_$(date +%s)"

while true; do
  echo ""
  echo "Select authentication method or action:"
  echo "1) Password auth for existing user"
  echo "2) SSH key auth for existing user"
  echo "3) Create new user with auth method"
  echo "4) Change sshd server settings"
  read -p "Enter number (1, 2, 3 or 4): " auth_method

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

    4)
      while true; do
        # Читаем текущие значения или ставим "not set"
        current_permit_root=$(grep -E "^PermitRootLogin" "$DEST_FILE" | awk '{print $2}')
        current_permit_root=${current_permit_root:-not set}

        current_pubkey_auth=$(grep -E "^PubkeyAuthentication" "$DEST_FILE" | awk '{print $2}')
        current_pubkey_auth=${current_pubkey_auth:-not set}

        current_port=$(grep -E "^Port" "$DEST_FILE" | awk '{print $2}')
        current_port=${current_port:-22}

        echo ""
        echo "Choose SSH server preset settings to apply:"
        echo "1) Toggle PermitRootLogin (current: $current_permit_root)"
        echo "2) Toggle PubkeyAuthentication (current: $current_pubkey_auth)"
        echo "3) Change SSH server port (current: $current_port)"
        echo "4) Custom setting"
        echo "5) Done applying settings"

        read -p "Enter choice (1-5): " setting_choice
        case "$setting_choice" in
          1)
            echo "Current PermitRootLogin is '$current_permit_root'. Choose new value:"
            select val in yes no; do
              if [[ "$val" == "yes" || "$val" == "no" ]]; then
                if grep -q "^PermitRootLogin" "$DEST_FILE"; then
                  sed -i "s/^PermitRootLogin.*/PermitRootLogin $val/" "$DEST_FILE"
                else
                  echo "PermitRootLogin $val" >> "$DEST_FILE"
                fi
                echo "Set PermitRootLogin $val"
                break
              else
                echo "Invalid choice, try again."
              fi
            done
            ;;
          2)
            echo "Current PubkeyAuthentication is '$current_pubkey_auth'. Choose new value:"
            select val in yes no; do
              if [[ "$val" == "yes" || "$val" == "no" ]]; then
                if grep -q "^PubkeyAuthentication" "$DEST_FILE"; then
                  sed -i "s/^PubkeyAuthentication.*/PubkeyAuthentication $val/" "$DEST_FILE"
                else
                  echo "PubkeyAuthentication $val" >> "$DEST_FILE"
                fi
                echo "Set PubkeyAuthentication $val"
                break
              else
                echo "Invalid choice, try again."
              fi
            done
            ;;
          3)
            echo "Current SSH port is '$current_port'. Enter new port (1024-65535):"
            while true; do
              read -p "New port: " port
              if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1024 ] && [ "$port" -le 65535 ]; then
                if grep -q "^Port" "$DEST_FILE"; then
                  sed -i "s/^Port.*/Port $port/" "$DEST_FILE"
                else
                  echo "Port $port" >> "$DEST_FILE"
                fi
                echo "Set SSH Port $port"
                break
              else
                echo "Invalid port. Enter a number between 1024 and 65535."
              fi
            done
            ;;
          4)
            read -p "Enter custom sshd config key: " key
            read -p "Enter value for $key: " value
            if grep -q "^$key" "$DEST_FILE"; then
              sed -i "s|^$key.*|$key $value|" "$DEST_FILE"
            else
              echo "$key $value" >> "$DEST_FILE"
            fi
            echo "Set custom setting: $key $value"
            ;;
          5)
            echo "Done applying settings."
            break
            ;;
          *)
            echo "Invalid choice. Try again."
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
