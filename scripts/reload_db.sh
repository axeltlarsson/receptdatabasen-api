#!/bin/bash

# revert latest migration
# finds next-to-last migration
revert_to=$(sqitch --chdir db/migrations plan --format "format:%n" | tail -n2 | head -1)
sqitch --chdir db/migrations revert -y --to "${revert_to}"

# deploy again
sqitch --chdir db/migrations deploy

# reload postgrest
docker-compose kill -s SIGUSR1 postgrest
