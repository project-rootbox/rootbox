# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


ALL_VERS="3.4 3.5"
DEFAULT_VER="3.5"

SETUP=setup.sh


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


print() {
  # print text...
  # Prints the given text, evaluating escape sequences.
  echo -ne "$@"
}


println() {
  # println text...
  # Like print, but resets formatting afterwards and adds a newline.
  echo -e "$@$C_R"
}


printfln() {
  # printfln format text...
  # Like printf, but adds a newline, but resets formatting afterwards and adds
  # a newline.
  fm="$1"
  shift
  printf "$fm$C_R\n" "$@"
}


pnote() {
  # pnote text...
  # Prints the given text, using the C_NOTE formatting.
  println "$C_NOTE$@"
}


perror() {
  # Prints the given text, using the C_ERROR formatting.
  println "$C_ERROR$@" >&2
}


ndie() {
  # ndie err-code [message...]
  # Exits with the given error code. If message was given, print it first.

  ret=$1
  shift
  [ "$#" -ne 0 ] && println "$@" >&2
  disable_errors
  exit $ret
}


quit() {
  # quit message...
  # Quits the program with return code 0 using C_NOTE formatting and the given
  # message.
  ndie 0 "$C_NOTE$@"
}


die() {
  # die message...
  # Quits the program with return code 1 using C_ERROR formatting and the given
  # message.
  ndie 1 "$C_ERROR$@"
}


internal() {
  # internal message...
  # Like die, but prefixes the text with INTERNAL ERROR.
  die "INTERNAL ERROR: $@"
}


pdebug() {
  # Used to print debug messages.
  printfln "$C_NOTE% 25s$CF_R :: %s" "${FUNCNAME[1]}" "$@" >&2
}


cmd_fail() {
  # Used to print debug messages.
  printfln "ERROR: $C_ERROR% 25s$CF_R :: %s" "${FUNCNAME[1]}" "$@" >&2
  exit 1
}


enable_debug() {
  # Enables verbose debugging.
  trap 'pdebug "$BASH_COMMAND"' DEBUG
}


enable_errors() {
  # Enables verbose error handlers.
  trap 'cmd_fail "$BASH_COMMAND exited with 1"' ERR
}


disable_errors() {
  # Disables verbose error handles (to allow a silent exit).
  trap - ERR
}


# SAFECALLS (a hacked-on bash variant of try ... finally).


# Trapchains are a sequence of commands to be run given a certain signal.
# They're like traps, but they allow commands to be stacked.


update_trapchain() {
  # update_trapchain sig
  # Updates the current trapchain.

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
  # trapchain func sig
  # Like 'trap func sig', but doesn't overwrite previous handlers in the
  # trapchain.

  local func="$1"
  local sig="$2"

  chain=TRAPCHAIN_$sig
  eval "$chain+=('$func')"
  update_trapchain $sig
}


trapchain_pop() {
  # trapchain_pop sig
  # Pops and executes the last trapchain handler for the given signal.

  local sig="$1"

  chain=TRAPCHAIN_$sig
  last=$chain[-1]
  local block="${!last}"
  unset $last

  update_trapchain $sig
  eval "$block"
}


safecall() {
  # safecall safe [del]
  # Roughly equivalent to:
  # try:
  #    safe
  # finally:
  #    del
  # If del is not specified, then safe is set to ${safe}_safecall, and del is
  # set to ${del}_safecall.

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
  # in_tmp block
  # Runs the given block inside a temporary directory.

  local block="$1"
  local dir=`mktempd "$TMP"`
  export block dir

  safecall in_tmp_safecall "in_tmp_del `proper_quote "$dir"`"
}


# MISC.


split() {
  # split str sep
  # Splits the given string by sep, and prints the output to stdout.
  local str="$1"
  local sep="$2"
  echo "$str" | awk "BEGIN { FS=\"$sep\"; } { print \$1\"\\n\"\$2; }"
}


join() {
  # join sep [args...]
  # Joins the given arguments using the given separator, and prints the result
  # to stdout.
  local sep="$1"
  shift
  local ret="${*/#/$sep}"
  echo ${ret#$sep}
}


lbgrep() {
  # lbgrep before match file
  # Matches the text using a pattern equivalent to `(?<=before)match`, printing
  # only the matching part (i.e. not the before part).

  local before="$1"
  local match="$2"
  local file="$3"

  grep -o "$before$match" "$file" | sed "s/^$before//g"
}


require_sparse() {
  # require_sparse dir
  # Ensures that the given path is on a file system that supports sparse files.

  dir="`realpath "$1"`"
  sparse_test="$dir/.sparse-test"
  rm -f "$sparse_test"
  truncate -s 4MB "$sparse_test"
  (( `du "$sparse_test" | cut -f1` == 0 )) || \
    die "Rootbox requires the workspace directory to be on a file system that \
supports sparse files."
  rm -f "$sparse_test"
}


require_init() {
  # require_init
  # Ensures that rootbox has been initialized.
  [ -e "$WORKSPACE" ] || die "Run 'rootbox init' to initialize rootbox."
  require_sparse "$WORKSPACE"
}


require_root() {
  # require_root
  # If the executor is not root, then aborts with an error message.
  [ "$EUID" -eq 0 ] || die ${1:-"This must be run as root!"}
}


download() {
  # download url target
  # Downloads the given url to the target file. If target is not specified,
  # then it will be deduced from the URL. Exits on download failure.

  local url="$1"
  local target="$2"

  [ -z "$target" ] && target=-O || target="-o$target"

  local ret=0
  curl "$target" -fL "$url" || ret=1
  echo
  return $ret
}


mktempd() {
  # mktempd dir
  # Like mktemp -d, but creates the temporary directory inside the given
  # directory.
  local dir="$1"
  mktemp -d "$dir/XXXXXXXXXX"
}


sudo_perm_fix() {
  # sudo_perm_fix path [perm=775]
  # If someone was executing this as sudo, then change the permissions of the
  # created files to the underlying user.
  local path="$1"
  local perm="${2:-775}"

  [ -n "$SUDO_USER" ] || return 0

  if [ -d "$path" ]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$path"
    chmod -R "$perm" "$path"
  else
    chown "$SUDO_USER:$SUDO_USER" "$path"
    chmod "$perm" "$path"
  fi
}


proper_quote() {
  # proper_quote str
  # Escape and quote the string with single quotes.

  local str="$1"
  echo "$str" | sed "s/'/'\"'\"'/g;s/^/'/;s/$/'/"
}
