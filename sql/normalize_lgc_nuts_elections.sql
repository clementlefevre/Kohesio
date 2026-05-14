CREATE
OR REPLACE MACRO number_value(value) AS TRY_CAST(
    replace(CAST(value AS VARCHAR), ',', '.') AS DOUBLE
);

CREATE
OR REPLACE MACRO share_percent(value) AS CASE
    WHEN number_value(value) IS NULL THEN NULL
    WHEN number_value(value) <= 1 THEN number_value(value) * 100
    WHEN number_value(value) > 100 THEN number_value(value) / 100
    ELSE number_value(value)
END;

CREATE
OR REPLACE TEMP VIEW be_nuts2_codes AS
SELECT
    *
FROM
    (
        VALUES
            ('Prov. Antwerpen', 'BE21'),
            ('Prov. Limburg (BE)', 'BE22'),
            ('Prov. Oost-Vlaanderen', 'BE23'),
            ('Prov. Vlaams-Brabant', 'BE24'),
            ('Prov. West-Vlaanderen', 'BE25'),
            ('Prov. Brabant Wallon', 'BE31'),
            ('Prov. Hainaut', 'BE32'),
            ('Prov. Liège', 'BE33'),
            ('Prov. Luxembourg (BE)', 'BE34'),
            ('Prov. Namur', 'BE35'),
            (
                'Région de Bruxelles-Capitale/ Brussels Hoofdstedelijk Gewest',
                'BE10'
            )
    ) AS mapping(region_key, nuts_code);

CREATE
OR REPLACE TEMP VIEW bg_nuts3_codes AS
SELECT
    *
FROM
    (
        VALUES
            ('Видин', 'BG311'),
            ('Монтана', 'BG312'),
            ('Враца', 'BG313'),
            ('Плевен', 'BG314'),
            ('Ловеч', 'BG315'),
            ('Велико Търново', 'BG321'),
            ('Габрово', 'BG322'),
            ('Русе', 'BG323'),
            ('Разград', 'BG324'),
            ('Силистра', 'BG325'),
            ('Варна', 'BG331'),
            ('Добрич', 'BG332'),
            ('Шумен', 'BG333'),
            ('Търговище', 'BG334'),
            ('Бургас', 'BG341'),
            ('Сливен', 'BG342'),
            ('Ямбол', 'BG343'),
            ('Стара Загора', 'BG344'),
            ('София (столица)', 'BG411'),
            ('София', 'BG412'),
            ('Благоевград', 'BG413'),
            ('Перник', 'BG414'),
            ('Кюстендил', 'BG415'),
            ('Пловдив', 'BG421'),
            ('Хасково', 'BG422'),
            ('Пазарджик', 'BG423'),
            ('Смолян', 'BG424'),
            ('Кърджали', 'BG425')
    ) AS mapping(region_key, nuts_code);

CREATE
OR REPLACE TEMP VIEW de_nuts3_labels AS
SELECT
    nuts3code,
    any_value(nuts3Label) AS nuts3Label
FROM
    read_csv(
        'data/kohesio_current/nuts/DE-20260317.csv',
        delim = ',',
        quote = '"',
        escape = '"',
        header = true,
        all_varchar = true
    )
GROUP BY
    1;

CREATE
OR REPLACE TEMP VIEW es_nuts3_labels AS
SELECT
    nuts3code,
    any_value(nuts3Label) AS nuts3Label
FROM
    read_csv(
        'data/kohesio_current/nuts/ES-20260317.csv',
        delim = ',',
        quote = '"',
        escape = '"',
        header = true,
        all_varchar = true
    )
GROUP BY
    1;

CREATE
OR REPLACE TEMP VIEW normalized_nuts_elections AS
SELECT
    'BE' AS country_code,
    'belgique' AS slug,
    'NEg15' AS chart_id,
    'legislative' AS election_family,
    2019 AS election_year,
    'NUTS2' AS nuts_level,
    m.nuts_code,
    e.nuts_name AS region_name,
    number_value(e.registered) AS registered,
    number_value(e.confirmed) AS turnout,
    number_value(e."Turnout (%)") AS turnout_pct,
    NULL AS winner,
    NULL AS winner_share_pct,
    NULL AS winner_color,
    'turnout' AS source_metric,
    'data/elections/raw/legrandcontinent/belgique/NEg15.data.csv' AS source_path
FROM
    read_csv(
        'data/elections/raw/legrandcontinent/belgique/NEg15.data.csv',
        delim = ',',
        quote = '"',
        escape = '"',
        header = true,
        all_varchar = true
    ) e
    LEFT JOIN be_nuts2_codes m ON m.region_key = e.NUTS2
UNION
ALL
SELECT
    'BG' AS country_code,
    'bulgarie' AS slug,
    '97EWM' AS chart_id,
    'legislative' AS election_family,
    2024 AS election_year,
    'NUTS3' AS nuts_level,
    m.nuts_code,
    e.NUTS_NAME AS region_name,
    NULL AS registered,
    NULL AS turnout,
    NULL AS turnout_pct,
    e.winner,
    share_percent(e.winner_share) AS winner_share_pct,
    NULL AS winner_color,
    'winner' AS source_metric,
    'data/elections/raw/legrandcontinent/bulgarie/97EWM.data.csv' AS source_path
FROM
    read_csv(
        'data/elections/raw/legrandcontinent/bulgarie/97EWM.data.csv',
        delim = ',',
        quote = '"',
        escape = '"',
        header = true,
        all_varchar = true
    ) e
    LEFT JOIN bg_nuts3_codes m ON m.region_key = e.NUTS_NAME
