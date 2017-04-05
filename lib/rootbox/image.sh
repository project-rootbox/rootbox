# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

DEFAULT_MIRROR="http://nl.alpinelinux.org/alpine/"

# Ommiting the backup superblocks significantly decreases the size of the
# sparse image file.
MKFS_OPTS="-t ext4 -F -Osparse_super,^has_journal -Enum_backup_sb=0"


create_tmp_image() {
  # create_tmp_image
  # Creates a bare, empty ext4 sparse image file of 128GB.
  # (On-disk, it will be more like 13MB or so.)

  pnote "Creating bare image..."

  truncate -s 128G "$tpath"
  mke2fs $MKFS_OPTS "$tpath"
}


image_setup() {
  # image_setup
  # Sets up the image version $version in the appropriate directory.

  local version="v$version"
  pnote "Downloading apk tools..."

  download "$mirror/$version/main/x86_64/APKINDEX.tar.gz"
  tar xvf APKINDEX.tar.gz
  apktools_ver=`grep -C1 apk-tools-static APKINDEX | tail -1 | cut -d: -f2`

  file="apk-tools-static-${apktools_ver}.apk"
  download "$mirror/$version/main/x86_64/$file" "$file"
  tar xzf "$file"

  pnote "Installing chroot into image..."
  sbin/apk.static -X "$mirror/$version/main" -U --allow-untrusted \
                  --root "$mpoint" --initdb add alpine-base

  mv "$tpath" "$path"
}


image.add() {
  require_init
  require_root

  local path="`image_path v$version`"
  local tpath="$path.tmp"
  [ -f "$path" ] && quit "Version $version was already downloaded"
  rm -rf "$path" "$tpath"

  export version mirror path

  create_tmp_image
  with_mount "$tpath" "in_tmp image_setup"
}


image.add::DESCR() {
  echo "downloads and installs the requested Alpine Linux image."
}


image.add::ARGS() {
  cmdarg "v:" "version" "The Alpine Linux version to use"
  cmdarg "m?" "mirror" "The Alpine Linux mirror to use" "$DEFAULT_MIRROR"
}


image.list() {
  require_init
  find "$IMAGES" -maxdepth 1 -name '*.img' -printf '%f\n' | \
    sed 's/alpine-v\([0-9].[0-9]\).img/\1/'
}


image.list::DESCR() {
  echo "lists all the installed Alpine Linux images."
}


image.list::ARGS() {
  :
}


image.remove() {
  require_init
  require_root

  local path="`image_path v$version`"
  [ -f "$path" ] || die "Version $version is not yet installed"
  [ -d "$path.mnt" ] && umount_if_mounted "$path.mnt"
  rm -f "$path.tmp" || true
  rm "$path"

  pnote "Successfully removed image '$version'."
}


image.remove::DESCR() {
  echo "deletes the requested Alpine Linux image."
}


image.remove::ARGS() {
  cmdarg "v:" "version" "The Alpine Linux version to remove"
}


register_command image.add
register_command image.list
register_command image.remove
