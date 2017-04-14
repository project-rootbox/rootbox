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

  pdebug "url='$url'"

  pnote "Downloading from $url..."
  download "$url" "$path" || die "Invalid Git location $kind:$loc"

  local path="$PWD/$path"
  export path

  pdebug "path='$path'"

  cd "$origdir"
  eval "$wl_block"
}


with_location_url() {
  download "$loc" "_download"
  path="$PWD/_download"
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

  pdebug "@loc,wl_block,default: $*"

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
  url:*) loc="${loc#*:}"; kind=url ;;
  file:*) loc="${loc#*:}"; kind=file ;;
  *) kind=file ;;
  esac

  pdebug "kind='$kind' loc='$loc'"

  case "$kind" in
  git*)
    local repo
    local path
    local branch

    if [[ "$loc" =~ /// ]]; then
      split "$loc" "///" repo path
    else
      repo="$loc"
      path="$default"
    fi

    pdebug "repo='$repo' path='$path'"

    if [[ "$repo" == *@@* ]]; then
      split "$repo" "@@" repo branch
    else
      branch=master
    fi

    pdebug "branch='$branch'"

    export loc repo path branch wl_block origdir
    case "$kind" in
    git) in_tmp with_location_pure_git ;;
    *)   in_tmp with_location_git_hosted ;;
    esac ;;
  url)
    [[ "$loc" == */ ]] && loc="$loc/$default" ||:

    pdebug "loc='$loc'"

    export loc wl_block origdir
    in_tmp with_location_url ;;
  file)
    [ -d "$loc" ] && loc="$loc/$default" ||:
    [ -e "$loc" ] || die "Invalid file location $loc"

    local path="`realpath "$loc"`"

    pdebug "path='$path'"

    export path
    eval "$wl_block" ;;
  *) internal "invalid location kind $kind" ;;
  esac
}
