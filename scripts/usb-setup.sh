#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# Git USB Setup
#
# Run this script from the USB stick.
#
# Creates:
#
#   ./git-config
#   ./ssh.config
#   ./keys/<key-name>
#   ./keys/<key-name>.pub
#
# The USB can later be used with git-setup
# =============================================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ROOT_DIR=$(realpath $SCRIPT_DIR/..)

SSH_CONFIG="$ROOT_DIR/ssh.config"
GIT_CONFIG="$ROOT_DIR/.gitconfig"
KEYS_DIR="$ROOT_DIR/keys"


die() {
    echo
    echo "Error: $*" >&2
    exit 1
}

ask_yes_no() {
    local prompt="$1"
    local answer

    while true; do
        read -r -p "$prompt [y/n] " answer

        case "${answer,,}" in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                echo "Please answer y or n."
                ;;
        esac
    done
}

# Check dependencies
command -v git >/dev/null 2>&1 || die "git is not installed."
command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is not installed."

mkdir -p "$KEYS_DIR"

echo
echo "========================================"
echo " Git USB Setup"
echo "========================================"
echo
echo "USB directory:"
echo "  $ROOT_DIR"
echo
echo "----------------------------------------"
echo " Git configuration"
echo "----------------------------------------"
echo

if [[ -f "$GIT_CONFIG" ]]; then
    echo "A Git configuration already exists:"
    echo "  $GIT_CONFIG"
    echo

    if ask_yes_no "Replace it?"; then
        rm -f "$GIT_CONFIG"
    else
        echo "Keeping existing Git configuration."
    fi
fi

if [[ ! -f "$GIT_CONFIG" ]]; then

    if [[ -f "$HOME/.gitconfig" ]]; then
        echo
        echo "Found your existing Git configuration:"
        echo "  $HOME/.gitconfig"
        echo

        if ask_yes_no "Copy your existing .gitconfig to the USB?"; then
            cp "$HOME/.gitconfig" "$GIT_CONFIG"
            echo "Git configuration copied."
        fi
    fi
fi

# If the user didn't copy an existing config, create one.
if [[ ! -f "$GIT_CONFIG" ]]; then

    echo
    echo "Creating a new Git configuration."
    echo

    read -r -p "Git user.name: " GIT_NAME

    while [[ -z "$GIT_NAME" ]]; do
        echo "Name cannot be empty."
        read -r -p "Git user.name: " GIT_NAME
    done

    read -r -p "Git user.email: " GIT_EMAIL

    while [[ -z "$GIT_EMAIL" ]]; do
        echo "Email cannot be empty."
        read -r -p "Git user.email: " GIT_EMAIL
    done

    cat > "$GIT_CONFIG" <<EOF
[user]
    name = $GIT_NAME
    email = $GIT_EMAIL
EOF

    echo
    echo "Created:"
    echo "  $GIT_CONFIG"
fi

echo
echo "----------------------------------------"
echo " SSH configuration"
echo "----------------------------------------"
echo

if [[ -f "$SSH_CONFIG" ]]; then
    echo "An SSH configuration already exists:"
    echo "  $SSH_CONFIG"
    echo

    if ! ask_yes_no "Replace it?"; then
        echo "Keeping existing SSH configuration."
        echo
        echo "Setup complete."
        exit 0
    fi

    rm -f "$SSH_CONFIG"
fi

touch "$SSH_CONFIG"

cat > "$SSH_CONFIG" <<'EOF'
# ============================================================================
# Git USB SSH configuration
#
# Paths are relative placeholders. git-setup replaces %KEY_DIR% with
# the keys directory when the environment is started.
# ============================================================================

EOF

echo
echo "You can now configure multiple Git hosts."
echo
echo "For each host you can:"
echo
echo "  Host name       The hostname used in the Git URL"
echo "                  e.g. github.com"
echo
echo "  Key name        Filename stored in ./keys/"
echo "                  e.g. github"
echo
echo "Examples:"
echo
echo "  git@github.com:username/repository.git"
echo "  git@gitlab.com:username/repository.git"
echo "  git@git.company.com:project/repository.git"
echo

