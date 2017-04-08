# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


get_factory() {
  local tgt="$mpoint/_factory/`ls -1 "$mpoint/_factory" | wc -l`.sh"

  cp "$path" "$tgt"

  local vers="`lbgrep "#:IMAGES " "\(.*\)" "$tgt" ||:`"
  if [ -n "$vers" ]; then
    [[ " $vers " =~ " $version " ]] || \
      die "Factory script $loc requires one of versions '$vers', but \
this box is being created with version '$version'."
  fi

  local nextloc
  while read -r nextloc; do
    [ -z "$nextloc" ] && continue
    load_factory "$mpoint" "$nextloc" "$version"
  done <<<"`lbgrep "#:DEPENDS " "\(.*\)" "$tgt" | tac`"
}


load_factory() {
  # load_factory mpoint loc version
  # Loads the factory at loc, as well as its dependencies into the given
  # mountpoint (storing as /_factory/0.sh, /_factory/1.sh, etc., in reverse
  # order of dependencies). Also verify that the factory is compatible with the
  # given image version.

  local mpoint="$1"
  local loc="$2"
  local version="$3"

  export loc mpoint version

  pnote "Loading factory $loc..."
  mkdir -p "$mpoint/_factory"
  with_location "$loc" get_factory "factory.sh"
}
