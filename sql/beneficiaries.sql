COPY (
	SELECT
		*
	FROM
		read_csv(
			'data/beneficiaries/latest_*.csv',
			delim = ',',
			quote = '"',
			escape = '"',
			filename = true,
			header = true,
			columns = { 'Beneficiary': 'VARCHAR',
			'BeneficiaryLabel': 'VARCHAR',
			'Website': 'VARCHAR',
			'WikidataID': 'VARCHAR' }
		)
) TO 'data\Kohesio_latest_beneficiaries.parquet' (FORMAT PARQUET);