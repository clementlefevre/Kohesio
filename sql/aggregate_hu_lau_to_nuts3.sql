-- Aggregate LGC Hungary 2022 legislative commune-level data to NUTS3
-- using the Eurostat LAU-NUTS 2022 correspondence table.
-- EM / FIDESZ-KDNP / MNOÖ columns are fractions of Registered,
-- so absolute votes = share * Registered; we then divide by Turnout.
COPY (
    WITH base AS (
        SELECT
            l.nuts3_code,
            TRY_CAST(replace(e.Registered, ',', '.') AS DOUBLE) AS reg,
            TRY_CAST(replace(e.Turnout,    ',', '.') AS DOUBLE) AS trnout,
            TRY_CAST(replace(e.EM,         ',', '.') AS DOUBLE)
                * TRY_CAST(replace(e.Registered, ',', '.') AS DOUBLE) AS votes_em,
            TRY_CAST(replace(e."FIDESZ-KDNP", ',', '.') AS DOUBLE)
                * TRY_CAST(replace(e.Registered, ',', '.') AS DOUBLE) AS votes_fidesz,
            TRY_CAST(replace(e."MNOÖ",    ',', '.') AS DOUBLE)
                * TRY_CAST(replace(e.Registered, ',', '.') AS DOUBLE) AS votes_mnoö
        FROM read_csv('data/elections/raw/legrandcontinent/hongrie/Lux34.data.csv',
                      header=true, all_varchar=true) e
        JOIN read_csv_auto('data/population/HU_LAU_NUTS3_2022.csv') l
            ON l.gisco_id = e.GISCO_ID
    )
    SELECT
        nuts3_code,
        count(*)                                               AS communes,
        sum(reg)                                               AS registered,
        sum(trnout)                                            AS turnout,
        sum(trnout)*100.0 / nullif(sum(reg), 0)               AS turnout_pct,
        sum(votes_em)                                          AS votes_em,
        sum(votes_fidesz)                                      AS votes_fidesz,
        sum(votes_mnoö)                                        AS votes_mnoö,
        sum(votes_em)    *100.0 / nullif(sum(trnout), 0)      AS em_pct,
        sum(votes_fidesz)*100.0 / nullif(sum(trnout), 0)      AS fidesz_pct,
        sum(votes_mnoö)  *100.0 / nullif(sum(trnout), 0)      AS mnoö_pct,
        CASE
            WHEN sum(votes_fidesz)>=sum(votes_em) AND sum(votes_fidesz)>=sum(votes_mnoö) THEN 'FIDESZ-KDNP'
            WHEN sum(votes_em)>=sum(votes_fidesz)                                         THEN 'EM'
            ELSE 'MNOÖ'
        END                                                    AS winner
    FROM base GROUP BY 1 ORDER BY 1
) TO 'data/elections/normalized/HU_nuts3_2022_legislative.csv' (HEADER, DELIMITER ',');

SELECT nuts3_code, communes, round(registered,0) AS registered,
       round(turnout_pct,1) AS turnout_pct,
       round(fidesz_pct,1)  AS fidesz_pct,
       round(em_pct,1)      AS em_pct,
       round(mnoö_pct,2)    AS mnoö_pct,
       winner
FROM read_csv_auto('data/elections/normalized/HU_nuts3_2022_legislative.csv')
ORDER BY nuts3_code;