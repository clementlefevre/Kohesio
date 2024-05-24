
/*FROM
	sniff_csv('data\latest_SK.csv'); */

COPY 
(
SELECT
	*
FROM
	read_csv('data\projects\latest_*.csv',
	 delim = ',', 
	 quote = '"',
	escape = '"',
	 filename = true,
	header = true,
	columns = {'Operation_Unique_Identifier': 'VARCHAR',
	'Operation_Local_Identifier': 'VARCHAR',
	'Operation_Name_English': 'VARCHAR',
	'Operation_Name_Programme_Language': 'VARCHAR',
	'Country': 'VARCHAR',
	'Postal_Code': 'VARCHAR',
	'Operation_Start_Date': 'DATE',
	'Operation_End_Date': 'DATE',
	'Cofinancing_Rate': 'DOUBLE',
	'Total_Eligible_Expenditure_amount': 'DOUBLE',
	'Total_Eligible_Expenditure_Currency': 'VARCHAR',
	'Project_EU_Budget': 'DOUBLE',
	'Beneficiary_Unique_Identifier': 'VARCHAR',
	'Location_Indicator_latitude_longitude': 'VARCHAR',
	'Category_Of_Intervention': 'VARCHAR',
	'Category_Label': 'VARCHAR',
	'Thematic_Objective_ID': 'VARCHAR',
	'Thematic_Objective_Label': 'VARCHAR',
	'Policy_Objective_ID': 'VARCHAR',
	'Policy_Objective_Label': 'VARCHAR',
	'Fund_Code': 'VARCHAR',
	'Fund_Name': 'VARCHAR',
	'Programme_Code': 'VARCHAR',
	'Programme_Name': 'VARCHAR',
	'Region': 'VARCHAR',
	'NUTS3_Code': 'VARCHAR',
	'Programming_Period': 'VARCHAR',
	'Operation_Summary_English': 'VARCHAR',
	'Operation_Summary_Programme_Language': 'VARCHAR',
	'ManagingAuthority': 'VARCHAR',
	'Image_URL': 'VARCHAR',
	'InfoRegio_ID': 'DOUBLE',
	'InfoRegio_URL': 'VARCHAR' })
	

) TO 'data\Kohesio_latest_projects.parquet' (FORMAT PARQUET);