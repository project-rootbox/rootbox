# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


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
  # with_location loc block default
  # Grabs the file from the given location and calls the given block,
  # with the environment variable $path set to the path to the file location.
  # If the location is a directory, then default will be appended as the default
  # file name.

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