UNION
ALL
SELECT
    'CZ' AS country_code,
    'tchequie' AS slug,
    't0lWU' AS chart_id,
    'legislative' AS election_family,
    2021 AS election_year,
    'NUTS3' AS nuts_level,
    e.NUTS3 AS nuts_code,
    e.NUTS_name AS region_name,
    number_value(e.Registered) AS registered,
    number_value(e.Turnout) AS turnout,
    number_value(e.Turnout) * 100.0 / nullif(number_value(e.Registered), 0) AS turnout_pct,
    e.winner,
    share_percent(e.winner_share) AS winner_share_pct,
    e.winner_color,
    'winner_turnout' AS source_metric,
    'data/elections/raw/legrandcontinent/tchequie/t0lWU.data.csv' AS source_path
FROM
    read_csv(
        'data/elections/raw/legrandcontinent/tchequie/t0lWU.data.csv',
        delim = ',',
        quote = '"',
        escape = '"',
        header = true,
        all_varchar = true
    ) e
UNION
ALL
SELECT
    'DE' AS country_code,
    'allemagne' AS slug,
    'CUOqk' AS chart_id,
    'legislative' AS election_family,
    2021 AS election_year,
    'NUTS3' AS nuts_level,
    e.NUTS3 AS nuts_code,
    n.nuts3Label AS region_name,
    number_value(e.Registered) AS registered,
    number_value(e.Turnout) AS turnout,
    number_value(e.Turnout) * 100.0 / nullif(number_value(e.Registered), 0) AS turnout_pct,
    e.winner,
    share_percent(e.winner_share) AS winner_share_pct,
    e.winner_color,
    'winner_turnout' AS source_metric,
    'data/elections/raw/legrandcontinent/allemagne/CUOqk.data.csv' AS source_path
FROM
    read_csv(
        'data/elections/raw/legrandcontinent/allemagne/CUOqk.data.csv',
        delim = ',',
        quote = '"',
        escape = '"',
        header = true,
        all_varchar = true
    ) e
    LEFT JOIN de_nuts3_labels n ON n.nuts3code = e.NUTS3
UNION
ALL
SELECT
    'ES' AS country_code,
    'espagne' AS slug,
    'e8O9D' AS chart_id,
    'legislative' AS election_family,
    2023 AS election_year,
    'NUTS3' AS nuts_level,
    e.NUTS3 AS nuts_code,
    n.nuts3Label AS region_name,
    number_value(e.Registered) AS registered,
    number_value(e.Turnout) AS turnout,
    number_value(e.Turnout) * 100.0 / nullif(number_value(e.Registered), 0) AS turnout_pct,
    e.winner,
    share_percent(e.winner_share) AS winner_share_pct,
    e.winner_color,
    'winner_turnout' AS source_metric,
    'data/elections/raw/legrandcontinent/espagne/e8O9D.data.csv' AS source_path
FROM
    read_csv(
        'data/elections/raw/legrandcontinent/espagne/e8O9D.data.csv',
        delim = ',',
        quote = '"',
        escape = '"',
        header = true,
        all_varchar = true
    ) e
    LEFT JOIN es_nuts3_labels n ON n.nuts3code = e.NUTS3
UNION
ALL
SELECT
    'IT' AS country_code,
    'italie' AS slug,
    '8mYA2' AS chart_id,
    'legislative' AS election_family,
    2022 AS election_year,
    'NUTS3' AS nuts_level,
    e.NUTS3 AS nuts_code,
    e.nuts_name AS region_name,
    number_value(e.Registered) AS registered,
    number_value(e.Turnout) AS turnout,
    number_value(e."Turnout (%)") AS turnout_pct,
    e.winner,
    share_percent(e.winner_share) AS winner_share_pct,
    e.winner_color,
    'winner_turnout' AS source_metric,
    'data/elections/raw/legrandcontinent/italie/8mYA2.data.csv' AS source_path
FROM
    read_csv(
        'data/elections/raw/legrandcontinent/italie/8mYA2.data.csv',
        delim = ',',
        quote = '"',
        escape = '"',
        header = true,
        all_varchar = true
    ) e;

COPY (
    SELECT
        *
    FROM
        normalized_nuts_elections
    ORDER BY
        country_code,
        nuts_level,
        nuts_code
) TO 'data/elections/normalized/lgc_nuts_elections.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT
        country_code,
        slug,
        chart_id,
        election_year,
        nuts_level,
        COUNT(*) AS rows,
        COUNT(*) FILTER (
            WHERE
                nuts_code IS NULL
        ) AS missing_nuts_code,
        COUNT(*) FILTER (
            WHERE
                turnout_pct IS NOT NULL
        ) AS rows_with_turnout,
        COUNT(*) FILTER (
            WHERE
                winner IS NOT NULL
        ) AS rows_with_winner
    FROM
        normalized_nuts_elections
    GROUP BY
        1,
        2,
        3,
        4,
        5
    ORDER BY
        country_code,
        chart_id
) TO 'data/elections/normalized/lgc_nuts_elections_coverage.csv' (HEADER, DELIMITER ',');

SELECT
    country_code,
    slug,
    chart_id,
    election_year,
    nuts_level,
    COUNT(*) AS rows,
    COUNT(*) FILTER (
        WHERE
            nuts_code IS NULL
    ) AS missing_nuts_code,
    COUNT(*) FILTER (
        WHERE
            turnout_pct IS NOT NULL
    ) AS rows_with_turnout,
    COUNT(*) FILTER (
        WHERE
            winner IS NOT NULL
    ) AS rows_with_winner
FROM
    normalized_nuts_elections
GROUP BY
    1,
    2,
    3,
    4,
    5
ORDER BY
    country_code,
    chart_id;