CREATE
OR REPLACE TEMP VIEW election AS
SELECT
    NUTS3,
    NUTS_name,
    Registered,
    Turnout,
    Turnout * 100.0 / Registered AS turnout_pct,
    winner,
    winner_share,
    "SPOLU – ODS, KDU-ČSL, TOP 09" AS spolu_share,
    "ANO 2011" AS ano_share,
    "Svoboda a př. demokracie (SPD)" AS spd_share,
    "PIRÁTI a STAROSTOVÉ" AS pirates_stan_share
FROM
    read_csv_auto(
        'data/elections/legrandcontinent_tchequie/t0lWU.data.csv'
    );

CREATE
OR REPLACE TEMP VIEW projects AS
SELECT
    *
FROM
    read_csv_auto(
        'data/kohesio_current/CZ_projects_2014_2020.csv',
        union_by_name = true
    )
UNION
ALL BY NAME
SELECT
    *
FROM
    read_csv_auto(
        'data/kohesio_current/CZ_projects_2021_2027.csv',
        union_by_name = true
    );

CREATE
OR REPLACE TEMP VIEW kohesio_by_nuts3 AS
SELECT
    NUTS3_Code AS nuts3,
    COUNT(DISTINCT Operation_Unique_Identifier) AS project_count,
    COUNT(DISTINCT Beneficiary_Unique_Identifier) AS beneficiary_count,
    SUM(Total_Eligible_Expenditure_amount) AS eligible_amount,
    SUM(Project_EU_Budget) AS eu_budget
FROM
    projects
WHERE
    NUTS3_Code IS NOT NULL
GROUP BY
    1;

CREATE
OR REPLACE TEMP VIEW pop AS WITH pop_raw AS (
    SELECT
        *,
        split_part("freq,unit,sex,age,geo\TIME_PERIOD", ',', -1) AS nuts
    FROM
        read_csv(
            'data/population/estat_demo_r_pjanaggr3.tsv',
            delim = '\t',
            header = true
        )
    WHERE
        "freq,unit,sex,age,geo\TIME_PERIOD" LIKE '%T,TOTAL%'
)
SELECT
    nuts,
    CAST(
        coalesce(
            nullif(regexp_extract("2023", '\d+', 0), ''),
            nullif(regexp_extract("2022", '\d+', 0), ''),
            nullif(regexp_extract("2021", '\d+', 0), '')
        ) AS DOUBLE
    ) AS pop
FROM
    pop_raw;

CREATE
OR REPLACE TEMP VIEW gdp AS WITH gdp_raw AS (
    SELECT
        *,
        split_part("freq,unit,geo\TIME_PERIOD", ',', -1) AS nuts
    FROM
        read_csv(
            'data/population/estat_nama_10r_3gdp.tsv',
            delim = '\t',
            header = true
        )
    WHERE
        "freq,unit,geo\TIME_PERIOD" LIKE '%EUR_HAB,%'
)
SELECT
    nuts,
    CAST(
        coalesce(
            nullif(regexp_extract("2021", '\d+', 0), ''),
            nullif(regexp_extract("2020", '\d+', 0), ''),
            nullif(regexp_extract("2019", '\d+', 0), '')
        ) AS DOUBLE
    ) AS gdp_per_capita
FROM
    gdp_raw;

CREATE
OR REPLACE TEMP VIEW joined AS
SELECT
    e.*,
    p.pop,
    g.gdp_per_capita,
    k.project_count,
    k.beneficiary_count,
    k.eligible_amount,
    k.eu_budget,
    k.eu_budget / p.pop AS eu_budget_per_capita,
    k.eligible_amount / p.pop AS eligible_per_capita,
    k.project_count * 100000.0 / p.pop AS projects_per_100k
FROM
    election e
    LEFT JOIN kohesio_by_nuts3 k ON k.nuts3 = e.NUTS3
    LEFT JOIN pop p ON p.nuts = e.NUTS3
    LEFT JOIN gdp g ON g.nuts = e.NUTS3;

COPY joined TO 'data/kohesio_current/czech_nuts3_joined_analysis.csv' (HEADER, DELIMITER ',');

SELECT
    COUNT(*) AS nuts3_regions,
    SUM(project_count) AS projects,
    SUM(beneficiary_count) AS beneficiaries_nuts_sum,
    ROUND(SUM(eu_budget), 0) AS eu_budget,
    ROUND(SUM(eligible_amount), 0) AS eligible_amount,
    ROUND(AVG(gdp_per_capita), 0) AS avg_gdp_pc,
    ROUND(AVG(eu_budget_per_capita), 0) AS avg_eu_budget_pc
FROM
    joined;

SELECT
    ROUND(corr(gdp_per_capita, spolu_share), 3) AS corr_gdp_spolu,
    ROUND(corr(gdp_per_capita, ano_share), 3) AS corr_gdp_ano,
    ROUND(corr(gdp_per_capita, spd_share), 3) AS corr_gdp_spd,
    ROUND(corr(gdp_per_capita, turnout_pct), 3) AS corr_gdp_turnout,
    ROUND(corr(eu_budget_per_capita, gdp_per_capita), 3) AS corr_eu_budget_pc_gdp,
    ROUND(corr(eu_budget_per_capita, spolu_share), 3) AS corr_eu_budget_pc_spolu,
    ROUND(corr(eu_budget_per_capita, ano_share), 3) AS corr_eu_budget_pc_ano,
    ROUND(corr(eu_budget_per_capita, spd_share), 3) AS corr_eu_budget_pc_spd,
    ROUND(corr(projects_per_100k, turnout_pct), 3) AS corr_projects_density_turnout
FROM
    joined;

SELECT
    winner,
    COUNT(*) AS regions,
    ROUND(AVG(gdp_per_capita), 0) AS avg_gdp_pc,
    ROUND(AVG(turnout_pct), 1) AS avg_turnout_pct,
    ROUND(AVG(eu_budget_per_capita), 0) AS avg_eu_budget_pc,
    ROUND(AVG(projects_per_100k), 1) AS avg_projects_per_100k
FROM
    joined
GROUP BY
    1
ORDER BY
    regions DESC,
    winner;

SELECT
    NUTS3,
    NUTS_name,
    winner,
    ROUND(gdp_per_capita, 0) AS gdp_pc,
    ROUND(turnout_pct, 1) AS turnout_pct,
    ROUND(spolu_share * 100, 1) AS spolu_pct,
    ROUND(ano_share * 100, 1) AS ano_pct,
    ROUND(spd_share * 100, 1) AS spd_pct,
    ROUND(eu_budget_per_capita, 0) AS eu_budget_pc,
    ROUND(projects_per_100k, 1) AS projects_per_100k
FROM
    joined
ORDER BY
    eu_budget_per_capita DESC
LIMIT
    6;

SELECT
    NUTS3,
    NUTS_name,
    winner,
    ROUND(gdp_per_capita, 0) AS gdp_pc,
    ROUND(turnout_pct, 1) AS turnout_pct,
    ROUND(spolu_share * 100, 1) AS spolu_pct,
    ROUND(ano_share * 100, 1) AS ano_pct,
    ROUND(spd_share * 100, 1) AS spd_pct,
    ROUND(eu_budget_per_capita, 0) AS eu_budget_pc,
    ROUND(projects_per_100k, 1) AS projects_per_100k
FROM
    joined
ORDER BY
    gdp_per_capita DESC;