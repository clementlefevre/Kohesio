-- Export data as Apache Arrow IPC files for the DuckDB-WASM dashboard
-- ── 1. Election + GDP + population master table (all countries, NUTS3) ────────
COPY (
    SELECT
        country_code,
        nuts_code,
        region_name,
        eu_ned_election_year,
        eu_ned_winner_party,
        eu_ned_winner_party_en,
        eu_ned_winner_share_pct,
        eu_ned_turnout_pct,
        lgc_election_year,
        lgc_winner,
        lgc_winner_share_pct,
        lgc_turnout_pct,
        latest_winner,
        latest_election_year,
        ep_group_id,
        ep_group_acronym,
        population,
        gdp_per_capita_eur,
        -- best available winner share and turnout across sources
        COALESCE(lgc_winner_share_pct, eu_ned_winner_share_pct) AS winner_share_pct,
        COALESCE(lgc_turnout_pct, eu_ned_turnout_pct) AS turnout_pct
    FROM
        read_parquet('data/analysis/master_nuts3.parquet')
    WHERE
        nuts_code IS NOT NULL
    ORDER BY
        country_code,
        nuts_code
) TO 'data/analysis/election_nuts3.arrow' (FORMAT ARROW);

-- ── 2. Kohesio projects aggregated per NUTS3 + programming period (CZ) ────────
COPY (
    WITH all_projects AS (
        SELECT
            Operation_Unique_Identifier,
            NUTS3_Code,
            NUTS3_Label,
            Programming_Period,
            Total_Eligible_Expenditure_amount,
            Project_EU_Budget,
            Cofinancing_Rate
        FROM
            read_csv_auto('data/kohesio_current/CZ_projects_2014_2020.csv')
        UNION
        ALL
        SELECT
            Operation_Unique_Identifier,
            NUTS3_Code,
            NUTS3_Label,
            Programming_Period,
            Total_Eligible_Expenditure_amount,
            Project_EU_Budget,
            Cofinancing_Rate
        FROM
            read_csv_auto('data/kohesio_current/CZ_projects_2021_2027.csv')
    ),
    deduped AS (
        SELECT
            Operation_Unique_Identifier,
            NUTS3_Code,
            NUTS3_Label,
            Programming_Period,
            Total_Eligible_Expenditure_amount,
            Project_EU_Budget,
            Cofinancing_Rate
        FROM
            (
                SELECT
                    *,
                    ROW_NUMBER() OVER (PARTITION BY Operation_Unique_Identifier) AS rn
                FROM
                    all_projects
            ) t
        WHERE
            rn = 1
    )
    SELECT
        NUTS3_Code AS nuts_code,
        'CZ' :: VARCHAR AS country_code,
        Programming_Period AS programming_period,
        ANY_VALUE(NUTS3_Label) AS nuts3_label,
        COUNT(DISTINCT Operation_Unique_Identifier) AS project_count,
        ROUND(SUM(Total_Eligible_Expenditure_amount), 0) AS total_expenditure_eur,
        ROUND(SUM(Project_EU_Budget), 0) AS total_eu_budget_eur,
        ROUND(AVG(Cofinancing_Rate), 1) AS avg_cofinancing_pct
    FROM
        deduped
    WHERE
        NUTS3_Code IS NOT NULL
        AND NUTS3_Code != ''
    GROUP BY
        1,
        2,
        3
    ORDER BY
        1,
        3
) TO 'data/analysis/kohesio_nuts3.arrow' (FORMAT ARROW);

-- Validation
SELECT
    'election_nuts3' AS table_name,
    COUNT(*) AS rows,
    COUNT(DISTINCT country_code) AS countries
FROM
    read_arrow('data/analysis/election_nuts3.arrow')
UNION
ALL
SELECT
    'kohesio_nuts3',
    COUNT(*),
    COUNT(DISTINCT country_code)
FROM
    read_arrow('data/analysis/kohesio_nuts3.arrow');