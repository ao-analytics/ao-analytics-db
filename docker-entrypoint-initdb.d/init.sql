CREATE SCHEMA IF NOT EXISTS public;

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS timescaledb;
SET pg_trgm.similarity_threshold = 0.5;

CREATE TABLE
    IF NOT EXISTS item_group (
        name TEXT NOT NULL,
        --
        PRIMARY KEY (name)
);

CREATE TABLE
    IF NOT EXISTS item (
        unique_name TEXT NOT NULL,
        --
        item_group_name TEXT NOT NULL,
        enchantment_level SMALLINT NOT NULL,
        --
        PRIMARY KEY (unique_name),
        FOREIGN KEY (item_group_name) REFERENCES item_group (name)
);

CREATE TABLE
    IF NOT EXISTS
        item_data (
            item_group_name TEXT NOT NULL,
            --
            data JSONB NOT NULL,
            --
            PRIMARY KEY (item_group_name),
            FOREIGN KEY (item_group_name) REFERENCES item_group (name)
);

CREATE TABLE
    IF NOT EXISTS localized_name (
        item_unique_name TEXT NOT NULL,
        lang TEXT NOT NULL,
        --
        name TEXT NOT NULL,
        --
        PRIMARY KEY (item_unique_name, lang),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name)
);

CREATE TABLE
    IF NOT EXISTS localized_description (
        item_unique_name TEXT NOT NULL,
        lang TEXT NOT NULL,
        --
        description TEXT NOT NULL,
        --
        PRIMARY KEY (item_unique_name, lang),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name)
);

CREATE TABLE
    IF NOT EXISTS location (
        id SMALLINT NOT NULL,
        ---
        PRIMARY KEY (id)
);

CREATE TABLE
    IF NOT EXISTS location_data (
        id TEXT NOT NULL,
        --
        location_id SMALLINT,
        name TEXT NOT NULL,
        --
        PRIMARY KEY (id),
        FOREIGN KEY (location_id) REFERENCES location (id),
        UNIQUE(id, location_id)
);

CREATE TABLE
    IF NOT EXISTS market_order (
        id BIGINT NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        --
        item_unique_name TEXT NOT NULL,
        location_id SMALLINT NOT NULL,
        quality_level SMALLINT NOT NULL,
        unit_price_silver BIGINT NOT NULL,
        amount BIGINT NOT NULL,
        auction_type TEXT NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        --
        PRIMARY KEY (id, updated_at),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name),
        FOREIGN KEY (location_id) REFERENCES location (id)
);

SELECT FROM create_hypertable('market_order', by_range('updated_at', INTERVAL '30 minutes'), if_not_exists := true);

CREATE TABLE
    IF NOT EXISTS market_history (
        item_unique_name TEXT NOT NULL,
        location_id SMALLINT NOT NULL,
        quality_level SMALLINT NOT NULL,
        timescale SMALLINT NOT NULL,
        timestamp TIMESTAMPTZ NOT NULL,
        --
        item_amount BIGINT NOT NULL,
        silver_amount BIGINT NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        --
        PRIMARY KEY (
            item_unique_name,
            location_id,
            quality_level,
            timescale,
            timestamp
        ),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name),
        FOREIGN KEY (location_id) REFERENCES location (id)
);

SELECT FROM create_hypertable('market_history', by_range('timestamp', INTERVAL '1 day'), if_not_exists := true);

CREATE MATERIALIZED VIEW IF NOT EXISTS item_prices_by_hour_and_location
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', updated_at) as date,
    item_unique_name,
    location_id,
    COUNT(*) as total_count,
    MAX(unit_price_silver) FILTER (WHERE auction_type = 'offer') as max_unit_price_silver_offer,
    MIN(unit_price_silver) FILTER (WHERE auction_type = 'offer') as min_unit_price_silver_offer,
    ROUND(SUM(unit_price_silver * amount) FILTER (WHERE auction_type = 'offer') / SUM(amount) FILTER (WHERE auction_type = 'offer'))::BIGINT as avg_unit_price_silver_offer,
    SUM(amount) FILTER (WHERE auction_type = 'offer') as sum_amount_offer,
    MAX(unit_price_silver) FILTER (WHERE auction_type = 'request') as max_unit_price_silver_request,
    MIN(unit_price_silver) FILTER (WHERE auction_type = 'request') as min_unit_price_silver_request,
    ROUND(SUM(unit_price_silver * amount) FILTER (WHERE auction_type = 'request') / SUM(amount) FILTER (WHERE auction_type = 'request'))::BIGINT as avg_unit_price_silver_request,
    SUM(amount) FILTER (WHERE auction_type = 'request') as sum_amount_request
