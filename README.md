# git-setup

## What?
It's a tool that lets you set up a USB (via [usb-setup](scripts/usb-setup.sh))
and then use [git-setup](scripts/git-setup-unix.sh) on a different computer to
open a shell environment for Git that uses the SSH keys, SSH config and Git config
from the USB.

## Why?
So you can use Git over SSH on any pc without having to generate a new key for
each one. You also don't have to delete the SSH keys, like you would have to if you
store SSH keys on a PC other people have access to (school, work, etc.), as they
stay on the USB.*

*On Linux the SSH keys are copied to a temp dir because of Linux requires certain 
permissions to use SSH keys and USB drives usually don't support them because of their
file system.

## How?
It sets the GIT_CONFIG_GLOBAL env var to the Git config on the USB and the
GIT_SSH_COMMAND env var to use a copy of the SSH config on the USB with %KEY_DIR%
replaced with the correct path.

## Security
The scripts don't provide any security so to make it secure you have to use a passphrase
for each SSH key.