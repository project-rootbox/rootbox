# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

main() {
  [ -n "$ROOTBOX_DEBUG" ] && enable_debug

  if [[ -n "$1" && "$1" != -* ]]; then
    run_command "$@"
  else
    run_no_command "$@"
  fi
}
