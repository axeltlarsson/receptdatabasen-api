ARG PG_VERSION
FROM postgres:12

# Add pl/python
RUN apt-get update
# TODO: can't use PG_VERSION arg twice?
RUN apt-get -y install python3 postgresql-plpython3-12 python3-pip

# Install py_webauthn
RUN pip install webauthn

COPY ./src/ /docker-entrypoint-initdb.d
