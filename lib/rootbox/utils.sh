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
  if [ `eval "echo $chainlen"` -eq 0 ]; then
    trap - $sig
  else
    trap "`join ' && ' "${!chainvar}"`" $sig
  fi
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
  last=$chain[-1]
  local block="${!last}"
  unset $last

  update_trapchain $sig
  eval "$block"
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
  trapchain_pop EXIT
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


with_mount_safecall() {
  imgmount "$img" "$mpoint"
  eval "$block"
}


with_mount_del() {
  local mpoint="$1"
  umount_if_mounted "$mpoint"
}


with_mount() {
  local img="$1"
  local block="$2"

  local mpoint="$img.mnt"
  [ -d "$mpoint" ] && umount_if_mounted "$mpoint"
  mkdir -p "$mpoint"

  export block img mpoint

  safecall with_mount_safecall "with_mount_del '$mpoint'"
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

  cd "$origdir"
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

  cd "$origdir"
  eval "$wl_block"
}


with_location() {
  local loc="$1"
  local wl_block="$2"
  local default="$3"
  local kind

  local origdir="$PWD"

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

    export loc repo path branch wl_block origdir
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


image_path() {
  echo "$IMAGES/alpine-$1.img"
}


box_path() {
  echo "$BOXES/$1.box"
}


imgmount() {
  image="$1"
  target="$2"
  mount -o loop -t ext4 "$image" "$target"
}


umount_if_mounted() {
  mount | grep -q "`realpath "$1"`" && umount -l "$1"
  rmdir "$1"
}


require_root() {
  [ "$EUID" -eq 0 ] || die ${1:-"This must be run as root!"}
}


with_bind_safecall() {
  eval "$block"
}


with_bind_del() {
  local path="$1"
  umount_if_mounted "$path"
}


with_bind() {
  local root="$1"
  local spec="$2"
  local block="$3"

  local bind target
  read -r bind target <<< `split "$spec" '///'`

  [ -n "$bind" ] && [ -n "$target" ] || die "Invalid bind mount spec '$spec'"

  local path="$root/$target"

  mkdir -p "$path"
  sudo mount --bind "$bind" "$path"

  export block
  safecall with_bind_safecall "with_bind_del '$path'"
}


with_binds_impl() {
  case "${#rest[@]}" in
  "0") internal "with_binds given no arguments" ;;
  "1")
    local block="${rest[0]}"
    eval "$block" ;;
  "2")
    local spec="${rest[0]}"
    local block="${rest[1]}"
    with_bind "$root" "$spec" "$block" ;;
  "3")
    local first_spec="${rest[0]}"
    rest=("${rest[@]:1}")
    export rest

    with_bind "$root" "$first_spec" with_binds_impl ;;
  esac
}


with_binds() {
  # with_binds root specs... block

  local root="$1"
  shift
  local rest=("$@")

  export root rest
  with_binds_impl
}


with_binds_unset_ifs() {
  unset IFS
  with_binds "$@"
}


in_chroot() {
  # in_chroot mpoint command bind-file other-binds...
  local mpoint="$1"
  local command="$2"
  local bind_file="$3"
  shift 3

  IFS=$'\n'
  with_binds_unset_ifs "$mpoint" `< "$bind_file"` "$@" \
                       "chroot '$mpoint' $command"
}
