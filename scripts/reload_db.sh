#!/bin/bash

# revert latest migration
# finds next-to-last migration
revert_to=$(find db/migrations/revert -type f -printf "%T@ %f\n" | sort -n | sed -n '2p' | awk '{print $2}' | xargs -I {} basename {} .sql)
sqitch --chdir db/migrations revert -y --to "${revert_to}"

# deploy again
sqitch --chdir db/migrations deploy

# reload postgrest
docker-compose kill -s SIGUSR1 postgrest
