COPY (
	SELECT
		*
	FROM
		read_csv(
			'data/nuts/latest_*.csv',
			delim = ',',
			quote = '"',
			escape = '"',
			filename = true,
			header = true,
			columns = { 'nuts3': 'VARCHAR',
			'nuts3Label': 'VARCHAR',
			'nuts3code': 'VARCHAR',
			'nuts2': 'VARCHAR',
			'nuts2Label': 'VARCHAR',
			'nuts2code': 'VARCHAR',
			'nuts1': 'VARCHAR',
			'nuts1Label': 'VARCHAR',
			'nuts1code': 'VARCHAR' }
		)
) TO 'data/Kohesio_latest_nuts.parquet' (FORMAT PARQUET);