while true; do

    echo
    echo "----------------------------------------"
    echo "Add SSH host"
    echo "----------------------------------------"
    echo

    # Host name
    read -r -p "Host name (empty to finish): " HOST

    if [[ -z "$HOST" ]]; then
        break
    fi

    # Basic validation.
    if [[ "$HOST" == *" "* ]]; then
        echo "Host name cannot contain spaces."
        continue
    fi

    # Host addr
    read -r -p "Host addr ($HOST): " HOST_ADDR

    if [[ -z "$HOST_ADDR" ]]; then
        HOST_ADDR=$HOST
    fi

    if [[ "$HOST_ADDR" == *" "* ]]; then
        echo "Host addr cannot contain spaces."
        continue
    fi

    # Host usr
    read -r -p "Host user (git): " HOST_USR

    if [[ -z "$HOST_USR" ]]; then
        HOST_USR=git
    fi

    if [[ "$HOST_USR" == *" "* ]]; then
        echo "Host user cannot contain spaces."
        continue
    fi

    # Key name
    read -r -p "SSH key name [$HOST]: " KEY_NAME

    if [[ -z "$KEY_NAME" ]]; then
        KEY_NAME="$HOST"
    fi

    # Keep key names filesystem-safe.
    if [[ "$KEY_NAME" == */* ]]; then
        echo "Key name cannot contain '/'."
        continue
    fi

    KEY_FILE="$KEYS_DIR/$KEY_NAME"
    PUBLIC_KEY="$KEY_FILE.pub"

    # Existing key
    if [[ -f "$KEY_FILE" ]]; then
        echo
        echo "A private key already exists:"
        echo "  $KEY_FILE"
        echo

        if ask_yes_no "Use this existing key?"; then
            continue
        fi
    else

        echo
        echo "No key found for $HOST."
        echo
    
    fi

    if ask_yes_no "Generate a new ED25519 key?"; then
        echo
        echo "Generating:"
        echo "  $KEY_FILE"
        echo

        ssh-keygen \
            -t ed25519 \
            -f "$KEY_FILE" \
            -C ""

        echo
        echo "Key generated."
    else
        echo
        echo "You can copy an existing private key to:"
        echo "  $KEY_FILE"
        echo
        echo "Skipping $HOST for now."
        continue
    fi

    # Make sure a public key exists
    if [[ ! -f "$PUBLIC_KEY" ]]; then

        echo
        echo "Public key not found."
        echo "Generating it from the private key..."

        ssh-keygen \
            -y \
            -f "$KEY_FILE" \
            > "$PUBLIC_KEY"

        # Add a newline if necessary.
        printf '\n' >> "$PUBLIC_KEY"

        echo "Public key generated:"
        echo "  $PUBLIC_KEY"
    fi

    # Add SSH host to config
    cat >> "$SSH_CONFIG" <<EOF

Host $HOST
    HostName $HOST_ADDR
    User $HOST_USR
    IdentityFile %KEY_DIR%/$KEY_NAME
    IdentitiesOnly yes
EOF

    echo
    echo "Added:"
    echo "  Host: $HOST"
    echo "  Key : $KEY_NAME"

    echo
    echo "Public key:"
    echo
    cat "$PUBLIC_KEY"
    echo

    echo "Add this public key to the corresponding Git provider."
    echo

    if ! ask_yes_no "Configure another Git host?"; then
        break
    fi

done

echo
echo "========================================"
echo " Setup complete"
echo "========================================"
echo
echo "USB directory:"
echo "  $ROOT_DIR"
echo
echo "Git configuration:"
echo "  $GIT_CONFIG"
echo
echo "SSH configuration:"
echo "  $SSH_CONFIG"
echo
echo "SSH keys:"
find "$KEYS_DIR" \
    -maxdepth 1 \
    -type f \
    -printf '  %f\n' 2>/dev/null || true
echo
echo "Configured hosts:"
grep -E '^Host ' "$SSH_CONFIG" | sed 's/^/  /' || true
echo
echo "========================================"
echo
echo "The USB is ready."
echo
echo "Use git-setup to start the isolated Git environment."
echo