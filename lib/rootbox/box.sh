# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


DEFAULT_COMMAND="/bin/ash -i"
FACTORY="_factory.sh"


load_factory() {
  # load_factory
  # Copies the image factory script to the box's mount point.
  cp "$path" "$mpoint/$FACTORY"
}


box_actual_setup() {
  # box_actual_setup
  # Runs /bin/ash inside the chroot, with all the bind mounts setup, which
  # will in turn execute the factory script if it was present.

  in_chroot "$mpoint" "/bin/ash /$SETUP" "$tbox/binds"
}


box_setup() {
  # box_setup
  # Sets up the box $tbox using the image factory location in $factory.

  if [ -n "$factory" ]; then
    pnote "Using image factory $factory..."
    with_location "$factory" load_factory "factory.sh"
  fi

  safecall box_actual_setup "rm -f '$mpoint/$FACTORY' '$mpoint/$SETUP'"
}


box.new() {
  require_init
  require_root

  image="`image_path "v$version"`"
  box="`box_path "$name"`"
  tbox="$box.tmp"  # Temporary box path.

  export box tbox factory

  [ ! -d "$box" ] || die "Box '$name' has already been created"
  [ -f "$image" ] || die "Version $version is not yet installed"

  pnote "Creating box..."

  mkdir -p "$tbox"

  echo -e `join "\n" "${box_bind_values[@]}"` > "$tbox/binds"
  cp --sparse=always "$image" "$tbox/image"

  pnote "Setting up box..."
  with_mount "$tbox/image" box_setup

  pnote "Saving box..."
  sudo_perm_fix "$tbox"
  sudo_perm_fix "$tbox/binds" 664
  sudo_perm_fix "$tbox/image" 664
  mv "$tbox" "$box"

  pnote "Setup successful!"
}


box.new::DESCR() {
  echo "creates a new box using the given Alpine Linux image."
}


create_fake_validator box_bind


box.new::ARGS() {
  cmdarg "n:" "name" "The name of the new box"
  cmdarg "v?" "version" "The Alpine Linux version to use" "$DEFAULT_VER"
  cmdarg "f?" "factory" "The location path of the image factory to use"
  cmdarg "b?" "bind" "Set the given directory to be automatically bind \
mounted whenever the box is run. Can be passed multiple times." "" \
    box_bind_validate
}


box.clone() {
  require_init

  srcbox="`box_path "$source"`"
  [ -d "$srcbox" ] || die "Box '$source' does not exist"

  dstbox="`box_path "$name"`"
  [ ! -d "$dstbox" ] || die "Box '$name' has already been created"

  pnote "Cloning box..."
  cp --sparse=always -r "$srcbox" "$dstbox"
  pnote "Clone was successful!"
}


box.clone::DESCR() {
  echo "clones the given box."
}


box.clone::ARGS() {
  cmdarg "s:" "source" "The name of the box to clone"
  cmdarg "n:" "name" "The name of the new box"
}


box.dist() {
  require_init

  box="`box_path "$name"`"
  [ -d "$box" ] || die "Box '$name' does not exist"

  [ "$output" == "<name>.box" ] && output="$name.box" || :

  pnote "Exporting box..."
  bsdtar cf "$output" -C "$box" binds image
  pnote "Successfully exported box to '$output'!"
}


box.dist::DESCR() {
  echo "exports the given box for distribution."
}


box.dist::ARGS() {
  cmdarg "n:" "name" "The name of the box to export"
  cmdarg "o:" "output" "The output file" "<name>.box"
}


import_box() {
  pnote "Importing box..."
  tar xf "$path" -C "$tbox"
}


box.import() {
  require_init

  box="`box_path "$name"`"
  tbox="$box.tmp"
  export box

  [ ! -d "$box" ] || die "Box '$name' has already been created"

  pnote "Setting up import..."
  mkdir -p "$tbox"

  with_location "$loc" import_box dist.box
  mv "$tbox" "$box"

  pnote "Successfully imported box '$name'!"
}


box.import::DESCR() {
  echo "imports an exported box into the Rootbox workspace."
}


box.import::ARGS() {
  cmdarg "l:" "loc" "The location path of the box to import"
  cmdarg "n:" "name" "The name of the new box"
}


box.list() {
  require_init
  find "$BOXES" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | \
    sed 's/.box$//' | sort
}


box.list::DESCR() {
  echo "lists all installed boxes."
}


box.list::ARGS() {
  :
}


box_run_command() {
  # box_run_command
  # Runs $command inside the mounted box $mpoint, with the proper bind mounts.
  in_chroot "$mpoint" "$command" "$box/binds" "${box_bind_values[@]}"
}


box.run() {
  require_init
  require_root

  box="`box_path "$name"`"
  [ -d "$box" ] || die "Box '$name' does not exist"

  export box command
  with_mount "$box/image" box_run_command
}


box.run::DESCR() {
  echo "runs the command inside the given box."
}

box.run::ARGS() {
  cmdarg "n:" "name" "The name of the box to run"
  cmdarg "c?" "command" "The command to run" "$DEFAULT_COMMAND"
  cmdarg "b?" "bind" "Bind mount the given directory inside the chroot before \
the command is run. Can be passed multiple times." "" \
    box_bind_validate
}


box.remove() {
  require_init

  box="`box_path "$name"`"
  [ -d "$box" ] || die "Box '$name' does not exist"

  rm "$box/binds"
  rm "$box/image"
  rmdir "$box"

  pnote "Successfully removed box '$name'."
}


box.remove::DESCR() {
  echo "deletes the given box."
}


box.remove::ARGS() {
  cmdarg "n:" "name" "The name of the box to delete"
}


register_command box.new
register_command box.clone
register_command box.dist
register_command box.import
register_command box.list
register_command box.run
register_command box.remove
