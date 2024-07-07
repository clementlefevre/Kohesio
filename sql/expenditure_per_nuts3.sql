COPY (
	WITH POP_NUTS AS (
		SELECT
			*
		FROM
			read_parquet("data/Kohesio_POP_NUTS.parquet")
	),
	GDP_NUTS AS (
		SELECT
			*
		FROM
			read_parquet("data/Kohesio_GDP_NUTS.parquet")
	),
	projects as (
		SELECT
			*
		FROM
			read_parquet("data/Kohesio_latest_projects.parquet")
	),
	nuts as (
		SELECT
			*
		FROM
			read_parquet("data/Kohesio_latest_nuts.parquet")
	),
	benef as (
		SELECT
			*
		FROM
			read_parquet("data/Kohesio_latest_beneficiaries.parquet") --WHERE Beneficiary= 'https://linkedopendata.eu/entity/Q3063331'
	),
	RAW AS (
		SELECT
			*
		FROM
			projects p
			left join nuts n on n.nuts3code = p.NUTS3_Code
			left join benef b on b.Beneficiary = p.Beneficiary_Unique_Identifier -- https://linkedopendata.eu/entity/Q6878151
	) --SELECT * FROM RAW WHERE nuts1code like 'DEE%'
,
	RAW_UNIQUES AS (
		SELECT
			*
		FROM
			(
				SELECT
					*,
					ROW_NUMBER() OVER (PARTITION BY Operation_Unique_Identifier) AS rn
				FROM
					RAW
			) AS ranked
		WHERE
			rn = 1
	),
	RAW_AGG AS (
		SELECT
			nuts3code,
			nuts3Label,
			ROUND(SUM(Total_Eligible_Expenditure_amount), 0) as Total_Eligible_Expenditure_amount,
			ROUND(SUM(Project_EU_Budget), 0) as Project_EU_Budget,
			COUNT(*) as count_projects,
			ROUND(
				SUM(Total_Eligible_Expenditure_amount) / COUNT(*),
				0
			) AS COSTS_PER_PROJECT
		FROM
			RAW_UNIQUES
		GROUP BY
			1,
			2
		ORDER BY
			Total_Eligible_Expenditure_amount DESC
	)
	SELECT
		RAW_AGG.*,
		pn.POP_NUTS :: INT as POP_NUTS,
		RAW_AGG.Total_Eligible_Expenditure_amount :: DOUBLE AS Total_Eligible_Expenditure_amount,
		RAW_AGG.Project_EU_Budget :: DOUBLE AS Project_EU_Budget,
		pn.POP_NUTS :: INT AS POP_NUTS,
		ROUND(
			RAW_AGG.Total_Eligible_Expenditure_amount :: DOUBLE / pn.POP_NUTS :: INT,
			0
		) as expenditure_per_ha,
		ROUND(
			RAW_AGG.Project_EU_Budget :: DOUBLE / pn.POP_NUTS :: INT,
			0
		) as EU_budget_per_ha,
		gn.GDP_NUTS as GDP_PER_HA
	FROM
		RAW_AGG
		LEFT JOIN POP_NUTS pn on pn.NUTS = RAW_AGG.nuts3code
		LEFT JOIN GDP_NUTS gn on gn.NUTS = RAW_AGG.nuts3code
	ORDER BY
		expenditure_per_ha DESC
) TO 'data\Kohesio_expenditure_per_nuts3.parquet' (FORMAT PARQUET);