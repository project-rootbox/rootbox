# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

. `dirname $0`/../lib/rootbox/cmdarg/cmdarg.sh


# HOW COMMANDS WORK:

# A command is registered using register_command. There should be three
# functions defined associated with the command:

# ${command}            - Runs the given command.
# ${command}::ARGS      - Registers the command's arguments with cmdarg.
# #{command}::DESCR     - Prints a description of the command to stdout.

# After the arguments are parsed, the function named after the command (the
# first one in the list) will be called, with all the arguments loaded into
# variables. For instance, box.new will be called with the variable $name
# pre-created, corresponding to the --name argument.


collect_command_info() {
  # collect_command_info
  # Prints information about all the registered commands.

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
  # register_command name
  # Registers the given command.
  local name="$1"
  COMMANDS+=("$name")
}


show_licenses() {
  # show_licenses
  # Prints the licenses to stdout, as well as optionally printing the FULL
  # license text if requested.

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
  # run_no_command
  # Runs rootbox without a command.

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
  # run_command cmd
  # Runs the given command (what else did you think it'd do?).

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
    eval "local $key=`proper_quote "${cmdarg_cfg[$key]}"`"
  done
  eval "export ${!cmdarg_cfg[@]}"

  eval $cmd
}


create_fake_validator() {
  # create_fake_validator name
  # Creates an array ${name}_values and a function ${name}_validate. When
  # ${name}_validate is called, it appends its argument to ${name}_values and
  # returns 0. This is used to implement cumulative arguments, since cmdarg's
  # array arguments don't work correctly on certain bash versions.

  eval "declare -ga $1_values"
  eval "$1_validate() { $1_values+=(\"\$1\"); return 0; }"
}
