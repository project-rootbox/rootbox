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

  safecall in_tmp_safecall "in_tmp_del '$dir'"
}


# LOCATION LINKS


with_location_pure_git() {
  pnote "Downloading repo $repo with branch $branch..."

  git init
  git config core.sparseCheckout true
  echo "$path" > .git/info/sparse-checkout

  git pull "$repo" "$branch" --depth=1 || die "Invalid Git location $loc"
  [ -f "$path" ] || internal "$path not created via sparse checkout"

  path="`realpath "$PWD/$path"`"
  export path
  eval "$wl_block"
}


with_location_git_hosted() {
  mkdir -p "`dirname $path`"
  case "$kind" in
  github) url="https://raw.githubusercontent.com/$repo/$branch/$path" ;;
  gitlab) url="https://gitlab.com/$repo/raw/$branch/`basename $repo`/$path" ;;
  *) internal "Invalid Git kind $kind" ;;
  esac

  pnote "Downloading from $url..."
  download "$url" "$path" || die "Invalid Git location $loc"

  local path="$PWD/$path"
  export path
  eval "$wl_block"
}


with_location() {
  local loc="$1"
  local wl_block="$2"
  local default="$3"
  local kind

  case "$loc" in
  git:*)
    loc="${loc#*:}"
    if [[ "$loc" == *://* ]]; then
      kind=git
    else
      kind=github
    fi ;;
  github:*) loc="${loc#*:}"; kind=github ;;
  gitlab:*) loc="${loc#*:}"; kind=gitlab ;;
  file:*) loc="${loc#*:}"; kind=file ;;
  *) kind=file ;;
  esac

  case "$kind" in
  git*)
    local repo
    local path
    local branch

    if [[ "$loc" =~ /// ]]; then
      read -r repo path <<< `split "$loc" "///"`
    else
      repo="$loc"
      path="$default"
    fi

    if [[ "$repo" == *@@* ]]; then
      read -r repo branch <<< `split "$repo" "@@"`
    else
      branch=master
    fi

    export loc repo path branch wl_block
    case "$kind" in
    git) in_tmp with_location_pure_git ;;
    *)   in_tmp with_location_git_hosted ;;
    esac ;;
  file)
    [ -d "$loc" ] && loc="$loc/$default" || true
    [ -e "$loc" ] || die "Invalid file location $loc"

    local path="`realpath "$loc"`"
    export path
    eval "$wl_block" ;;
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
  echo
}


imgmount() {
  image="$1"
  target="$2"
  mount -o loop -t ext4 "$image" "$target"
}


require_root() {
  [ "$EUID" -eq 0 ] || die ${1:-"This must be run as root!"}
}
