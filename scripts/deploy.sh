#!/bin/bash

set -e

# This script is called from the post-receive hook, upon deployment.
# Working directory is root of the project

echo "Deploying ${NEWREV:0:6}..."
(cd frontend && docker build -t receptdatabasen_frontend_builder .) 
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up --build -d
echo "Running migrations..."
source .env
PGUSER=$SUPER_USER PGPASSWORD=$SUPER_USER_PASSWORD DOCKER_NETWORK="${COMPOSE_PROJECT_NAME}_backend" scripts/sqitch deploy prod --cd db/migrations
