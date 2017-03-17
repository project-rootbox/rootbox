ndie() {
  ret=$1
  shift
  [ "$#" -ne 0 ] && echo "$@" >&2
  exit $ret
}


quit() {
  ndie 0 "$@"
}


die() {
  ndie 1 "$@"
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
