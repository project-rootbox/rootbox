main() {
  [ -n "$ROOTBOX_DEBUG" ] && set -x

  if [[ -n "$1" && "$1" != -* ]]; then
    run_command "$@"
  else
    run_no_command "$@"
  fi
}
