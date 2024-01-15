CREATE TABLE IF NOT EXISTS item
(
    unique_name TEXT NOT NULL,
    PRIMARY KEY (unique_name)
);
CREATE TABLE IF NOT EXISTS localized_name
(
    item_unique_name TEXT NOT NULL,
    en_us            TEXT NOT NULL,
    de_de            TEXT NOT NULL,
    fr_fr            TEXT NOT NULL,
    ru_ru            TEXT NOT NULL,
    pl_pl            TEXT NOT NULL,
    es_es            TEXT NOT NULL,
    pt_br            TEXT NOT NULL,
    it_it            TEXT NOT NULL,
    zh_cn            TEXT NOT NULL,
    ko_kr            TEXT NOT NULL,
    ja_jp            TEXT NOT NULL,
    zh_tw            TEXT NOT NULL,
    id_id            TEXT NOT NULL,
    PRIMARY KEY (item_unique_name),
    FOREIGN KEY (item_unique_name) REFERENCES item (unique_name)
);
CREATE TABLE IF NOT EXISTS localized_description
(
    item_unique_name TEXT NOT NULL,
    en_us            TEXT NOT NULL,
    de_de            TEXT NOT NULL,
    fr_fr            TEXT NOT NULL,
    ru_ru            TEXT NOT NULL,
    pl_pl            TEXT NOT NULL,
    es_es            TEXT NOT NULL,
    pt_br            TEXT NOT NULL,
    it_it            TEXT NOT NULL,
    zh_cn            TEXT NOT NULL,
    ko_kr            TEXT NOT NULL,
    ja_jp            TEXT NOT NULL,
    zh_tw            TEXT NOT NULL,
    id_id            TEXT NOT NULL,
    PRIMARY KEY (item_unique_name),
    FOREIGN KEY (item_unique_name) REFERENCES item (unique_name)
);
CREATE TABLE IF NOT EXISTS location
(
    id   TEXT NOT NULL,
    name TEXT NOT NULL,
    PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS market_order
(
    id                BIGINT    NOT NULL,
    item_unique_name  TEXT      NOT NULL,
    location_id       TEXT      NOT NULL,
    quality_level     INTEGER   NOT NULL,
    enchantment_level INTEGER   NOT NULL,
    unit_price_silver INTEGER   NOT NULL,
    amount            INTEGER   NOT NULL,
    auction_type      TEXT      NOT NULL,
    expires_at        TIMESTAMP NOT NULL,
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (item_unique_name) REFERENCES item (unique_name),
    FOREIGN KEY (location_id) REFERENCES location (id)
);

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_location AS
    SELECT 
        location.name as location, 
        COUNT(*) as count 
    FROM 
        market_order, 
        location 
    WHERE 
        location_id = location.id 
    GROUP BY 
        location.name 
    ORDER BY
        count DESC;

CREATE UNIQUE INDEX IF NOT EXISTS market_orders_count_by_location_idx ON market_orders_count_by_location(location);

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_updated_at AS
    SELECT
        DATE_TRUNC('hour', updated_at) AS updated_at,
        COUNT(*) as count
    FROM
        market_order
    WHERE
        expires_at > NOW()
    GROUP BY
        DATE_TRUNC('hour', updated_at)
    ORDER BY
        updated_at DESC;

CREATE UNIQUE INDEX IF NOT EXISTS market_orders_count_by_updated_at_idx ON market_orders_count_by_updated_at(updated_at);

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_updated_at_and_location AS
    SELECT
        DATE_TRUNC('hour', updated_at) AS updated_at,
        location.name as location,
        COUNT(*) as count
    FROM
        market_order,
        location
    WHERE
        location_id = location.id
        AND expires_at > NOW()
    GROUP BY
        DATE_TRUNC('hour', updated_at),
        location.name
    ORDER BY
        updated_at DESC;

CREATE UNIQUE INDEX IF NOT EXISTS market_orders_count_by_updated_at_and_location_idx ON market_orders_count_by_updated_at_and_location(location, updated_at);

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_created_at AS
    SELECT
        DATE_TRUNC('hour', created_at) AS created_at,
        COUNT(*) as count
    FROM
        market_order
    WHERE
        expires_at > NOW()
    GROUP BY
        DATE_TRUNC('hour', created_at)
    ORDER BY
        created_at DESC;

CREATE UNIQUE INDEX IF NOT EXISTS market_orders_count_by_created_at_idx ON market_orders_count_by_created_at(created_at);

CREATE MATERIALIZED VIEW IF NOT EXISTS market_orders_count_by_created_at_and_location AS
    SELECT
        DATE_TRUNC('hour', created_at) AS created_at,
        location.name as location,
        COUNT(*) as count
    FROM
        market_order,
        location
    WHERE
        location_id = location.id
        AND expires_at > NOW()
    GROUP BY
        DATE_TRUNC('hour', created_at),
        location.name
    ORDER BY
        created_at DESC;

CREATE UNIQUE INDEX IF NOT EXISTS market_orders_count_by_created_at_and_location_idx ON market_orders_count_by_created_at_and_location(location, created_at);

CREATE INDEX IF NOT EXISTS market_orders_auction_type_idx ON market_order(auction_type);
