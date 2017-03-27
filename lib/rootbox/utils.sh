# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


_add_color() {
  eval "$1=\\\\033[$2m"
}

_add_color C_R 0  # Reset
_add_color C_B 1  # Bold
_add_color CF_RED 31
_add_color CF_GREEN 32
_add_color CF_BLUE 34
_add_color CF_CYAN 36
_add_color CF_R 39

C_NOTE="$C_B$CF_CYAN"
C_ERROR="$C_B$CF_RED"


c_reset() {
  echo -ne "$C_R"
}


print() {
  echo -ne "$@"
}


println() {
  echo -e "$@$C_R"
}


printfln() {
  fm="$1"
  shift
  printf "$fm$C_R\n" "$@"
}


pnote() {
  println "$C_NOTE$@"
}


perror() {
  println "$C_ERROR$@"
}


ndie() {
  ret=$1
  shift
  [ "$#" -ne 0 ] && perror "$@" >&2
  exit $ret
}


quit() {
  ndie 0 "$@"
}


die() {
  ndie 1 "$@"
}


pdebug() {
  printfln "$C_B$CF_CYAN% 25s$CF_R :: %s" "${FUNCNAME[1]}" "$@" >&2
}


enable_debug() {
  trap 'pdebug "CMD $BASH_COMMAND"' DEBUG
}


safecall() {
  if [ -z "$2" ]; then
    safe="$1_safecall"
    del="$1_del"
  else
    safe="$1"
    del="$2"
  fi

  (eval "$safe") && ret=0 || ret=$?
  (eval "$del") || true
  exit "$ret"
}


in_tmp_safecall() {
  cd "$dir"
  eval "$block"
}


in_tmp_del() {
  rm -rf "$dir"
}


in_tmp() {
  local block="$1"
  local dir=`mktemp -d "$TMP/XXXXXXXXXX"`
  export block dir

  safecall in_tmp
}


download() {
  url="$1"
  target="$2"

  [ -z "$target" ] && target=-O || target="-o$target"

  curl "$target" -L "$url"
}


imgmount() {
  image="$1"
  target="$2"
  mount -o loop -t ext4 "$image" "$target"
}


require_root() {
  [ "$EUID" -eq 0 ] || die ${1:-"This must be run as root!"}
}
