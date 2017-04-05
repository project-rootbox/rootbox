# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

. `dirname $0`/../lib/rootbox/cmdarg/cmdarg.sh


collect_command_info() {
  for cmd in "${COMMANDS[@]}"; do
    printf '    %-15s - ' $cmd
    eval ${cmd}::DESCR
  done
}


ROOTBOX_HEADER=$(cat <<EOF
rootbox is a set of scripts that makes it easy to create and distribute Alpine \
Linux-based chroots for development purposes.

EOF
)


declare -a COMMANDS


register_command() {
  local name="$1"
  COMMANDS+=("$name")
}


show_licenses() {
  echo "Rootbox is (c) 2017 Ryan Gonzalez and is licensed under the \
Mozilla Public License 2.0."
  echo "Rootbox embeds cmdarg, which is (c) 2013 Andrew Kesterson and is \
licensed under the MIT license."

  while [ "$answer" != "y" ] && [ "$answer" != "n" ]; do
    echo -n "Show full license text? [y/n] "
    read answer
  done

  if [ "$answer" == "y" ]; then
    cd "`dirname $0`/../lib/rootbox"
    echo | cat LICENSE - LICENSE-THIRD-PARTY | less
  fi

  quit
}


generic_command_setup() {
  cmdarg_info "header" "$ROOTBOX_HEADER"
  cmdarg_info "copyright" "(C) 2017"
  cmdarg_info "author" "Ryan Gonzalez"
  cmdarg "D" "debug" "Print each shell command as it's executed."
  cmdarg "L" "license" "Show the license."
  disable_errors

  cmdarg_parse "$@"

  enable_errors

  [ "${cmdarg_cfg['debug']}" == "true" ] && enable_debug || true
  [ "${cmdarg_cfg['license']}" == "true" ] && show_licenses || true
}


run_no_command() {
  ROOTBOX_HEADER+=$(cat <<EOF


usage: `basename $0` <command> [<args>]

Valid commands are:

`collect_command_info`
EOF
  )

  generic_command_setup "$@"
  die "A command is required!"
}


run_command() {
  local cmd="$1"
  shift

  [[ " ${COMMANDS[@]} " =~ " $cmd " ]] || \
    die "Invalid command '$cmd'; use --help for help"
  ROOTBOX_HEADER+=$(cat <<EOF


usage: `basename $0` $cmd [<args>]

$cmd `eval ${cmd}::DESCR`
EOF
  )
  eval ${cmd}::ARGS

  generic_command_setup "$@"

  for key in "${!cmdarg_cfg[@]}"; do
    eval "local $key=${cmdarg_cfg[$key]}"
  done
  eval "export ${!cmdarg_cfg[@]}"

  eval $cmd
}


# Workaround a bug in Bash 4.3 with cmdarg's array arguments.
create_fake_validator() {
  eval "declare -ga $1_values"
  eval "$1_validate() { $1_values+=(\"\$1\"); return 0; }"
}
