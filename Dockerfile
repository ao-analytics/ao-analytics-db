FROM postgres:latest

ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_USER=postgres
ENV POSTGRES_DB=ao

RUN apt update && apt install -y \
    postgresql-16-cron \
    postgresql-16-partman

COPY ./docker-entrypoint-initdb.d /docker-entrypoint-initdb.d
