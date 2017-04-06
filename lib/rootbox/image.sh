# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# https://wiki.alpinelinux.org/wiki/Installing_Alpine_Linux_in_a_chroot

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


RESOLV_CONF=`cat <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 2001:4860:4860::8888
nameserver 2001:4860:4860::8844
EOF
`


SETUP_CODE=`cat <<EOF
#!/bin/ash

rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add mdev sysinit

rc-update add mount-ro shutdown
rc-update add killprocs shutdown
rc-update add savecache shutdown

apk update

if [ -d /_factory ]; then
  ls -1 /_factory/*.sh | sort -r | xargs -n1 /bin/ash
fi

EOF
`


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
                  --root "$mpoint" --initdb add $packages

  pnote "Making final image adjustments..."
  mkdir -p "$mpoint/root"
  mkdir -p "$mpoint/etc/apk"

  echo "$RESOLV_CONF" > "$mpoint/etc/resolv.conf"
  echo "$mirror/$version/main" > "$mpoint/etc/apk/repositories"
  echo "$mirror/$version/community" >> "$mpoint/etc/apk/repositories"
  echo "$SETUP_CODE" > "$mpoint/$SETUP"

  mv "$tpath" "$path"
}


image.add() {
  require_init
  require_root

  local packages verstr

  if [ "$slim" == "true" ]; then
    packages=alpine-base
    verstr="${version}-nodev"
  else
    packages="alpine-base alpine-sdk"
    verstr="$version"
  fi

  local path="`image_path v$verstr`"
  local tpath="$path.tmp"
  [ -f "$path" ] && quit "Version $verstr was already downloaded"
  rm -rf "$path" "$tpath"

  export version mirror path packages

  create_tmp_image
  with_mount "$tpath" "in_tmp image_setup"

  pnote "Image creation successful!"
}


image.add::DESCR() {
  echo "downloads and installs the requested Alpine Linux image."
}


image.add::ARGS() {
  cmdarg "v:" "version" "The Alpine Linux version to use"
  cmdarg "m?" "mirror" "The Alpine Linux mirror to use" "$DEFAULT_MIRROR"
  cmdarg "s" "slim" "Don't install the development packages. The resulting \
image can later be referenced via version-nodev; e.g., 3.5-nodev."
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
  rm -f "$path.tmp" || :
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
