COPY (
	WITH GDP_RAW AS (
		SELECT
			*
		FROM
			read_csv(
				"data/population/estat_nama_10r_3gdp.tsv",
				sep = '\t',
				header = true
			)
		WHERE
			"freq,unit,geo\TIME_PERIOD" LIKE '%EUR_HAB,%'
	),
	GDP_NUTS AS (
		SELECT
			*,
			split_part("freq,unit,geo\TIME_PERIOD", ',', -1) AS NUTS,
			regexp_extract("2021", '\d+', 0) AS GDP_2021,
			regexp_extract("2020", '\d+', 0) AS GDP_2020,
			regexp_extract("2019", '\d+', 0) AS GDP_2019
		FROM
			GDP_RAW
	),
	GDP_NUTS_CLEAN AS (
		SELECT
			NUTS,
			CASE
				WHEN GDP_2021 IS NOT NULL THEN GDP_2021
				WHEN GDP_2021 IS NULL
				AND GDP_2020 IS NOT NULL THEN GDP_2020
				ELSE GDP_2019
			END AS GDP_NUTS
		FROM
			GDP_NUTS
	)
	SELECT
		*
	FROM
		GDP_NUTS_CLEAN
) TO 'data/Kohesio_GDP_NUTS.parquet' (FORMAT PARQUET);