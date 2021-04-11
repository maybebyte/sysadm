# shellcheck disable=SC2154
# 'common.sh' is a file with frequently used functions. its purpose is
# to be sourced in scripts for readability purposes and ease of
# management. therefore, it has no shebang and isn't executable.

# instead of remembering/accounting for two different forms of privilege
# elevation, one is assigned to the alias 'priv.' doas is preferred over
# sudo.
if [ -x "$(command -v doas)" ]; then
  alias priv='doas '
elif [ -x "$(command -v sudo)" ]; then
  alias priv='sudo '
fi

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
  [ "$(id -u)" = 0 ] || err "Execute ${0##*/} with root privileges."
}

# print date in yyyy-mm-dd format.
today() { date '+%Y-%m-%d'; }

# if the number of arguments isn't equal to the number needed, print the
# usage details to STDERR and exit.
arg_eq() {
  [ "$#" -eq "${arguments_needed}" ] || err "${usage_details}"
}

# if the number of arguments isn't greater than or equal to the number
# needed, print the usage details to STDERR and exit.
arg_ge() {
  [ "$#" -ge "${arguments_needed}" ] || err "${usage_details}"
}
