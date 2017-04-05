# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

INIT_SPEC="version"

WORKSPACE="$HOME/.rootbox"
IMAGES="$WORKSPACE/images"
BOXES="$WORKSPACE/boxes"
MNT="$WORKSPACE/mnt"
TMP="$WORKSPACE/tmp"


remove_old_directory() {
  # remove_old_directory
  # Deletes the old workspace directory.

  [ "$force" == "false" ] && die "Workspace directory already exists"
  require_root "Root access is required to remove the old workspace directory."

  if [ -L "$WORKSPACE" ]; then
    to_remove=`realpath "$WORKSPACE"`
    rm "$WORKSPACE"
  else
    to_remove="$WORKSPACE"
  fi

  for mnt in $MNT/*; do
    umount_if_mounted "$mnt"
  done

  [ "`ls -A "$mnt"`" ] && die "Failed to clear mount directory $MNT!!"

  rm -rf "$to_remove"
}


init() {
  require_ext4 ${dir:-$WORKSPACE}
  [ -e "$WORKSPACE" ] && remove_old_directory

  pnote "Setting up workspace..."

  if [ -n "$dir" ]; then
    mkdir -p "$dir"
    ln -sf "$dir" "$WORKSPACE"
  else
    mkdir -p "$WORKSPACE"
  fi

  mkdir -p "$IMAGES"
  mkdir -p "$BOXES"
  mkdir -p "$MNT"
  mkdir -p "$TMP"

  sudo_perm_fix "$WORKSPACE"
  [ -n "$dir" ] && sudo_perm_fix "$path" || :

  pnote "Rootbox has been initailized."
}


init::DESCR() {
  echo "initailizes rootbox using the given arguments"
}


init::ARGS() {
  cmdarg "d?" "dir" "The data directory (Default \"$WORKSPACE\")"
  cmdarg "f" "force" "Force initialization, even if rootbox has already been \
initailized (WARNING: this will delete your previous data directory!)" "false"
}


register_command init
