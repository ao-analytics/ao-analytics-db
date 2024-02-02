-- ######### EXTENSIONS #########
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ########### TABLES ###########
CREATE TABLE
    IF NOT EXISTS item (
        unique_name TEXT NOT NULL,
        id INTEGER NOT NULL UNIQUE,
        PRIMARY KEY (unique_name)
    );

CREATE TABLE
    IF NOT EXISTS localized_name (
        item_unique_name TEXT NOT NULL,
        en_us TEXT,
        de_de TEXT,
        fr_fr TEXT,
        ru_ru TEXT,
        pl_pl TEXT,
        es_es TEXT,
        pt_br TEXT,
        it_it TEXT,
        zh_cn TEXT,
        ko_kr TEXT,
        ja_jp TEXT,
        zh_tw TEXT,
        id_id TEXT,
        tr_tr TEXT,
        ar_sa TEXT,
        PRIMARY KEY (item_unique_name),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name)
    );

CREATE TABLE
    IF NOT EXISTS localized_description (
        item_unique_name TEXT NOT NULL,
        en_us TEXT,
        de_de TEXT,
        fr_fr TEXT,
        ru_ru TEXT,
        pl_pl TEXT,
        es_es TEXT,
        pt_br TEXT,
        it_it TEXT,
        zh_cn TEXT,
        ko_kr TEXT,
        ja_jp TEXT,
        zh_tw TEXT,
        id_id TEXT,
        tr_tr TEXT,
        ar_sa TEXT,
        PRIMARY KEY (item_unique_name),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name)
    );

CREATE TABLE
    IF NOT EXISTS location (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        PRIMARY KEY (id)
    );

CREATE TABLE
    IF NOT EXISTS market_history (
        item_unique_name TEXT NOT NULL,
        location_id TEXT NOT NULL,
        quality_level INTEGER NOT NULL,
        timescale INTEGER NOT NULL,
        timestamp TIMESTAMPTZ NOT NULL,
        item_amount INTEGER NOT NULL,
        silver_amount INTEGER NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW (),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW (),
        PRIMARY KEY (
            item_unique_name,
            location_id,
            quality_level,
            timescale,
            timestamp,
            updated_at
        ),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name),
        FOREIGN KEY (location_id) REFERENCES location (id)
    );

CREATE TABLE
    IF NOT EXISTS market_order (
        id BIGINT NOT NULL,
        item_unique_name TEXT NOT NULL,
        location_id TEXT NOT NULL,
        quality_level INTEGER NOT NULL,
        enchantment_level INTEGER NOT NULL,
        unit_price_silver INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        auction_type TEXT NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW (),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW (),
        PRIMARY KEY (id, updated_at),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name),
        FOREIGN KEY (location_id) REFERENCES location (id)
    );

-- ########### INDEXES ##########
CREATE INDEX ON market_order (id, item_unique_name, location_id, expires_at, updated_at, created_at);
CREATE INDEX ON market_history (item_unique_name, location_id, timescale, updated_at, created_at);

-- ######### HYPERTABLES ########
SELECT
    create_hypertable(
        'market_history',
        'updated_at',
        chunk_time_interval => INTERVAL '1 day',
        if_not_exists => true
    );

SELECT
    create_hypertable(
        'market_order',
        'updated_at',
        chunk_time_interval => INTERVAL '1 day',
        if_not_exists => true
    );

    
-- ##### MATERIALIZED VIEWS #####
CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_location AS
SELECT
    location_id,
    COUNT(*) as count
FROM
    market_order,
    location
WHERE
    location_id = location.id
GROUP BY
    location_id
ORDER BY
    count DESC;

-- ### CONTINUOUS AGGREGATIONS ###
CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_updated_in_last_24h 
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 day', updated_at) as day,
    id,
    item_unique_name,
    location_id,
    quality_level,
    enchantment_level,
    unit_price_silver,
    amount,
    auction_type,
    expires_at,
    updated_at,
    created_at
FROM
    market_order
WHERE
    updated_at > NOW() - INTERVAL '1 day'
GROUP BY
    time_bucket('1 day', updated_at),
    id,
    item_unique_name,
    location_id,
    quality_level,
    enchantment_level,
    unit_price_silver,
    amount,
    auction_type,
    expires_at,
    updated_at,
    created_at;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_updated_at
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', updated_at) as updated_at,
    COUNT(*) as count
FROM
    market_order
WHERE
    expires_at > NOW()
GROUP BY
    time_bucket('1 hour', updated_at)
ORDER BY
    updated_at DESC;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_updated_at_and_location
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', updated_at) as updated_at,
    location.name as location,
    COUNT(*) as count
