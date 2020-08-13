#!/usr/bin/env bash


trap 'error_handler' ERR

function error_handler {
  echo "🚨 An error occurred, aborting script..."
  exit 1
}

echo "♻️  Converting schema structure in 'oldrecipes' database..."
psql -d oldrecipes -f ./migrate.sql


echo "⬇️  Dumping the converted schema to 'converted_dump.sql'..."
pg_dump --schema=data --data-only oldrecipes > converted_dump.sql


echo "🔥 Truncating destination table..."
docker-compose exec db psql -U superuser -d app -c "truncate table data.recipe;"

echo "⬆️  Importing 'converted_dump.sql...'"
docker-compose exec -T db psql -U superuser -d app < converted_dump.sql

rm converted_dump.sql

echo "✅ Done, please manually transfer any images."
