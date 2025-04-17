#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

usage() {
	cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-d] host

Import production database into local setup

Required arguments:
host            the host to import from

Available options:
-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-d, --download  Also download images 
--docker				Download images to docker container (otherwise uses on-metal Nix)
EOF
	exit
}

cleanup() {
	trap - SIGINT SIGTERM ERR EXIT
	# script cleanup here
}

setup_colors() {
	if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
		# shellcheck disable=2034
		NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
	fi
}

msg() {
	echo >&2 -e "${1-}"
}

die() {
	local msg=$1
	local code=${2-1} # default exit status 1
	msg "$msg"
	exit "$code"
}

parse_params() {
	# default values of variables set from params
	DOWNLOAD=0
	DOCKER=0

	while [[ $# -gt 0 ]]; do
		case "${1-}" in
		-h | --help) usage ;;
		-v | --verbose) set -x ;;
		--no-color) NO_COLOR=1 ;;
		-d | --download) DOWNLOAD=1 ;; # download images too
		--docker) DOCKER=1 ;;          # download images to docker container (otherwise uses on-metal Nix)
		-?*) die "Unknown option: $1" ;;
		*)
			# Collect all non-option arguments
			args+=("$1")
			;;
		esac
		shift
	done

	# check required params and arguments
	[[ ${#args[@]} -eq 0 ]] && usage && die "Missing script arguments"

	return 0
}

# Initialize the args array
args=()
parse_params "$@"
host=${args[0]}
setup_colors

msg "${YELLOW}Import production database dump...${NOFORMAT}"
ssh "$1" 'cd /srv/receptdatabasen && docker compose -f docker-compose.yml -f docker-compose.prod.yml exec -T db pg_dump -U superuser -d app' >prod-dump.sql 2>/dev/null

_dropdb() {
	if [ "$DOCKER" -eq 1 ]; then
		docker compose exec db bash -c "dropdb -h localhost -U $SUPER_USER -p $DB_PORT app"
	else
		dropdb -h localhost -U "$SUPER_USER" -p "$DB_PORT" app
	fi
}

_createdb() {
	if [ "$DOCKER" -eq 1 ]; then
		docker compose exec db bash -c "createdb -h localhost -U $SUPER_USER -p $DB_PORT app"
	else
		createdb -h localhost -U "$SUPER_USER" -p "$DB_PORT" app
	fi
}

_importdb() {
	if [ "$DOCKER" -eq 1 ]; then
		docker compose exec -T db bash -c "psql -h localhost -U $SUPER_USER -p $DB_PORT app" <prod-dump.sql
	else
		psql -h localhost -U "$SUPER_USER" -p "$DB_PORT" app <prod-dump.sql
	fi
}

_execdb() {
	if [ "$DOCKER" -eq 1 ]; then
		echo "$1" | docker compose exec -T db psql -U "$SUPER_USER" app
	else
		psql -h localhost -U "$SUPER_USER" -p "$DB_PORT" app "$1"
	fi
}

msg "${YELLOW}Drop local database...${NOFORMAT}"
_dropdb
msg "${YELLOW}Re-create local database...${NOFORMAT}"
_createdb
msg "${YELLOW}Import production into local db...${NOFORMAT}"
_importdb
rm prod-dump.sql

# create test users and set some settings for local usage
msg "${YELLOW}Configuring prod db for local usage...${NOFORMAT}"
sql_config=$(
	cat <<EOF
	begin;
	\echo Creating test users;
	insert into data.user (user_name, password) values ('alice', 'pass');
	insert into data.user (user_name, password) values ('bob', 'pass');

	\echo Setting up settings to match default .env;
	select settings.set('origin', 'http://localhost:1234');
	select settings.set('rp_id', 'localhost');
	select settings.set('image_server_secret', '5b1c7df3d10cfa988b2830562662d45c');
	select settings.set('jwt_secret', 'AG7Yo/BbqGZUm75BZ5HfDkexDKAIumSCJY+eoyh9f1sr');
	select settings.set('disable_user_verification', 'true');
	commit;
EOF
)

_execdb "$sql_config"

if [ "$DOWNLOAD" -eq 1 ]; then
	msg "${YELLOW}Downloading images..${NOFORMAT}"
	ssh "$host" "mkdir -p /tmp/uploads-recept"
	ssh "$host" "docker run -i --rm -v receptdatabasen_uploads-vol:/uploads -v /tmp/uploads-recept:/target ubuntu tar cvf /target/backup.tar /uploads > /dev/null"
	scp "$host":/tmp/uploads-recept/backup.tar .
	ssh "$host" "rm -rf /tmp/uploads-recept"

	if [ "$DOCKER" -eq 1 ]; then
		docker compose exec openresty bash -c "rm -rf /uploads/*"
		docker cp backup.tar receptdatabasen_openresty_1:/uploads
		docker compose exec openresty bash -c "cd /uploads && tar -xf backup.tar && mv uploads/* . && rmdir uploads && rm backup.tar"
		docker compose exec openresty bash -c "chown -R nobody /uploads/*"
		rm backup.tar
	else
		echo "mkdir -p $FILE_UPLOAD_PATH"
		mkdir -p "$FILE_UPLOAD_PATH"
		mv backup.tar "$FILE_UPLOAD_PATH"/backup.tar
		cd "$FILE_UPLOAD_PATH" && tar -xf backup.tar && mv uploads/* . && rmdir uploads && rm backup.tar
	fi
fi

msg "✅"
