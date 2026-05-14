-- =============================================================================
-- Master NUTS3 analysis table
-- Joins: EU-NED latest election winners  (NUTS 2016, bridged to 2021)
--         LGC normalized elections        (NUTS 2021, most-recent per country)
--         HU 2022 LAU-aggregated          (NUTS 2021)
--         Eurostat population             (NUTS 2021)
--         Eurostat GDP per capita         (NUTS 2021)
--         EP party-group mapping          (national level, by year)
-- Output: data/analysis/master_nuts3.parquet
--         data/analysis/master_nuts3.csv
-- =============================================================================
-- ── helpers ──────────────────────────────────────────────────────────────────
CREATE
OR REPLACE MACRO parse_num(v) AS TRY_CAST(replace(CAST(v AS VARCHAR), ',', '.') AS DOUBLE);

-- ── NUTS 2016 → 2021 bridge (NUTS3 only) ─────────────────────────────────────
CREATE
OR REPLACE TEMP VIEW nuts_bridge AS
SELECT
    nuts_code_2016,
    nuts_code_2021,
    change_code
FROM
    read_csv_auto('data/population/nuts_2016_to_2021.csv')
WHERE
    nuts_level = 3;

-- ── Eurostat population (latest year available, NUTS3) ────────────────────────
CREATE
OR REPLACE TEMP VIEW eurostat_pop AS WITH raw AS (
    SELECT
        trim(
            split_part("freq,unit,sex,age,geo\TIME_PERIOD", ',', -1)
        ) AS nuts_code,
        "2023" AS y2023,
        "2022" AS y2022,
        "2021" AS y2021
    FROM
        read_csv(
            'data/population/estat_demo_r_pjanaggr3.tsv',
            delim = chr(9),
            header = true
        )
    WHERE
        "freq,unit,sex,age,geo\TIME_PERIOD" LIKE '%T,TOTAL%'
        AND length(
            trim(
                split_part("freq,unit,sex,age,geo\TIME_PERIOD", ',', -1)
            )
        ) = 5
)
SELECT
    nuts_code,
    COALESCE(
        TRY_CAST(regexp_extract(y2023, '\d+', 0) AS DOUBLE),
        TRY_CAST(regexp_extract(y2022, '\d+', 0) AS DOUBLE),
        TRY_CAST(regexp_extract(y2021, '\d+', 0) AS DOUBLE)
    ) AS population
FROM
    raw;

-- ── Eurostat GDP per capita EUR/hab (latest year available, NUTS3) ────────────
CREATE
OR REPLACE TEMP VIEW eurostat_gdp AS WITH raw AS (
    SELECT
        trim(split_part("freq,unit,geo\TIME_PERIOD", ',', -1)) AS nuts_code,
        "2021" AS y2021,
        "2020" AS y2020,
        "2019" AS y2019
    FROM
        read_csv(
            'data/population/estat_nama_10r_3gdp.tsv',
            delim = chr(9),
            header = true
        )
    WHERE
        "freq,unit,geo\TIME_PERIOD" LIKE '%EUR_HAB,%'
        AND length(
            trim(split_part("freq,unit,geo\TIME_PERIOD", ',', -1))
        ) = 5
)
SELECT
    nuts_code,
    COALESCE(
        TRY_CAST(regexp_extract(y2021, '\d+', 0) AS DOUBLE),
        TRY_CAST(regexp_extract(y2020, '\d+', 0) AS DOUBLE),
        TRY_CAST(regexp_extract(y2019, '\d+', 0) AS DOUBLE)
    ) AS gdp_per_capita_eur
FROM
    raw;

-- ── EU-NED latest election winners, bridged to NUTS 2021 ─────────────────────
CREATE
OR REPLACE TEMP VIEW eu_ned_parliament AS
SELECT
    w.country_code,
    w.country,
    COALESCE(b.nuts_code_2021, w.nuts_code) AS nuts_code,
    -- prefer 2021, fall back if already 2021
    w.nuts_code AS nuts_code_2016,
    b.change_code AS nuts_version_change,
    w.region_name,
    w.election_type,
    w.election_year AS eu_ned_election_year,
    w.party_abbreviation AS eu_ned_winner_party,
    w.party_english AS eu_ned_winner_party_en,
    w.party_vote_share_pct AS eu_ned_winner_share_pct,
    w.turnout_pct AS eu_ned_turnout_pct,
    w.valid_vote,
    w.total_vote,
    w.electorate
FROM
    read_parquet(
        'data/elections/eu_ned/eu_ned_latest_winners.parquet'
    ) w
    LEFT JOIN nuts_bridge b ON b.nuts_code_2016 = w.nuts_code
WHERE
    w.nuts_level = 3
    AND w.election_type = 'Parliament';

-- ── LGC normalized elections (most-recent per country, NUTS3 only) ─────────────
CREATE
OR REPLACE TEMP VIEW lgc_nuts3 AS
SELECT
    country_code,
    nuts_code,
    region_name AS lgc_region_name,
    election_year AS lgc_election_year,
    turnout_pct AS lgc_turnout_pct,
    winner AS lgc_winner,
    winner_share_pct AS lgc_winner_share_pct
FROM
    read_csv_auto(
        'data/elections/normalized/lgc_nuts_elections.csv'
    )
WHERE
    nuts_level = 'NUTS3';

-- ── HU 2022 (fills the EU-NED gap for 2022 Hungarian election) ───────────────
CREATE
OR REPLACE TEMP VIEW hu_2022 AS
SELECT
    'HU' AS country_code,
    nuts3_code AS nuts_code,
    2022 AS lgc_election_year,
    turnout_pct AS lgc_turnout_pct,
    winner AS lgc_winner,
    CASE
        winner
        WHEN 'FIDESZ-KDNP' THEN fidesz_pct
        WHEN 'EM' THEN em_pct
        ELSE mnoö_pct
    END AS lgc_winner_share_pct
FROM
    read_csv_auto(
        'data/elections/normalized/HU_nuts3_2022_legislative.csv'
    );

-- ── EP party-group mapping (election-results phase) ──────────────────────────
-- We attach EP group to the EU-NED winner party via approximate key:
-- country_id + party_acronym + term that covers the election year
CREATE
OR REPLACE TEMP VIEW ep_group_map AS
SELECT
    country_id,
    party_acronym,
    CAST(left(term, 4) AS INTEGER) AS term_start,
    CAST(right(term, 4) AS INTEGER) AS term_end,
    ep_group_id,
    ep_group_acronym
FROM
    read_csv_auto(
        'data/elections/raw/european_parliament_results/party_group_mapping.csv'
    )
WHERE
    phase = 'election-results'
    AND ep_group_id IS NOT NULL
    AND candidate_type != 'COALITION';

-- ── Supplemental EP group overrides (covers acronym / country-code mismatches) ─
CREATE
OR REPLACE TEMP VIEW ep_group_supplement AS
SELECT
    country_code,
    ned_party_name,
    ep_group_acronym
FROM
    read_csv_auto(
        'data/elections/supplements/party_ep_group_overrides.csv'
    );

