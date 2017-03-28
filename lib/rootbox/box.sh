# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


load_factory() {
  echo "$path"
}


box.new() {
  if [ -n "$factory" ]; then
    pnote "Using image factory $factory..."
    with_location "$factory" load_factory "factory.sh"
  fi
}


box.new::DESCR() {
  echo "creates a new box using the given Alpine Linux image."
}


box.new::ARGS() {
  cmdarg "v?" "version" "The Alpine Linux version to use" "$DEFAULT_VER"
  cmdarg "f?" "factory" "The image factory to use"
}


register_command box.new
