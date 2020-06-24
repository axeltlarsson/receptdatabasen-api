## Convert mysql db to postgres

### On andrimner

1. Create the destination Postgres instance, and attach it to the `receptdatabasen_back` network:
  ```
  docker run --name migrating_receptdatabasen -e POSTGRES_PASSWORD=pass -d --network receptdatabasen_back -P postgres
  ```
2. Inspect the network to find IP address of `migrating_receptdatabasen` and `receptdatabasen_db_1`, (pgloader has issues with host_names containing "_" it seems...):
```
  docker network inspect receptdatabasen_back
  ```
3. Inspect the source container and find the password, store connection URI:s in some env vars for easy usage:
  ```
  MY_SOURCE="mysql://recipes:<pass>@172.20.0.2/recipes"
  PG_DEST="postgresql://postgres:pass@172.20.0.5/postgres"
  ```
4. Run the migration:
  ```
  docker run --rm --name pgloader --network receptdatabasen_back dimitri/pgloader:latest pgloader $MY_SOURCE $PG_DEST
  ```
5. Verify by connecting to the destination:
```
  docker exec -it migrating_receptdatabasen psql -U postgres -d postgres
  \dt
  select * from Gallery limit 10;
  ```
6. Create a dump:
  ```
  docker exec -it migrating_receptdatabasen bash
  pg_dump recipes > dump.sql
  exit
  docker cp migrating_receptdatabasen:/dump.sql ./
  ```
7. Restore the dump into any pg you want, or use the already created pg instance to transform the tables appropriately.

## Run the automated migration script

Note, it will truncate the destination db's `data.recipe` table!

```shell
./migrate.sh
```

## Copy over the images

```shell
docker cp images receptdatabasen_openresty_1:/uploads
docker-compose exec openresty bash
cd /uploads
mv images/* .
rmdir images
chown nobody:root *
```
