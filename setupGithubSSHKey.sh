#!/usr/bin/env bash

set -euo pipefail

SSH_DIR="$HOME/.ssh"
CONFIG_FILE="$SSH_DIR/config"

ensure_ssh_dir() {
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
}

add_key() {
    local email="$1"
    local profile="$2"
    local key_path="$SSH_DIR/id_ed25519_${profile}"
    local host_alias="github-${profile}"

    ensure_ssh_dir

    if [[ -f "$key_path" ]]; then
        echo "Key already exists at $key_path"
    else
        echo "Generating SSH key for profile '$profile'..."
        ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""
    fi

    eval "$(ssh-agent -s)" >/dev/null
    ssh-add "$key_path"

    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"

    if ! grep -q "Host $host_alias" "$CONFIG_FILE"; then
        cat >> "$CONFIG_FILE" <<EOF

Host $host_alias
  HostName github.com
  User git
  IdentityFile $key_path
  IdentitiesOnly yes
EOF
        echo "SSH config entry added for $host_alias."
    fi

    echo ""
    echo "Public key to add to GitHub ($profile):"
    echo "--------------------------------------"
    cat "${key_path}.pub"
    echo "--------------------------------------"
    echo "Test with: ssh -T $host_alias"
}

remove_key() {
    local profile="$1"
    local key_path="$SSH_DIR/id_ed25519_${profile}"
    local host_alias="github-${profile}"

    if [[ -f "$key_path" ]]; then
        rm -f "$key_path" "$key_path.pub"
        echo "Removed local key files for $profile."
    else
        echo "No key found for profile '$profile'"
    fi

    if grep -q "Host $host_alias" "$CONFIG_FILE"; then
        sed -i "/Host $host_alias/,/^$/d" "$CONFIG_FILE"
        echo "Removed SSH config entry for $host_alias."
    fi

    ssh-add -D >/dev/null 2>&1 || true
}

list_keys() {
    echo "Local SSH keys in $SSH_DIR:"
    echo "---------------------------"
    ls -1 "$SSH_DIR" | grep '^id_ed25519' || echo "No keys found"
}

check_key() {
    local alias="$1"
    echo "Testing SSH connection for $alias..."
    ssh -T "$alias"
}

list_linked() {
    echo "Checking which local keys authenticate with GitHub..."
    echo "----------------------------------------------------"
    for key in "$SSH_DIR"/id_ed25519*; do
        [[ -f "$key" ]] || continue
        ssh -i "$key" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -T git@github.com 2>&1 | \
        grep -E "Hi|Permission denied" | awk -v k="$key" '{print k ": " $0}'
    done
}

delete_all_keys() {
    read -p "Are you sure you want to delete ALL SSH keys? This cannot be undone! (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        rm -f "$SSH_DIR"/id_ed25519*
        sed -i '/Host github-/,/^$/d' "$CONFIG_FILE"
        ssh-add -D >/dev/null 2>&1 || true
        echo "All keys and related SSH config entries deleted."
    else
        echo "Aborted."
    fi
}

interactive_menu() {
    while true; do
        echo ""
        echo "================ GitHub SSH Key Manager ================"
        echo "1) Add new SSH key"
        echo "2) Remove a key"
        echo "3) List local keys"
        echo "4) Check which keys authenticate (linked)"
        echo "5) Delete all keys"
        echo "6) Test a key by alias"
        echo "0) Exit"
        echo "======================================================="
        read -p "Choose an option: " choice

        case "$choice" in
            1)
                read -p "Email: " email
                read -p "Profile name (e.g., personal, work): " profile
                add_key "$email" "$profile"
                ;;
            2)
                read -p "Profile name to remove: " profile
                remove_key "$profile"
                ;;
            3)
                list_keys
                ;;
            4)
                list_linked
                ;;
            5)
                delete_all_keys
                ;;
            6)
                read -p "Alias to test (e.g., github-work): " alias
                check_key "$alias"
                ;;
            0)
                echo "Exiting..."
                break
                ;;
            *)
                echo "Invalid option."
                ;;
        esac
    done
}

# --- Main ---

if [[ $# -ge 1 ]]; then
    cmd="$1"
    shift
    case "$cmd" in
        add) add_key "$@" ;;
        remove) remove_key "$@" ;;
        list) list_keys ;;
        linked) list_linked ;;
        check) check_key "$@" ;;
        delete-all) delete_all_keys ;;
        *) echo "Unknown command"; exit 1 ;;
    esac
else
    interactive_menu
fi

