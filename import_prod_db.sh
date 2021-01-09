#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT


usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] host

Import production database into local setup

Required arguments:
host            the host to import from

Available options:
-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-f, --flag      Some flag description
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
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
  download=0
  param=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -d | --download) download=1 ;; # download images too
    -p | --param) # example named parameter
      param="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  # [[ -z "${param-}" ]] && die "Missing required parameter: param"
  [[ ${#args[@]} -eq 0 ]] && usage && die "Missing script arguments"

  return 0
}

parse_params "$@"
host=${args[0]}
setup_colors

# script logic here

msg "${YELLOW}Import production database dump...${NOFORMAT}"
ssh "$1" 'cd /srv/receptdatabasen && docker-compose -f docker-compose.yml -f docker-compose.prod.yml exec -T db pg_dump -U superuser -d app' > prod-dump.sql

msg "${YELLOW}Drop local database...${NOFORMAT}"
docker-compose exec db dropdb -U superuser app
msg "${YELLOW}Re-create local database...${NOFORMAT}"
docker-compose exec db createdb -U superuser app
msg "${YELLOW}Import production into local db...${NOFORMAT}"
docker-compose exec -T db psql -U superuser -d app < prod-dump.sql
rm prod-dump.sql

if [ -n "$download" ]; then
  msg "${YELLOW}Download images..${NOFORMAT}"
  ssh "$host" "mkdir -p /tmp/uploads-recept"
  ssh "$host" "docker run -i --rm -v receptdatabasen_uploads-vol:/uploads -v /tmp/uploads-recept:/target ubuntu tar cvf /target/backup.tar /uploads > /dev/null"
  scp "$host":/tmp/uploads-recept/backup.tar .
  ssh "$host" "rm -rf /tmp/uploads-recept"
  docker cp backup.tar receptdatabasen_openresty_1:/uploads
  docker-compose exec openresty rm -rf /uploads/*
  docker-compose exec openresty "cd /uploads && tar -xf backup.tar && mv uploads/* . && rmdir uploads && rm backup.tar"
  docker-compose exec openresty chown -R nobody /uploads/*
  rm backup.tar
fi

msg "✅"
