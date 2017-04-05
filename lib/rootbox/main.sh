# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


check_exe() {
  local msg=${2:-"$1 is required"}
  which "$1" 2>&1 >/dev/null || die "$msg"
}


integrity_check() {
  check_exe curl
  check_exe cp
  check_exe less
  check_exe truncate
  check_exe mke2fs
  check_exe mount
  check_exe mkdir
  check_exe find
  check_exe sed
  check_exe tar "tar is required to be able to create images and unpack boxes"
  check_exe bsdtar "bsdtar is required to be able to distribute boxes"
  check_exe chmod
  check_exe chown
  check_exe awk

  (( ${BASH_VERSINFO[0]} >= 4 )) || die "bash >= 4.3 is requried"
  (( ${BASH_VERSINFO[1]} >= 3 )) || die "bash >= 4.3 is requried"
}


main() {
  [ "$ROOTBOX_DEBUG" == "1" ] && enable_debug
  enable_errors

  integrity_check

  if [[ -n "$1" && "$1" != -* ]]; then
    run_command "$@"
  else
    run_no_command "$@"
  fi
}