FROM
    market_order
    JOIN location ON location_id = location.id
WHERE
    expires_at > NOW ()
GROUP BY
    time_bucket('1 hour', updated_at),
    location.name
ORDER BY
    updated_at DESC;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_history_updated_in_last_24h
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 day', updated_at) as day,
    item_unique_name,
    location_id,
    quality_level,
    timescale,
    timestamp,
    item_amount,
    silver_amount,
    created_at,
    updated_at
FROM
    market_history
WHERE
    updated_at > NOW() - INTERVAL '1 day'
GROUP BY
    time_bucket('1 day', updated_at),
    item_unique_name,
    location_id,
    quality_level,
    timescale,
    timestamp,
    item_amount,
    silver_amount,
    created_at,
    updated_at;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_history_count_by_updated_at
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', updated_at) as updated_at,
    COUNT(*) as count
FROM
    market_history
GROUP BY
    time_bucket('1 hour', updated_at)
ORDER BY
    updated_at DESC;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_history_count_by_updated_at_and_location
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', updated_at) as updated_at,
    location.name as location,
    COUNT(*) as count
FROM
    market_history
    JOIN location ON location_id = location.id
GROUP BY
    time_bucket('1 hour', updated_at),
    location.name
ORDER BY
    updated_at DESC;

-- ####### REFRESH POLICIES #######
SELECT add_continuous_aggregate_policy(
    'market_orders_updated_in_last_24h',
    start_offset => NULL,
    end_offset => NULL,
    schedule_interval => INTERVAL '5 minutes');

SELECT add_continuous_aggregate_policy(
    'market_orders_count_by_updated_at',
    start_offset => NULL,
    end_offset => NULL,
    schedule_interval => INTERVAL '5 minutes');

SELECT add_continuous_aggregate_policy(
    'market_orders_count_by_updated_at_and_location',
    start_offset => NULL,
    end_offset => NULL,
    schedule_interval => INTERVAL '5 minutes');

SELECT add_continuous_aggregate_policy(
    'market_history_updated_in_last_24h',
    start_offset => NULL,
    end_offset => NULL,
    schedule_interval => INTERVAL '5 minutes');

SELECT add_continuous_aggregate_policy(
    'market_history_count_by_updated_at',
    start_offset => NULL,
    end_offset => NULL,
    schedule_interval => INTERVAL '5 minutes');

SELECT add_continuous_aggregate_policy(
    'market_history_count_by_updated_at_and_location',
    start_offset => NULL,
    end_offset => NULL,
    schedule_interval => INTERVAL '5 minutes');

/*
CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_created_at
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', created_at) as created_at,
    COUNT(*) as count
FROM
    market_order
WHERE
    expires_at > NOW()
GROUP BY
    time_bucket('1 hour', created_at)
ORDER BY
    created_at DESC;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_created_at_and_location
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', created_at) as created_at,
    location.name as location,
    COUNT(*) as count
FROM
    market_order
    JOIN location ON location_id = location.id
WHERE
    expires_at > NOW ()
GROUP BY
    time_bucket('1 hour', created_at),
    location.name
ORDER BY
    created_at DESC;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_created_at_and_location
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', created_at) as created_at,
    location.name as location,
    COUNT(*) as count
FROM
    market_order
    JOIN location ON location_id = location.id
WHERE
    expires_at > NOW ()
GROUP BY
    time_bucket('1 hour', created_at),
    location.name
ORDER BY
    created_at DESC;


SELECT add_continuous_aggregate_policy(
    'market_orders_count_by_created_at',
    start_offset => NULL,
    end_offset => NULL,
    schedule_interval => INTERVAL '5 minutes');

SELECT add_continuous_aggregate_policy(
    'market_orders_count_by_created_at_and_location',
    start_offset => NULL,
    end_offset => NULL,
    schedule_interval => INTERVAL '5 minutes');
*/

/*
REFRESH MATERIALIZED VIEW markSELECT create_hypertable('market_history', 'timestamp', chunk_time_interval => INTERVAL '1 day');et_orders_count_by_location
WITH
NO DATA;

REFRESH MATERIALIZED VIEW market_orders_count_by_updated_at
WITH
NO DATA;

REFRESH MATERIALIZED VIEW market_orders_count_by_updated_at_and_location
WITH
NO DATA;

REFRESH MATERIALIZED VIEW market_orders_count_by_created_at
WITH
NO DATA;

REFRESH MATERIALIZED VIEW market_orders_count_by_created_at_and_location
WITH
NO DATA;
 */