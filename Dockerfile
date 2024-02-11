FROM postgres:latest

ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_USER=postgres
ENV POSTGRES_DB=ao

EXPOSE 5432

RUN apt update && apt install -y \
    git \
    make \
    gcc \
    libpq-dev \
    postgresql-server-dev-16

RUN git clone https://github.com/pgpartman/pg_partman.git \
    && cd pg_partman \
    && make \
    && make install

RUN git clone https://github.com/citusdata/pg_cron.git \
    && cd pg_cron \
    && make \
    && make install

COPY ./docker-entrypoint-initdb.d /docker-entrypoint-initdb.d
