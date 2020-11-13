#!/bin/bash

set -e

source .env

if [ -z ${SSH_HOST+x} ];
then
  echo "Set the SSH_HOST variable in .env to enable this script"
  exit 1;
fi

cd ..

echo "🔥 Truncating destination table..."
docker-compose exec db psql -U superuser -d app -c "truncate table data.recipe;" > /dev/null

echo "⏬ Making and importing ⬆️  a database backup from $SSH_HOST..."
ssh "$SSH_HOST" -C "cd /srv/receptdatabasen; docker-compose exec -T db pg_dump --clean -U $SUPER_USER -d app" | docker-compose exec -T db psql -U superuser -d app > /dev/null

echo "⏬ Importing latest image backup..."
latest=$(ssh "$SSH_HOST" -C "ls -t /datapool/backups/receptdatabasen/uploads | head -n 1")
scp $SSH_HOST:"/datapool/backups/receptdatabasen/uploads/$latest" "$latest"

openrestyId=$(docker ps -aqf "name=openresty")
docker cp "$latest" "$openrestyId:/"
docker-compose exec openresty tar -xf "$latest"
docker-compose exec openresty rm "$latest"
rm "$latest"


echo "✅ Done!"
