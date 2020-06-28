#!/bin/bash

set -e

# This script is called from the post-receive hook, upon deployment.

echo "Deploying ${NEWREV:0:6}..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --pull
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps
