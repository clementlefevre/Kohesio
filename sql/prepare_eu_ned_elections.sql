CREATE
OR REPLACE TEMP VIEW eu_ned_raw AS
SELECT
    country,
    country_code,
    TRY_CAST(nutslevel AS INTEGER) AS nuts_level,
    nuts2016 AS nuts_code,
    regionname AS region_name,
    type AS election_type,
    TRY_CAST(year AS INTEGER) AS election_year,
    party_abbreviation,
    party_english,
    party_native,
    TRY_CAST(partyfacts_id AS INTEGER) AS partyfacts_id,
    TRY_CAST(partyvote AS DOUBLE) AS party_vote,
    TRY_CAST(electorate AS DOUBLE) AS electorate,
    TRY_CAST(totalvote AS DOUBLE) AS total_vote,
    TRY_CAST(validvote AS DOUBLE) AS valid_vote
FROM
    read_csv(
        'data/elections/eu_ned/eu_ned_joint.tab',
        delim = '\t',
        quote = '"',
        escape = '"',
        header = true,
        all_varchar = true,
        strict_mode = false
    );

CREATE
OR REPLACE TEMP VIEW eu_ned_party_results AS
SELECT
    *,
    party_vote / NULLIF(valid_vote, 0) AS party_vote_share,
    party_vote * 100.0 / NULLIF(valid_vote, 0) AS party_vote_share_pct,
    total_vote * 100.0 / NULLIF(electorate, 0) AS turnout_pct
FROM
    eu_ned_raw
WHERE
    nuts_code IS NOT NULL
    AND election_year IS NOT NULL;

CREATE
OR REPLACE TEMP VIEW eu_ned_winners AS
SELECT
    * EXCLUDE (winner_rank)
FROM
    (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY country_code,
                election_type,
                election_year,
                nuts_level,
                nuts_code
                ORDER BY
                    party_vote DESC NULLS LAST,
                    party_abbreviation
            ) AS winner_rank
        FROM
            eu_ned_party_results
    ) ranked
WHERE
    winner_rank = 1;

CREATE
OR REPLACE TEMP VIEW eu_ned_latest_winners AS
SELECT
    w.*
FROM
    eu_ned_winners w
    INNER JOIN (
        SELECT
            country_code,
            election_type,
            nuts_level,
            MAX(election_year) AS latest_year
        FROM
            eu_ned_winners
        GROUP BY
            1,
            2,
            3
    ) latest ON latest.country_code = w.country_code
    AND latest.election_type = w.election_type
    AND latest.nuts_level = w.nuts_level
    AND latest.latest_year = w.election_year;

COPY eu_ned_party_results TO 'data/elections/eu_ned/eu_ned_party_results.parquet' (FORMAT PARQUET);

COPY eu_ned_winners TO 'data/elections/eu_ned/eu_ned_winners.parquet' (FORMAT PARQUET);

COPY eu_ned_latest_winners TO 'data/elections/eu_ned/eu_ned_latest_winners.parquet' (FORMAT PARQUET);

COPY (
    SELECT
        country_code,
        country,
        election_type,
        nuts_level,
        MIN(election_year) AS min_year,
        MAX(election_year) AS max_year,
        COUNT(*) AS party_rows,
        COUNT(DISTINCT nuts_code) AS nuts_regions,
        COUNT(DISTINCT partyfacts_id) AS partyfacts_ids
    FROM
        eu_ned_party_results
    GROUP BY
        1,
        2,
        3,
        4
    ORDER BY
        country_code,
        election_type,
        nuts_level
) TO 'data/elections/eu_ned/eu_ned_coverage.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT
        country_code,
        country,
        election_type,
        election_year,
        nuts_level,
        nuts_code,
        region_name,
        party_abbreviation AS winner_party,
        party_english AS winner_party_english,
        partyfacts_id AS winner_partyfacts_id,
        party_vote_share_pct AS winner_vote_share_pct,
        turnout_pct,
        valid_vote,
        total_vote,
        electorate
    FROM
        eu_ned_latest_winners
    ORDER BY
        country_code,
        election_type,
        nuts_level,
        nuts_code
) TO 'data/elections/eu_ned/eu_ned_latest_winners.csv' (HEADER, DELIMITER ',');

SELECT
    country_code,
    election_type,
    nuts_level,
    MIN(election_year) AS min_year,
    MAX(election_year) AS max_year,
    COUNT(*) AS party_rows,
    COUNT(DISTINCT nuts_code) AS nuts_regions
FROM
    eu_ned_party_results
GROUP BY
    1,
    2,
    3
ORDER BY
    country_code,
    election_type,
    nuts_level;