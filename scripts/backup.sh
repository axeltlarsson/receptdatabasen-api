#!/bin/bash

set -e

# This script is used to back up the database, dump is output to STDOUT

source .env
docker-compose exec db pg_dump -U "$SUPER_USER" -d app