FROM
    market_order
GROUP BY
    date,
    item_unique_name,
    location_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS item_prices_by_hour
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', updated_at) as date,
    item_unique_name,
    COUNT(*) as total_count,
    MAX(unit_price_silver) FILTER (WHERE auction_type = 'offer') as max_unit_price_silver_offer,
    MIN(unit_price_silver) FILTER (WHERE auction_type = 'offer') as min_unit_price_silver_offer,
    ROUND(SUM(unit_price_silver * amount) FILTER (WHERE auction_type = 'offer') / SUM(amount) FILTER (WHERE auction_type = 'offer'))::BIGINT as avg_unit_price_silver_offer,
    SUM(amount) FILTER (WHERE auction_type = 'offer') as sum_amount_offer,
    MAX(unit_price_silver) FILTER (WHERE auction_type = 'request') as max_unit_price_silver_request,
    MIN(unit_price_silver) FILTER (WHERE auction_type = 'request') as min_unit_price_silver_request,
    ROUND(SUM(unit_price_silver * amount) FILTER (WHERE auction_type = 'request') / SUM(amount) FILTER (WHERE auction_type = 'request'))::BIGINT as avg_unit_price_silver_request,
    SUM(amount) FILTER (WHERE auction_type = 'request') as sum_amount_request
FROM
    market_order
GROUP BY
    date,
    item_unique_name;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_hour_and_location
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', updated_at) as date,
    location_id,
    COUNT(*) as count
FROM
    market_order
WHERE
    expires_at > NOW ()
GROUP BY
    date,
    location_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_hour
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', updated_at) as date,
    COUNT(*) as count
FROM
    market_order
WHERE
    expires_at > NOW ()
GROUP BY
    date;

SELECT add_continuous_aggregate_policy(
        continuous_aggregate := 'market_orders_count_by_hour',
        start_offset := INTERVAL '1 day',
        end_offset := NULL,
        schedule_interval := INTERVAL '30 minutes',
        if_not_exists := true);

SELECT add_continuous_aggregate_policy(
        continuous_aggregate := 'market_orders_count_by_hour_and_location',
        start_offset := INTERVAL '1 day',
        end_offset := NULL,
        schedule_interval := INTERVAL '30 minutes',
        if_not_exists := true);

SELECT add_continuous_aggregate_policy(
        continuous_aggregate := 'item_prices_by_hour',
        start_offset := INTERVAL '1 day',
        end_offset := NULL,
        schedule_interval := INTERVAL '30 minutes',
        if_not_exists := true);

SELECT add_continuous_aggregate_policy(
        continuous_aggregate := 'item_prices_by_hour_and_location',
        start_offset := INTERVAL '1 day',
        end_offset := NULL,
        schedule_interval := INTERVAL '30 minutes',
        if_not_exists := true);

SELECT add_retention_policy(
        relation := 'market_order',
        drop_after := INTERVAL '1 day',
        schedule_interval := INTERVAL '1 hour',
        if_not_exists := true);

ALTER TABLE market_history SET(
        timescaledb.compress,
        timescaledb.compress_orderby = 'timestamp DESC',
        timescaledb.compress_segmentby = 'item_unique_name, location_id, quality_level, timescale',
        timescaledb.compress_chunk_time_interval = '1 day'
);

SELECT add_compression_policy(
       hypertable := 'market_history',
       compress_after := INTERVAL '1 month',
       if_not_exists := true,
       schedule_interval := INTERVAL '1 day',
       initial_start := NULL);
