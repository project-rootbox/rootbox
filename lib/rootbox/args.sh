# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

. `dirname $0`/../lib/rootbox/argparser/argparser


# HOW COMMANDS WORK:

# A command is registered using register_command. There should be three
# functions defined associated with the command:

# ${command}            - Runs the given command.
# ${command}::ARGS      - Registers the command's arguments with argparser.
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


add_bool_flag() {
  # add_bool_flag short long help [options...]
  # Adds the given boolean flag to the argparser parser.

  local short="$1"
  local long="$2"
  local help="$3"
  shift 3

  argparser_add_arg "--$long" "-$short" "desc=$help" \
                    default=false const=true nargs=0 "$@"
}


add_value_flag() {
  # add_value_flag short long help default [options...]
  # Adds the given value flag to the argparser parser.

  local short="$1"
  local long="$2"
  local help="$3"
  local default="$4"
  shift 4

  argparser_add_arg "--$long" "-$short" "desc=$help (Default: \"$default\")" \
                    "default=$default" nargs=1 "$@"
}


add_positional() {
  # add_positional name help [options...]
  # Adds the given positional argument to the argparser parser.

  local name="$1"
  local help="$2"
  shift 2

  argparser_add_arg "$name" "desc=$help" nargs=1 "metavar=<$name>" "$@"
}


show_licenses() {
  # show_licenses
  # Prints the licenses to stdout, as well as optionally printing the FULL
  # license text if requested.

  echo "Rootbox is (c) 2017 Ryan Gonzalez and is licensed under the \
Mozilla Public License 2.0."
  echo "Rootbox embeds argparser, which is (c) 2016 Ekeyme Mo and is licensed \
under the MIT license."

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


init_argparser() {
  local prefix="$1"
  argparser "$prefix" "desc=$ROOTBOX_HEADER"
}


generic_command_setup() {
  add_bool_flag "D" "debug" "Print each shell command as it's executed."
  add_bool_flag "L" "license" "Show the license."

  disable_errors
  argparser_parse "$@"
  enable_errors

  [ "$debug" == "true" ] && enable_debug || true
  [ "$license" == "true" ] && show_licenses || true
}


run_no_command() {
  # run_no_command
  # Runs rootbox without a command.

  ROOTBOX_HEADER+=$(cat <<EOF


Valid commands are:

`collect_command_info`
EOF
  )

  init_argparser "`basename $0` <command> <command-specific arguments>"
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


$cmd `eval ${cmd}::DESCR`
EOF
  )

  init_argparser "`basename $0` $cmd"
  eval ${cmd}::ARGS
  generic_command_setup "$@"

  eval $cmd
}
