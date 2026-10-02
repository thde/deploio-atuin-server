#!/bin/sh
# Configures atuin-server from the environment Deploio injects, then starts it.
# See https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services.md
set -eu

log() {
  echo "entrypoint: $*" >&2
}

die() {
  log "error: $*"
  exit 1
}

# Kubernetes injects ATUIN_PORT=tcp://<ip>:<port> when the app is named "atuin",
# which atuin would read as its port setting.
case ${ATUIN_PORT:-} in
tcp://*) unset ATUIN_PORT ;;
esac

# Deploio routes traffic to 0.0.0.0:$PORT.
export ATUIN_HOST="${ATUIN_HOST:-0.0.0.0}"
export ATUIN_PORT="${ATUIN_PORT:-${PORT:-8888}}"

# Service types atuin can use, in order of preference when looking up a named reference.
DB_KINDS="PGDB PG MYSQLDB MYSQL"

# Prints the name of the DSN variable to use, or nothing if no database is attached.
find_dsn_var() {
  if [ -n "${ATUIN_DB_SERVICE:-}" ]; then
    # Nine uppercases the reference name and replaces non-alphanumerics with "_".
    ref=$(printf '%s' "$ATUIN_DB_SERVICE" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9' '_')
    for kind in $DB_KINDS; do
      var="NINE_${kind}_${ref}_DSN"
      if [ -n "$(printenv "$var" || true)" ]; then
        echo "$var"
        return
      fi
    done
    die "ATUIN_DB_SERVICE=$ATUIN_DB_SERVICE is set, but no matching NINE_*_${ref}_DSN variable exists"
  fi

  vars=$(env | grep -Eo '^NINE_(PGDB|PG|MYSQLDB|MYSQL)_[A-Z0-9_]+_DSN=' | tr -d '=' | sort -u)
  count=$(printf '%s' "$vars" | grep -c . || true)
  if [ "$count" -gt 1 ]; then
    die "multiple database services attached ($(printf '%s' "$vars" | tr '\n' ' ')); set ATUIN_DB_SERVICE to the reference name to use"
  fi
  echo "$vars"
}

# Adds a database name to a DSN that has none (Business tier DSNs only point at the server).
with_db_name() {
  dsn=$1
  name=$2
  base=${dsn%%\?*}
  query=${dsn#"$base"}
  authority=${base#*://}
  case ${authority##*@} in
  */*) die "ATUIN_DB_NAME is set, but the injected DSN already contains a database name" ;;
  esac
  echo "${base}/${name}${query}"
}

if [ -n "${ATUIN_DB_URI:-}" ]; then
  log "using ATUIN_DB_URI from the environment"
else
  dsn_var=$(find_dsn_var)
  [ -n "$dsn_var" ] || die "no database configured: attach a PostgreSQL or MySQL service or set ATUIN_DB_URI"

  ATUIN_DB_URI=$(printenv "$dsn_var")
  if [ -n "${ATUIN_DB_NAME:-}" ]; then
    ATUIN_DB_URI=$(with_db_name "$ATUIN_DB_URI" "$ATUIN_DB_NAME")
  fi
  export ATUIN_DB_URI
  log "using database from $dsn_var"
fi

exec /usr/local/bin/atuin-server "$@"
