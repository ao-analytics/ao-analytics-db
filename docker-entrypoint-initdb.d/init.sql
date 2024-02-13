CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_partman;
CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE TABLE
    IF NOT EXISTS item (
        unique_name TEXT NOT NULL,
        id INTEGER NOT NULL,
        PRIMARY KEY (unique_name)
    );

CREATE TABLE
    IF NOT EXISTS localized_name (
        item_unique_name TEXT UNIQUE NOT NULL,
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
        FOREIGN KEY (item_unique_nlazy NULL,
        timescale INTEGER NOT NULL,
        timestamp TIMESTAMPTZ NOT NULL,
        item_amount INTEGER NOT NULL,
        silver_amount INTEGER NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
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
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (id),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name),
        FOREIGN KEY (location_id) REFERENCES location (id)
    );

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_location AS
SELECT
    location_id,
    COUNT(*) as count
FROM
    market_order
GROUP BY
    location_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_updated_in_last_24h AS
SELECT
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
    updated_at > NOW() - INTERVAL '1 day';

CREATE MATERIALIZED VIEW IF NOT EXISTS market_order_stats_by_item_and_day AS
SELECT
    updated_at::date as date,
    item_unique_name,
    COUNT(*) as count,
    MAX(unit_price_silver) as max_unit_price_silver,
    MIN(unit_price_silver) as min_unit_price_silver,
    AVG(unit_price_silver):: as avg_unit_price_silver,
    SUM(amount) as sum_amount
FROM
    market_order
GROUP BY
    updated_at::date,
    item_unique_name;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_updated_at AS
SELECT
    date_trunc('hour', updated_at) as updated_at,
    COUNT(*) as count
FROM
    market_order
WHERE
    expires_at > NOW()
GROUP BY
    date_trunc('hour', updated_at);

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_updated_at_and_location AS
SELECT
    date_trunc('hour', updated_at) as updated_at,
    location_id,
    COUNT(*) as count
FROM
    market_order
WHERE
    expires_at > NOW ()
GROUP BY
    date_trunc('hour', updated_at),
    location_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_created_at AS
SELECT
    date_trunc('hour', created_at) as created_at,
    COUNT(*) as count
FROM
    market_order
WHERE
    expires_at > NOW()
GROUP BY
    date_trunc('hour', created_at);

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_created_at_and_location AS
SELECT
    date_trunc('hour', created_at)  as created_at,
    location_id,
    COUNT(*) as count
FROM
    market_order
WHERE
    expires_at > NOW ()
GROUP BY
    date_trunc('hour', created_at),
    location_id;

CREATE UNIQUE INDEX ON market_order_stats_by_item_and_day (date, item_unique_name);
CREATE UNIQUE INDEX ON market_orders_count_by_created_at (created_at);
CREATE UNIQUE INDEX ON market_orders_count_by_created_at_and_location (created_at, location_id);
CREATE UNIQUE INDEX ON market_orders_count_by_updated_at (updated_at);
CREATE UNIQUE INDEX ON market_orders_count_by_updated_at_and_location (updated_at, location_id);
CREATE UNIQUE INDEX ON market_orders_count_by_location (location_id);
CREATE UNIQUE INDEX ON market_orders_updated_in_last_24h (id);

-- Debug to check if extensions are installed
SELECT * FROM pg_extension;

REFRESH MATERIALIZED VIEW CONCURRENTLY market_order_stats_by_item_and_day;
REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_count_by_created_at;
REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_count_by_created_at_and_location;
REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_count_by_updated_at;
REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_count_by_updated_at_and_location;
REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_count_by_location;
REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_updated_in_last_24h;

-- Create cron jobs for refreshing materialized views

SELECT cron.schedule('*/5 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY market_order_stats_by_item_and_day');
SELECT cron.schedule('*/5 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_count_by_created_at');
SELECT cron.schedule('*/5 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_count_by_created_at_and_location');
SELECT cron.schedule('*/5 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_count_by_updated_at');
SELECT cron.schedule('*/5 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_count_by_updated_at_and_location');
SELECT cron.schedule('*/5 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_count_by_location');
SELECT cron.schedule('*/5 * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY market_orders_updated_in_last_24h');
