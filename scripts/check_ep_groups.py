import duckdb

con = duckdb.connect()

# Coverage by country
print("=== EP group coverage by country ===")
rows = con.execute(
    "SELECT country_code, count(*) AS total, count(ep_group_acronym) AS with_grp "
    "FROM parquet_scan('data/analysis/master_nuts3.parquet') "
    "GROUP BY 1 ORDER BY with_grp * 1.0 / count(*) ASC"
).fetchall()
for r in rows:
    print(f"  {r[0]}: {r[2]}/{r[1]}")

# Sample of null cases with latest_winner
print("\n=== Rows with null ep_group (excl. TR/NO/CH) ===")
rows2 = con.execute(
    "SELECT country_code, latest_winner, latest_election_year, eu_ned_winner_party, count(*) AS n "
    "FROM parquet_scan('data/analysis/master_nuts3.parquet') "
    "WHERE ep_group_acronym IS NULL AND country_code NOT IN ('TR','NO','CH','LT','EE') "
    "GROUP BY 1,2,3,4 ORDER BY n DESC LIMIT 40"
).fetchall()
for r in rows2:
    print(f"  {r[0]}: winner={r[1]!r} (eu_ned={r[3]!r}) year={r[2]} n={r[4]}")

# Check if party_group_mapping.csv exists
print("\n=== party_group_mapping.csv sample ===")
try:
    rows3 = con.execute(
        "SELECT country_id, party_acronym, term, ep_group_acronym "
        "FROM read_csv_auto('data/elections/raw/european_parliament_results/party_group_mapping.csv') "
        "LIMIT 10"
    ).fetchall()
    for r in rows3:
        print(f"  {r}")
except Exception as e:
    print(f"  ERROR: {e}")
