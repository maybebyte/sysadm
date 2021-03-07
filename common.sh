# 'common.sh' is a file with frequently used functions that may be sourced
# for readability purposes

if command -v doas >/dev/null 2>&1; then
  alias priv='doas '
elif command -v sudo >/dev/null 2>&1; then
  alias priv='sudo '
fi

err() {
  printf '%s\n' "[$(date '+%Y-%m-%d|%H:%M:%S')]: $*" >&2
  exit 1
}

must_be_root() {
  [ "$(id -u)" = 0 ] || err "Execute ${0##*/} with root privileges."
}

today() {
  date '+%Y-%m-%d'
}

arg_eq() {
  [ "$#" -eq "${arguments_needed}" ] || err "${usage_details}"
}

arg_ge() {
  [ "$#" -ge "${arguments_needed}" ] || err "${usage_details}"
}
