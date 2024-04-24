FROM timescale/timescaledb:latest-pg16

COPY docker-entrypoint-initdb.d /docker-entrypoint-initdb.d