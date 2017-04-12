# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


image_path() {
  # image_path version
  # Prints the full path to the image for the given Alpine Linux version.
  echo "$IMAGES/alpine-$1.img"
}


box_path() {
  # box_path box
  # Prints the full path to the box with the given name.
  echo "$BOXES/$1.box"
}


imgmount() {
  # imgmount image target
  # Loop-mounts the given ext4 image to the target directory.
  image="$1"
  target="$2"

  pdebug "@image,target: $*"

  mount -o loop -t ext4 "$image" "$target"
}


umount_if_mounted() {
  # umount_if_mounted dir
  # If the given directory is a loop or bind mount, then unmount it, and delete
  # the directory.
  mount | grep -q "`realpath "$1"`" && umount -l "$1"
  # XXX: Special-case /dev.
  [ "`basename $1`" != "dev" ] && rmdir "$1" ||:
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
  # with_mount img block
  # Mounts the given image to an unspecified mount point, and calls the given
  # blocks with the environment variable $mpoint set to the mount point.
  local img="$1"
  local block="$2"

  local mpoint="`mktempd $MNT`"
  pdebug "@img,block: $* [mpoint=$mpoint]"
  [ -d "$mpoint" ] && umount_if_mounted "$mpoint"
  mkdir -p "$mpoint"

  export block img mpoint

  safecall with_mount_safecall "with_mount_del `proper_quote "$mpoint"`"
}


with_bind_safecall() {
  eval "$block"
}


with_bind_del() {
  local path="$1"
  umount_if_mounted "$path"
}


with_bind() {
  # with_bind root spec block
  # Mounts the given bind mount spec to $root/$bind_target, with bind_target
  # being taken from the spec, then calls the block.
  local root="$1"
  local spec="$2"
  local block="$3"

  pdebug "@root,spec,block: $*"

  local bind target
  read -r bind target <<< `split "$spec" '///'`

  pdebug "bind='$bind' target='$target'"
  [ -n "$bind" ] && [ -n "$target" ] || die "Invalid bind mount spec '$spec'"

  local path="$root/$target"
  pdebug "path='$path'"

  mkdir -p "$path"
  sudo mount --bind "$bind" "$path"

  export block
  safecall with_bind_safecall "with_bind_del `proper_quote "$path"`"
}


with_binds_impl() {
  case "${#rest[@]}" in
  "0") internal "with_binds given no arguments" ;;
  "1")
    local block="${rest[0]}"
    pdebug "@1 arg: <block>"
    eval "$block" ;;
  "2")
    local spec="${rest[0]}"
    local block="${rest[1]}"
    pdebug "@2 args: spec=$spec <block>"
    with_bind "$root" "$spec" "$block" ;;
  *)
    local first_spec="${rest[0]}"
    rest=("${rest[@]:1}")
    export rest

    pdebug "@* args: first_spec=$first_spec ..."
    with_bind "$root" "$first_spec" with_binds_impl ;;
  esac
}


with_binds() {
  # with_binds root specs... block
  # Like with_bind, but takes multiple bind specs.

  local root="$1"
  shift
  local rest=("$@")

  export root rest
  with_binds_impl
}


with_binds_unset_ifs() {
  # Like with_binds, but unsets IFS first.
  unset IFS
  with_binds "$@"
}


in_chroot_enter() {
  [ -n "$failure" ] && onfail=die || onfail="ndie 1"

  chroot "$mpoint" \
    /usr/bin/env -i \
    TERM="$TERM" \
    PATH=/usr/local/bin:/usr/sbin/usr/bin:/sbin:/bin \
    su -lc "$command" "$user" || $onfail "$failure"
}


in_chroot() {
  # in_chroot mpoint user command failure-message bind-file other-binds...
  # Runs the given command inside the chroot at mpoint under the given user,
  # using bind-file as the bind spec file as other-binds as a sequence of more
  # bind specs. Failure-message, if not empty, will be printing upon command
  # failure.

  pdebug "@mpoint,user,command,failure,bind: $*"

  local mpoint="$1"
  local user="$2"
  local command="$3"
  local failure="$4"
  local bind_file="$5"
  shift 5

  export mpoint user command failure

  IFS=$'\n'
  with_binds_unset_ifs "$mpoint" `< "$bind_file"` "$@" \
                       /dev///dev /sys///sys /proc///proc \
                       in_chroot_enter
}
