# shellcheck disable=SC2154 shell=sh
# 'common.sh' is a file with frequently used functions. its purpose is
# to be a collection of tools that can be easily referenced. keeping
# frequently used functions in one place ensures a certain level of
# consistency.

# instead of remembering/accounting for two different forms of privilege
# elevation, one is assigned to the alias 'priv.' doas is preferred over
# sudo.
if [ -x "$(command -v 'doas')" ]; then
  alias priv='doas '

elif [ -x "$(command -v 'sudo')" ]; then
  alias priv='sudo '

fi


# reads from STDIN and checks that all commands needed are executable
# and available.
#
# note that I only check executables that aren't accounted for in dotfiles.
check_deps() {
  while read -r dependency; do

    [ -x "$(command -v -- "${dependency}")" ] \
      || err "${dependency} not found in PATH or not executable."

  done
}


# err() is the generic way to print an error message and exit a script.
# all of its output goes to STDERR.
#
# print everything passed as an argument.
# exit with a return code of 1.
err() {
  printf '%s\n' "$*" >&2
  exit 1
}


# if the user isn't root, print an error message and exit.
must_be_root() {
  [ "$(id -u)" -eq 0 ] || err "Execute ${0##*/} with root privileges."
}
