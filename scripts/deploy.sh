#!/bin/bash

set -e

# This script is called from the post-receive hook, upon deployment.

echo "Deploying ${NEWREV:0:6}..."
docker-compose build
