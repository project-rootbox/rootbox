# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


FACTORY="_factory.sh"


load_factory() {
  cp "$path" "$mpoint/$FACTORY"
}


box_actual_setup() {
  in_chroot "$mpoint" "/bin/ash -c '[ -f /_$FACTORY ] && /$FACTORY || :'" \
            "$tbox/binds"
}


box_setup() {
  if [ -n "$factory" ]; then
    pnote "Using image factory $factory..."
    with_location "$factory" load_factory "factory.sh"
  fi

  safecall box_actual_setup "rm -f '$mpoint/$FACTORY'"
}


box.new() {
  require_root

  image="`image_path "v$version"`"
  box="`box_path "$name"`"
  tbox="$box.tmp"

  export box tbox factory

  [ ! -d "$box" ] || die "Box '$box' has already been created"
  [ -f "$image" ] || die "Version $version is not yet installed"

  pnote "Creating box..."

  mkdir -p "$tbox"

  echo -e `join "\n" ${bind[@]}` > "$tbox/binds"
  cp --sparse=always "$image" "$tbox/image"

  pnote "Setting up box..."
  with_mount "$tbox/image" box_setup

  pnote "Saving box..."
  mv "$tbox" "$box"
}


box.new::DESCR() {
  echo "creates a new box using the given Alpine Linux image."
}


create_fake_validator box_bind


box.new::ARGS() {
  cmdarg "n:" "name" "The name of the new box"
  cmdarg "v?" "version" "The Alpine Linux version to use" "$DEFAULT_VER"
  cmdarg "f?" "factory" "The image factory to use"
  cmdarg "b?" "bind" "Set the given directory to be automatically bind \
mounted whenever the box is run. Can be passed multiple times." "" \
    box_bind_validate
}


register_command box.new
