#!/usr/bin/env bash

set -e


SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

SSH_CONFIG="$SCRIPT_DIR/ssh.config"
GIT_CONFIG="$SCRIPT_DIR/git.config"
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

# shellcheck disable=SC1090
source "$GIT_CONFIG"

if [[ -z "${GIT_NAME:-}" ]]; then
    echo "Error: GIT_NAME is not set"
    exit 1
fi

if [[ -z "${GIT_EMAIL:-}" ]]; then
    echo "Error: GIT_EMAIL is not set"
    exit 1
fi


TEMP_DIR="$(mktemp -d)"
TEMP_SSH_CONFIG="$TEMP_DIR/ssh-config"

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

sed \
    "s|%KEY_DIR%|$KEYS_DIR|g" \
    "$SSH_CONFIG" \
    > "$TEMP_SSH_CONFIG"


export GIT_SSH_COMMAND="ssh -F \"$TEMP_SSH_CONFIG\""


export GIT_CONFIG_COUNT=2

export GIT_CONFIG_KEY_0="user.name"
export GIT_CONFIG_VALUE_0="$GIT_NAME"

export GIT_CONFIG_KEY_1="user.email"
export GIT_CONFIG_VALUE_1="$GIT_EMAIL"

echo
echo "========================================"
echo " Git USB environment"
echo "========================================"
echo
echo " Git name   : $GIT_NAME"
echo " Git email  : $GIT_EMAIL"
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