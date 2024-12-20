#!/bin/bash

set -e

# This script is called from the post-receive hook, upon deployment.
# Working directory is root of the project

echo "Deploying ${NEWREV:0:6}..."
source .env
docker compose -f docker-compose.yml -f docker-compose.prod.yml up --build -d --pull always
echo "Running migrations..."
PGUSER=$SUPER_USER PGPASSWORD=$SUPER_USER_PASSWORD DOCKER_NETWORK="${COMPOSE_PROJECT_NAME}_backend" scripts/sqitch deploy prod --cd db/migrations
