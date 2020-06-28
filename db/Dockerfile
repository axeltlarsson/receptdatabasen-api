ARG VERSION=latest
FROM postgres:${VERSION}

COPY ./src/ /docker-entrypoint-initdb.d
