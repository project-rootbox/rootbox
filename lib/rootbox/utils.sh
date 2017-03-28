# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


ALL_VERS="3.4 3.5"
DEFAULT_VER="3.5"


# COLORS, PRINTING, ERRORS, DEBUGGING

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
  [ "$#" -ne 0 ] && println "$@" >&2
  disable_errors
  exit $ret
}


quit() {
  ndie 0 "$C_NOTE$@"
}


die() {
  ndie 1 "$C_ERROR$@"
}


internal() {
  die "INTERNAL ERROR: $@"
}


pdebug() {
  printfln "$C_NOTE% 25s$CF_R :: %s" "${FUNCNAME[1]}" "$@" >&2
}


cmd_fail() {
  printfln "ERROR: $C_ERROR% 25s$CF_R :: %s" "${FUNCNAME[1]}" "$@" >&2
  exit 1
}


enable_debug() {
  trap 'pdebug "$BASH_COMMAND"' DEBUG
}


enable_errors() {
  trap 'cmd_fail "$BASH_COMMAND exited with 1"' ERR
}


disable_errors() {
  trap - ERR
}


# SAFECALLS (a hacked-on bash variant of try ... finally)


update_trapchain() {
  local sig="$1"

  chain=TRAPCHAIN_$sig
  chainlen=\${#$chain}
  chainvar=$chain[@]
  [ `eval "echo $chainlen"` -eq 0 ] || trap "`join ' && ' "${!chainvar}"`" $sig
}


trapchain() {
  local func="$1"
  local sig="$2"

  chain=TRAPCHAIN_$sig
  eval "$chain+=('$func')"
  update_trapchain $sig
}


trapchain_pop() {
  local sig="$1"

  chain=TRAPCHAIN_$sig
  unset $chain[-1]
  update_trapchain $sig
}


safecall() {
  if [ -z "$2" ]; then
    safe="$1_safecall"
    del="$1_del"
  else
    safe="$1"
    del="$2"
  fi

  trapchain "$del" EXIT
  eval "$safe"
  trapchain_pop
}


in_tmp_safecall() {
  local block="$1"
  local dir="$2"

  cd "$dir"
  eval "$block"
}


in_tmp_del() {
  local dir="$1"
  rm -rf "$dir"
}


in_tmp() {
  local block="$1"
  local dir=`mktemp -d "$TMP/XXXXXXXXXX"`
  export block dir

  safecall "in_tmp_safecall '$block' '$dir'" "in_tmp_del '$dir'"
}


# LOCATION LINKS

# e.g.
# git:user/repo        -> https://github.com/user/repo
# a/b                  -> file://$PWD/a/b
# /a/b                 -> file://a/b


with_location_pure_git() {
  git init
  git config core.sparseCheckout true
  echo "$path" > .git/info/sparse-checkout
  git pull "$repo" "$branch" --depth=1 || die "Invalid Git location $loc"
  [ -f "$path" ] || internal "$path not created via sparse checkout"

  path="`realpath "$PWD/$path"`"
  export path
  eval "$block"
}


with_location() {
  local loc="$1"
  local block="$2"
  local default="$3"
  local kind

  case "$loc" in
  git:*)
    if [[ "$loc" == *://* ]]; then
      kind=github
      loc="https://github.com/$loc"
    else
      kind=git
    fi ;;
  github:*) kind=github ;;
  gitlab:*) kind=gitlab ;;
  *) kind=file ;;
  esac

  case "$kind" in
  git*)
    local repo
    local path
    local branch

    if [[ "$loc" =~ [^:]// ]]; then
      read -r repo path <<< `split "$loc" "://"`
    else
      repo="$loc"
      path="$default"
    fi

    if [[ "$repo" == *@@* ]]; then
      local _
      read -r _ branch <<< `split "$repo" "@@"`
    else
      branch=master
    fi

    export loc repo path branch block
    in_tmp with_location_pure_git ;;
  file)
    [ -f "$loc" ] || die "Invalid file location $loc"
    local path="`realpath "$loc"`"
    export path
    eval "$block" ;;
  *) internal "invalid location kind $kind" ;;
  esac
}


# MISC.


split() {
  local str="$1"
  local sep="$2"
  echo "$str" | awk "BEGIN { FS=\"$sep\"; } { print \$1\"\\n\"\$2; }"
}


join() {
  local sep="$1"
  shift
  local ret="${*/#/$sep}"
  echo ${ret#$sep}
}


download() {
  url="$1"
  target="$2"

  [ -z "$target" ] && target=-O || target="-o$target"

  curl "$target" -fL "$url"
}


imgmount() {
  image="$1"
  target="$2"
  mount -o loop -t ext4 "$image" "$target"
}


require_root() {
  [ "$EUID" -eq 0 ] || die ${1:-"This must be run as root!"}
}
