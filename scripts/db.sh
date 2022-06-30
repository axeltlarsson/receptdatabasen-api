set -euo pipefail

PGHOST=./pg_db
PGLOG=$PGHOST/postgres.log

# expected env vars from .env file
if [[ -z $DB_PORT || -z $DB_NAME || -z $DB_PORT || -z $SUPER_USER || -z $SUPER_USER_PASSWORD ]]; then
  echo "One or more required env vars are not set!"
  exit 1
fi
DB_USER=$SUPER_USER
DB_PASSWORD=$SUPER_USER_PASSWORD

help () {
cat << DOC
Convenviently handle the database for receptdatabasen.

Usage:
  db init           Create start a new local db in ${PGHOST} using pg_ctl
  db start          Start existing db
  db stop           Stop the db
  db import_prod    Import a production dump into local db,
                    will start the db if not already running
  db shell          Launch psql shell into the db
  db reset          Reset the db with sample_data/reset.sql
  db status         Get status of the db (running already or not)
  db logs
DOC

}

init_db() {
  mkdir -p "$PGHOST"
  initdb --no-locale --encoding=UTF8 --auth=trust --username "$DB_USER" "$PGHOST"
  start_db
  createdb -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"
}

start_db() {
  pg_ctl start -l "$PGLOG" -D "$PGHOST" -o "-p $DB_PORT"
}

stop_db() {
  pg_ctl -D "$PGHOST" -o "-p $DB_PORT" stop
}

import_prod() {
  if pg_ctl -D "$PGHOST" status | grep -qw "no server running"; then
    start_db
  fi

  # If db already exists, we must drop it
  if psql -p "$DB_PORT" --user "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    echo "Drop $DB_NAME"
    dropdb --username "$DB_USER" -p "$DB_PORT" "$DB_NAME"
  fi

  # Import latest version from prod
  # TODO
}

CONN="postgresql://$DB_USER:$DB_PASSWORD@localhost:$DB_PORT/$DB_NAME"

case "${1-help}" in

  init)
    init_db
    ;;
  start)
    start_db
    ;;
  stop)
    stop_db
    ;;
  import_prod)
    import_prod stiftelseapp
    ;;
  shell)
    psql "$CONN"
    ;;
  reset)
    (cd db/src/sample_data && psql "$CONN" < ./reset.sql)
    ;;
  status)
    pg_ctl -D $PGHOST status
      ;;
  logs)
    echo "not yet implemented"
    env
      ;;
  *) help
     ;;
esac

exit 0