-- ── Master assembly ───────────────────────────────────────────────────────────
CREATE
OR REPLACE TEMP VIEW master AS WITH -- collect all NUTS3 codes with population (canonical universe)
nuts_universe AS (
    SELECT
        nuts_code,
        population
    FROM
        eurostat_pop
    WHERE
        nuts_code IS NOT NULL
        AND length(nuts_code) = 5
),
-- EU-NED Parliament winner per NUTS3
ned AS (
    SELECT
        *
    FROM
        eu_ned_parliament
),
-- latest LGC entry per NUTS3 (prefer HU 2022 over EU-NED for HU)
lgc_combined AS (
    SELECT
        country_code,
        nuts_code,
        lgc_region_name,
        lgc_election_year,
        lgc_turnout_pct,
        lgc_winner,
        lgc_winner_share_pct
    FROM
        lgc_nuts3
    UNION
    ALL
    SELECT
        country_code,
        nuts_code,
        NULL AS lgc_region_name,
        lgc_election_year,
        lgc_turnout_pct,
        lgc_winner,
        lgc_winner_share_pct
    FROM
        hu_2022
),
-- EP group for each EU-NED winner (best matching term)
ep_grp AS (
    SELECT
        DISTINCT ON (country_id, party_acronym, term_start) country_id,
        party_acronym,
        term_start,
        term_end,
        ep_group_id,
        ep_group_acronym
    FROM
        ep_group_map
)
SELECT
    -- geography
    COALESCE(ned.country_code, lgc.country_code) AS country_code,
    COALESCE(ned.nuts_code, lgc.nuts_code) AS nuts_code,
    COALESCE(ned.region_name, lgc.lgc_region_name) AS region_name,
    -- EU-NED (historical, latest available)
    ned.eu_ned_election_year,
    ned.eu_ned_winner_party,
    ned.eu_ned_winner_party_en,
    ned.eu_ned_winner_share_pct,
    ned.eu_ned_turnout_pct,
    ned.nuts_version_change,
    -- LGC / HU 2022 (more recent)
    lgc.lgc_election_year,
    lgc.lgc_winner,
    lgc.lgc_winner_share_pct,
    lgc.lgc_turnout_pct,
    -- convenience: most-recent winner regardless of source
    CASE
        WHEN lgc.lgc_election_year IS NOT NULL
        AND (
            ned.eu_ned_election_year IS NULL
            OR lgc.lgc_election_year >= ned.eu_ned_election_year
        ) THEN lgc.lgc_winner
        ELSE ned.eu_ned_winner_party
    END AS latest_winner,
    CASE
        WHEN lgc.lgc_election_year IS NOT NULL
        AND (
            ned.eu_ned_election_year IS NULL
            OR lgc.lgc_election_year >= ned.eu_ned_election_year
        ) THEN lgc.lgc_election_year
        ELSE ned.eu_ned_election_year
    END AS latest_election_year,
    -- NED winner EP group (BLUE join first, supplement fallback)
    COALESCE(
        ned_grp.ep_group_acronym,
        ned_supp.ep_group_acronym
    ) AS ned_ep_group_acronym,
    -- LGC winner EP group (supplement lookup)
    lgc_supp.ep_group_acronym AS lgc_ep_group_acronym,
    -- socioeconomic
    pop.population,
    gdp.gdp_per_capita_eur
FROM
    ned FULL
    OUTER JOIN lgc_combined lgc ON lgc.nuts_code = ned.nuts_code
    AND lgc.country_code = ned.country_code
    LEFT JOIN nuts_universe pop ON pop.nuts_code = COALESCE(ned.nuts_code, lgc.nuts_code)
    LEFT JOIN eurostat_gdp gdp ON gdp.nuts_code = COALESCE(ned.nuts_code, lgc.nuts_code) -- NED EP group: BLUE CSV join first, supplement fallback
    LEFT JOIN ep_grp ned_grp ON ned_grp.country_id = COALESCE(ned.country_code, lgc.country_code)
    AND ned_grp.party_acronym = ned.eu_ned_winner_party
    AND ned_grp.term_start <= COALESCE(ned.eu_ned_election_year, 2019)
    AND ned_grp.term_end >= COALESCE(ned.eu_ned_election_year, 2004)
    LEFT JOIN ep_group_supplement ned_supp ON ned_supp.country_code = COALESCE(ned.country_code, lgc.country_code)
    AND ned_supp.ned_party_name = ned.eu_ned_winner_party -- LGC EP group: supplement lookup on lgc_winner
    LEFT JOIN ep_group_supplement lgc_supp ON lgc_supp.country_code = COALESCE(ned.country_code, lgc.country_code)
    AND lgc_supp.ned_party_name = lgc.lgc_winner;

-- ── Write outputs ─────────────────────────────────────────────────────────────
CREATE
OR REPLACE TABLE master_nuts3 AS
SELECT
    *
FROM
    master;

COPY master_nuts3 TO 'data/analysis/master_nuts3.parquet' (FORMAT PARQUET);

COPY (
    SELECT
        *
    FROM
        master_nuts3
    ORDER BY
        country_code,
        nuts_code
) TO 'data/analysis/master_nuts3.csv' (HEADER, DELIMITER ',');

-- ── Quick validation summary ──────────────────────────────────────────────────
SELECT
    country_code,
    count(*) AS nuts3_regions,
    count(eu_ned_election_year) AS with_eu_ned,
    count(lgc_election_year) AS with_lgc,
    count(population) AS with_pop,
    count(gdp_per_capita_eur) AS with_gdp,
    count(ned_ep_group_acronym) AS with_ned_ep_group,
    count(lgc_ep_group_acronym) AS with_lgc_ep_group,
    max(eu_ned_election_year) AS ned_latest_year,
    max(lgc_election_year) AS lgc_latest_year
FROM
    master_nuts3
GROUP BY
    1
ORDER BY
    1;