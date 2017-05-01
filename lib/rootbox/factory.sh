# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


DOWNLOADED_HASHES=()


get_factory() {
  local sha="`sha1sum "$path" | tr ' ' '\t' | cut -f1`"
  pdebug "@path=$path,sha=$sha,DOWNLOADED_HASHES=${DOWNLOADED_HASHES[@]}"
  if [[ " ${DOWNLOADED_HASHES[@]} " =~ " $sha " ]]; then
    pnote "NOTE: skipping because this factory has already been downloaded..."
    return 0
  fi

  DOWNLOADED_HASHES+=("$sha")

  local tgt="$mpoint/_factory/`ls -1 "$mpoint/_factory" | wc -l`.sh"
  pdebug "@tgt='$tgt'"

  cp "$path" "$tgt"

  local vers="`lbgrep "#:IMAGES " "\(.*\)" "$tgt" ||:`"
  pdebug "vers='$vers' version='$version'"
  if [ -n "$vers" ]; then
    [[ " $vers " =~ " $version " ]] || \
      die "Factory script $loc requires one of versions '$vers', but \
this box is being created with version '$version'."
  fi

  local nextloc
  while read -r nextloc; do
    [ -z "$nextloc" ] && continue
    pdebug "nextloc='$nextloc'"
    load_factory "$mpoint" "$nextloc" "$version"
  done <<<"`lbgrep "#:DEPENDS " "\(.*\)" "$tgt" | tac`"
}


load_factory() {
  # load_factory mpoint loc version
  # Loads the factory at loc, as well as its dependencies into the given
  # mountpoint (storing as /_factory/0.sh, /_factory/1.sh, etc., in reverse
  # order of dependencies). Also verify that the factory is compatible with the
  # given image version. If the factory's hash is already in DOWNLOADED_HASHES,
  # then it will not be re-downloaded.

  local mpoint="$1"
  local loc="$2"
  local version="$3"

  export loc mpoint version

  pnote "Loading factory $loc..."
  with_location "$loc" get_factory "factory.sh"
}


FACTORY_ALL_CODE=`cat <<EOF
cd /home/user
ls -1 /_factory/?.sh | sort -r | xargs -n1 /bin/ash
EOF
`

setup_factories() {
  # setup_factories mpoint loc version
  # Sets up all the factories from loc inside $mpoint/_factory.

  local mpoint="$1"
  local loc="$2"
  local version="$3"

  mkdir -p "$mpoint/_factory"
  echo "$FACTORY_ALL_CODE" > "$mpoint/_factory/_all.sh"
  load_factory "$mpoint" "$loc" "$version"
}
