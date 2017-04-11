# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


DEFAULT_COMMAND="/bin/ash -i"


box_actual_setup() {
  # box_actual_setup
  # Runs /bin/ash inside the chroot, with all the bind mounts setup, which
  # will in turn execute the factory script if it was present.

  in_chroot "$mpoint" root "/bin/ash /$SETUP" "Failed to setup box" \
            "$tbox/binds"
}


box_setup() {
  # box_setup
  # Sets up the box $tbox using the image factory location in $factory.

  if [ -n "$factory" ]; then
    load_factory "$mpoint" "$factory" "$version"
  fi

  safecall box_actual_setup \
    "rm -rf `proper_quote "$mpoint/_factory"` `proper_quote "$mpoint/$SETUP"`"
}


fix_box_permissions() {
  local box="$1"

  sudo_perm_fix "$box"
  sudo_perm_fix "$box/binds" 664
  sudo_perm_fix "$box/image" 664
}


box.new() {
  require_init
  require_root

  local image="`image_path "v$version"`"
  local box="`box_path "$name"`"
  local tbox="$box.tmp"  # Temporary box path.

  export box tbox factory version

  [ ! -d "$box" ] || die "Box '$name' has already been created"
  [ -f "$image" ] || die "Image $version is not yet installed"

  pnote "Creating box..."

  mkdir -p "$tbox"

  echo -e `join "\n" "${bind[@]}"` > "$tbox/binds"
  cp --sparse=always "$image" "$tbox/image"

  pnote "Setting up box..."
  with_mount "$tbox/image" box_setup

  pnote "Saving box..."
  fix_box_permissions "$tbox"
  mv "$tbox" "$box"
  fix_box_permissions "$box" ||:

  pnote "Setup successful!"

  if [ "$run" == "true" ]; then
    "$0" box.run "$name"
  fi
}


box.new::DESCR() {
  echo "creates a new box using the given Alpine Linux image."
}


box.new::ARGS() {
  add_positional "name" "The name of the new box"
  add_positional "bind" "Set the given directory to be automatically bind \
mounted whenever the box is run. Can be passed multiple times." nargs=*
  add_value_flag "v" "version" "The Alpine Linux version to use" "$DEFAULT_VER"
  add_value_flag "f" "factory" "The location path of the image factory to use" \
                 ""
  add_bool_flag "r" "run" "Run the box after creation"
}


box.clone() {
  require_init

  local srcbox="`box_path "$source"`"
  [ -d "$srcbox" ] || die "Box '$source' does not exist"

  local dstbox="`box_path "$name"`"
  [ ! -d "$dstbox" ] || die "Box '$name' has already been created"

  pnote "Cloning box..."

  cp --sparse=always -r "$srcbox" "$dstbox"
  fix_box_permissions "$dstbox"

  pnote "Clone was successful!"
}


box.clone::DESCR() {
  echo "clones the given box."
}


box.clone::ARGS() {
  add_positional "source" "The name of the box to clone"
  add_positional "name" "The name of the new box"
}


box.dist() {
  require_init

  local box="`box_path "$name"`"
  [ -d "$box" ] || die "Box '$name' does not exist"

  pnote "Exporting box..."

  local taropts compress_ext
  case "$compress" in
  gzip) taropts=-z; compress_ext=.gz ;;
  bzip2) taropts=-y; compress_ext=.bz2 ;;
  none) ;;
  esac

  [ "$output" == '$name.box' ] && output="$name.box$compress_ext" ||:

  bsdtar cf "$output" -C "$box" $taropts binds image
  sudo_perm_fix "$output" 664

  pnote "Successfully exported box to '$output'!"
}


box.dist::DESCR() {
  echo "exports the given box for distribution."
}


box.dist::ARGS() {
  add_positional "name" "The name of the box to export"
  add_value_flag "o" "output" "The output file" '$name.box'
  add_value_flag "c" "compress" "Compress the result with the given \
compression method (Valid values: none, bzip2, gzip)" "none" \
    "choices=none|bzip2|gzip"
}


import_box() {
  pnote "Importing box..."
  tar xf "$path" -C "$tbox"
}


box.import() {
  require_init

  local box="`box_path "$name"`"
  local tbox="$box.tmp"
  export box

  [ ! -d "$box" ] || die "Box '$name' has already been created"

  pnote "Setting up import..."
  mkdir -p "$tbox"

  with_location "$loc" import_box dist.box
  fix_box_permissions "$tbox"
  mv "$tbox" "$box"

  pnote "Successfully imported box '$name'!"
}


box.import::DESCR() {
  echo "imports an exported box into the Rootbox workspace."
}


box.import::ARGS() {
  add_positional "loc" "The location path of the box to import"
  add_positional "name" "The name of the new box"
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

  if [ "$x11" == "true" ]; then
    [ -n "$DISPLAY" ] || die '$DISPLAY is empty!'

    while read -r cookie; do
      xauth extract "$mpoint/root/.Xauthority" "$cookie"
      xauth extract "$mpoint/home/user/.Xauthority" "$cookie"
      sudo_perm_fix "$mpoint/home/user/.Xauthority" 644
    done <<<"`xauth list "$DISPLAY" | cut "-d " -f1`"

    bind+=("/tmp/.X11-unix///tmp/.X11-unix")
    command="export DISPLAY=$DISPLAY; $command"
  fi

  in_chroot "$mpoint" "$user" "$command" "" "$box/binds" "${bind[@]}"
}


box.run() {
  require_init
  require_root

  local box="`box_path "$name"`"
  [ -d "$box" ] || die "Box '$name' does not exist"

  export box command user x11
  with_mount "$box/image" box_run_command
}


box.run::DESCR() {
  echo "runs the command inside the given box."
}

box.run::ARGS() {
  add_positional "name" "The name of the box to run"
  add_positional "bind" "Bind mount the given directory inside the chroot \
before the command is run. Can be passed multiple times." nargs=*
  add_bool_flag "x" "x11" "Add X11 support upon startup"
  add_value_flag "c" "command" "The command to run" "$DEFAULT_COMMAND"
  add_value_flag "u" "user" "The user to use inside the chroot" "user"
}


box.remove() {
  require_init

  local box="`box_path "$name"`"
  [ -d "$box" ] || die "Box '$name' does not exist"

  rm -f "$box/binds"
  rm -f "$box/image"
  rmdir "$box"

  pnote "Successfully removed box '$name'."
}


box.remove::DESCR() {
  echo "deletes the given box."
}


box.remove::ARGS() {
  add_positional "name" "The name of the box to delete"
}


register_command box.new
register_command box.clone
register_command box.dist
register_command box.import
register_command box.list
register_command box.run
register_command box.remove
