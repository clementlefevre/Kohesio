import duckdb
con = duckdb.connect()
res = con.execute(
    "SELECT country_code, count(*) AS total, count(ep_group_acronym) AS with_acronym "
    "FROM parquet_scan('data/analysis/master_nuts3.parquet') "
    "GROUP BY 1 ORDER BY with_acronym * 1.0 / count(*) ASC"
).fetchall()
for r in res:
    pct = round(100 * r[2] / r[1]) if r[1] else 0
    print(f"  {r[0]}: {r[2]}/{r[1]}  ({pct}%)")
