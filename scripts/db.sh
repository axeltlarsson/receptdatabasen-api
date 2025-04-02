# This script is currently not used - local db not reachable from docker
set -euo pipefail

PGHOST=./data/db
PGLOG=$PGHOST/postgres.log

# expected env vars from .env file
if [[ -z $DB_PORT || -z $DB_NAME || -z $DB_PORT || -z $SUPER_USER || -z $SUPER_USER_PASSWORD ]]; then
	echo "One or more required env vars are not set!"
	exit 1
fi

CONN="postgresql://$SUPER_USER:$SUPER_USER_PASSWORD@localhost:$DB_PORT/$DB_NAME"

help() {
	cat <<DOC
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

_createdb() {
	createdb -p "$DB_PORT" -U "$SUPER_USER" "$DB_NAME"
	# psql "$CONN" -c "create role $USER2 with login SUPERUSER";
}

init_db() {
	mkdir -p "$PGHOST"
	initdb --no-locale --encoding=UTF8 --auth=trust --username "$SUPER_USER" "$PGHOST"
	start_db
	_createdb
	_seed_db
}

_seed_db() {
	# need another user to run the init.sql script (as it drops its own superuser)
	(cd db/src && psql "$CONN" <./init.sql)
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

	# If db already exists, we must drop it and then recreate it
	if psql "$CONN" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
		echo "Dropping $DB_NAME..."
		echo dropdb --username "$SUPER_USER" -p "$DB_PORT" "$DB_NAME"
		dropdb --username "$SUPER_USER" -p "$DB_PORT" "$DB_NAME"
		psql "$CONN" -c "drop database $DB_NAME"
		_createdb
		_seed_db
	fi

	DUMP_CMD=$(
		cat <<EOF
cd /srv/receptdatabasen
set -a
source .env
set +a
docker-compose -f docker-compose.yml -f docker-compose.prod.yml exec -T db pg_dump --clean --if-exists "postgresql://$SUPER_USER@localhost:$DB_PORT/$DB_NAME"
EOF
	)

	echo "Importing prod database into local database..."
	ssh -CqT "$1" "$DUMP_CMD" | psql "$CONN"
	echo "✅"
}

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
	import_prod andrimner
	;;
shell)
	psql "$CONN"
	;;
reset)
	(cd db/src/sample_data && psql "$CONN" <./reset.sql)
	;;
status)
	pg_ctl -D $PGHOST status
	;;
logs)
	tail $PGLOG
	;;
*)
	help
	;;
esac

exit 0
