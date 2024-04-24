CREATE SCHEMA IF NOT EXISTS public;

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE
    IF NOT EXISTS shop_category (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        PRIMARY KEY (id)
);

CREATE TABLE
    IF NOT EXISTS shop_sub_category (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        shop_category_id TEXT NOT NULL,
        PRIMARY KEY (id),
        FOREIGN KEY (shop_category_id) REFERENCES shop_category (id)
);

CREATE TABLE
    IF NOT EXISTS item (
        unique_name TEXT NOT NULL,
        PRIMARY KEY (unique_name)
);

CREATE TABLE
    IF NOT EXISTS item_data (
        item_unique_name TEXT NOT NULL,
        enchantment_level INTEGER NOT NULL,
        shop_sub_category_id TEXT,
        tier INTEGER,
        weight REAL,
        PRIMARY KEY (item_unique_name),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name),
        FOREIGN KEY (shop_sub_category_id) REFERENCES shop_sub_category (id)
);

CREATE INDEX item_data_enchantment_level_idx ON item_data (enchantment_level);
CREATE INDEX item_data_tier_idx ON item_data (tier);

CREATE TABLE
    IF NOT EXISTS localized_name (
        item_unique_name TEXT NOT NULL,
        lang TEXT NOT NULL,
        name TEXT NOT NULL,
        PRIMARY KEY (item_unique_name, lang),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name)
);

CREATE INDEX localized_name_lang_idx ON localized_name (lang);
CREATE INDEX localized_name_name_idx ON localized_name (name);

CREATE TABLE
    IF NOT EXISTS localized_description (
        item_unique_name TEXT NOT NULL,
        lang TEXT NOT NULL,
        description TEXT NOT NULL,
        PRIMARY KEY (item_unique_name, lang),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name)
);

CREATE INDEX localized_description_lang_idx ON localized_description (lang);
CREATE INDEX localized_description_description_idx ON localized_description (description);

CREATE TABLE
    IF NOT EXISTS location (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        PRIMARY KEY (id)
    );

CREATE TABLE
    IF NOT EXISTS market_order (
        id BIGINT NOT NULL,
        item_unique_name TEXT NOT NULL,
        location_id TEXT NOT NULL,
        quality_level INTEGER NOT NULL,
        unit_price_silver INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        auction_type TEXT NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (id, updated_at),
        FOREIGN KEY (item_unique_name) REFERENCES item (unique_name),
        FOREIGN KEY (location_id) REFERENCES location (id)
    );

SELECT FROM create_hypertable('market_order', by_range('updated_at', INTERVAL '30 minutes'), if_not_exists := true);

CREATE INDEX market_order_id_idx ON market_order (id);

CREATE TABLE
    IF NOT EXISTS market_order_backup (
        id BIGINT NOT NULL,
        item_unique_name TEXT NOT NULL,
        location_id TEXT NOT NULL,
        quality_level INTEGER NOT NULL,
        unit_price_silver INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        auction_type TEXT NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

CREATE MATERIALIZED VIEW IF NOT EXISTS item_prices_by_updated_at_and_location
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', updated_at) as date,
    item_unique_name,
    location_id,
    COUNT(*) as total_count,
    MAX(unit_price_silver) FILTER (WHERE auction_type = 'offer') as max_unit_price_silver_offer,
    MIN(unit_price_silver) FILTER (WHERE auction_type = 'offer') as min_unit_price_silver_offer,
    ROUND(SUM(unit_price_silver::BIGINT * amount::BIGINT) FILTER (WHERE auction_type = 'offer') / SUM(amount) FILTER (WHERE auction_type = 'offer'))::INTEGER as avg_unit_price_silver_offer,
    SUM(amount) FILTER (WHERE auction_type = 'offer') as sum_amount_offer,
    MAX(unit_price_silver) FILTER (WHERE auction_type = 'request') as max_unit_price_silver_request,
    MIN(unit_price_silver) FILTER (WHERE auction_type = 'request') as min_unit_price_silver_request,
    ROUND(SUM(unit_price_silver::BIGINT * amount::BIGINT) FILTER (WHERE auction_type = 'request') / SUM(amount) FILTER (WHERE auction_type = 'request'))::INTEGER as avg_unit_price_silver_request,
    SUM(amount) FILTER (WHERE auction_type = 'request') as sum_amount_request
FROM
    market_order
GROUP BY
    date,
    item_unique_name,
    location_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS item_prices_by_updated_at
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 hour', updated_at) as date,
    item_unique_name,
    COUNT(*) as total_count,
    MAX(unit_price_silver) FILTER (WHERE auction_type = 'offer') as max_unit_price_silver_offer,
    MIN(unit_price_silver) FILTER (WHERE auction_type = 'offer') as min_unit_price_silver_offer,
    ROUND(SUM(unit_price_silver::BIGINT * amount::BIGINT) FILTER (WHERE auction_type = 'offer') / SUM(amount) FILTER (WHERE auction_type = 'offer'))::INTEGER as avg_unit_price_silver_offer,
    SUM(amount) FILTER (WHERE auction_type = 'offer') as sum_amount_offer,
    MAX(unit_price_silver) FILTER (WHERE auction_type = 'request') as max_unit_price_silver_request,
    MIN(unit_price_silver) FILTER (WHERE auction_type = 'request') as min_unit_price_silver_request,
    ROUND(SUM(unit_price_silver::BIGINT * amount::BIGINT) FILTER (WHERE auction_type = 'request') / SUM(amount) FILTER (WHERE auction_type = 'request'))::INTEGER as avg_unit_price_silver_request,
    SUM(amount) FILTER (WHERE auction_type = 'request') as sum_amount_request
FROM
    market_order
GROUP BY
    date,
    item_unique_name;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_updated_at_and_location
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

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_updated_at
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
               continuous_aggregate := 'market_orders_count_by_updated_at',
               start_offset := INTERVAL '1 day',
               end_offset := NULL,
               schedule_interval := INTERVAL '5 minutes');

SELECT add_continuous_aggregate_policy(
               continuous_aggregate := 'market_orders_count_by_updated_at_and_location',
               start_offset := INTERVAL '1 day',
               end_offset := NULL,
               schedule_interval := INTERVAL '5 minutes');

SELECT add_continuous_aggregate_policy(
               continuous_aggregate := 'item_prices_by_updated_at',
               start_offset := INTERVAL '1 day',
               end_offset := NULL,
               schedule_interval := INTERVAL '5 minutes');

SELECT add_continuous_aggregate_policy(
               continuous_aggregate := 'item_prices_by_updated_at_and_location',
               start_offset := INTERVAL '1 day',
               end_offset := NULL,
               schedule_interval := INTERVAL '5 minutes');

SELECT add_retention_policy(
       relation := 'market_order',
       drop_after := INTERVAL '2 days',
       if_not_exists := true,
       schedule_interval := INTERVAL '5 minutes');
