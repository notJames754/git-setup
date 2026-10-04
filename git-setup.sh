#!/usr/bin/env bash

set -e


SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

SSH_CONFIG="$SCRIPT_DIR/ssh.config"
GIT_CONFIG="$SCRIPT_DIR/.gitconfig"
KEYS_DIR="$SCRIPT_DIR/keys"


if [[ ! -f "$SSH_CONFIG" ]]; then
    echo "Error: SSH config not found:"
    echo "  $SSH_CONFIG"
    exit 1
fi

if [[ ! -f "$GIT_CONFIG" ]]; then
    echo "Error: Git config not found:"
    echo "  $GIT_CONFIG"
    exit 1
fi


TEMP_DIR="$(mktemp -d)"
TEMP_KEYS_DIR="$TEMP_DIR/keys"
mkdir $TEMP_KEYS_DIR

TEMP_SSH_CONFIG="$TEMP_DIR/ssh-config"

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

find "$KEYS_DIR" \
    -maxdepth 1 \
    -type f \
    ! -name "*.pub" \
    -exec cp -- {} "$TEMP_KEYS_DIR/" \;

chmod 700 "$TEMP_KEYS_DIR"
chmod 600 "$TEMP_KEYS_DIR"/*

sed \
    "s|%KEY_DIR%|$TEMP_KEYS_DIR|g" \
    "$SSH_CONFIG" \
    > "$TEMP_SSH_CONFIG"


export GIT_SSH_COMMAND="ssh -F \"$TEMP_SSH_CONFIG\""
export GIT_CONFIG_GLOBAL="$GIT_CONFIG"

echo
echo "========================================"
echo " Git USB environment"
echo "========================================"
echo
echo " Git config : $GIT_CONFIG"
echo " SSH config : $SSH_CONFIG"
echo
echo "SSH keys:"
grep -E '^[[:space:]]*IdentityFile ' "$TEMP_SSH_CONFIG" \
    | sed 's/^[[:space:]]*/  /'
echo
echo "Type 'exit' when finished."
echo

(
    export PS1="[git-usb] \u@\h:\w\$ "
    exec "${SHELL:-/bin/bash}" -i
)