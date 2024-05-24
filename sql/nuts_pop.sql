COPY ( WITH POP_RAW AS 
(
SELECT
	*
FROM
	read_csv("data\population\estat_demo_r_pjanaggr3.tsv",
	delim = '\t',
	header = true)
WHERE
	"freq,unit,sex,age,geo\TIME_PERIOD" LIKE '%T,TOTAL%'
	)
--SELECT * FROM POP_RAW WHERE "freq,unit,sex,age,geo\TIME_PERIOD" LIKE '%ES113%'
	
	,

POP_NUTS AS (
SELECT
	*, 
	split_part("freq,unit,sex,age,geo\TIME_PERIOD",
	',',
	-1) AS NUTS,
	"2023",
	regexp_extract("2023",
	'\d+',
	0) AS POP_2023,
	regexp_extract("2022",
	'\d+',
	0) AS POP_2022,
	regexp_extract("2021",
	'\d+',
	0) AS POP_2021,
	regexp_extract("2020",
	'\d+',
	0) AS POP_2020,
	regexp_extract("2019",
	'\d+',
	0) AS POP_2019
FROM
	POP_RAW)
	
	,
	
	
	
	
	POP_NUTS_CLEAN AS (
SELECT
	NUTS,
	 CASE
		WHEN POP_2023 IS NOT NULL THEN POP_2023
		WHEN POP_2023 IS NULL
			AND POP_2022 IS NOT NULL THEN POP_2022
			ELSE POP_2021
		END AS POP_NUTS
	FROM
		POP_NUTS)
		
		
		
SELECT
	*
FROM
	POP_NUTS_CLEAN)


TO 'data\Kohesio_POP_NUTS.parquet' (FORMAT PARQUET);