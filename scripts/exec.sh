#!/bin/bash

docker exec -it ao-analytics-db psql -U $POSTGRES_USER -d $POSTGRES_DB
