ARG PG_VERSION=12

FROM postgres:${PG_VERSION}
LABEL org.opencontainers.image.source=https://github.com/axeltlarsson/receptdatabasen-api
LABEL org.opencontainers.image.description="Receptdatabasen db"

# Add pl/python
RUN apt-get update
# TODO: can't use PG_VERSION arg twice?
RUN apt-get -y install python3 postgresql-plpython3-12 python3-pip

# Install py_webauthn
# RUN pip install --break-system-packages 'webauthn<2'
# locally, this might be needed 💩
RUN pip install webauthn

COPY ./src/ /docker-entrypoint-initdb.d
