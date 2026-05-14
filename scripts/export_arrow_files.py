"""
Export dashboard data as Apache Arrow IPC files.
Uses DuckDB Python API for querying and pyarrow for writing.
"""

from pathlib import Path
import duckdb
import pyarrow as pa
import pyarrow.ipc as ipc

ANALYSIS_OUT = Path("data/analysis")
DASHBOARD_OUT = Path("frontend/public/data")
for output_dir in (ANALYSIS_OUT, DASHBOARD_OUT):
    output_dir.mkdir(parents=True, exist_ok=True)

con = duckdb.connect()


def write_arrow(result, path: Path) -> None:
    table = result if isinstance(result, pa.Table) else result.read_all()
    with ipc.new_file(path, table.schema) as writer:
        writer.write_table(table)
    print(f"  Wrote {path} ({path.stat().st_size // 1024} KB, {len(table)} rows)")


def write_dashboard_arrow(result, filename: str) -> None:
    table = result if isinstance(result, pa.Table) else result.read_all()
    for output_dir in (ANALYSIS_OUT, DASHBOARD_OUT):
        write_arrow(table, output_dir / filename)


# ── 1. Election + GDP + population master table ───────────────────────────────
print("Exporting election_nuts3.arrow ...")
election = con.execute("""
    SELECT
        country_code,
        nuts_code,
        region_name,
        -- NED (older elections, relevant for 2014-2020 period)
        eu_ned_election_year          AS ned_election_year,
        eu_ned_winner_party           AS ned_winner,
        eu_ned_winner_party_en        AS ned_winner_en,
        eu_ned_winner_share_pct       AS ned_winner_share_pct,
        eu_ned_turnout_pct            AS ned_turnout_pct,
        ned_ep_group_acronym          AS ned_ep_group,
        -- LGC / HU (more recent elections, relevant for 2021-2027 period)
        lgc_election_year,
        lgc_winner,
        lgc_winner_share_pct,
        lgc_turnout_pct,
        lgc_ep_group_acronym          AS lgc_ep_group,
        -- Socioeconomic
        population,
        gdp_per_capita_eur
    FROM read_parquet('data/analysis/master_nuts3.parquet')
    WHERE nuts_code IS NOT NULL
    ORDER BY country_code, nuts_code
""").arrow()
write_dashboard_arrow(election, "election_nuts3.arrow")


# ── 2. Kohesio projects per NUTS3 + programming period (all countries) ────────
print("Exporting kohesio_nuts3.arrow ...")

# Discover all downloaded project CSVs
projects_dir = Path("data/kohesio_current/projects")
pp14_files = sorted(projects_dir.glob("*-pp14-20-*.csv"))
pp21_files = sorted(projects_dir.glob("*-pp21-27-*.csv"))

print(f"  Found {len(pp14_files)} files for 2014-2020, {len(pp21_files)} for 2021-2027")

def build_union(files, period_label, has_nuts3_label: bool):
    """Build a SQL UNION ALL across a list of CSV files."""
    if not files:
        return ""
    nuts3_label_expr = "NUTS3_Label" if has_nuts3_label else "NULL::VARCHAR"
    parts = []
    for f in files:
        cc = f.name[:2]
        parts.append(f"""
        SELECT
            Operation_Unique_Identifier,
            NUTS3_Code,
            {nuts3_label_expr} AS NUTS3_Label,
            '{period_label}' AS Programming_Period,
            '{cc}' AS country_code,
            Total_Eligible_Expenditure_amount,
            Project_EU_Budget,
            Cofinancing_Rate
        FROM read_csv_auto('{f.as_posix()}', ignore_errors=true)
        WHERE NUTS3_Code IS NOT NULL AND NUTS3_Code != ''
        """)
    return "UNION ALL".join(parts)

union_14_20 = build_union(pp14_files, "2014-2020", has_nuts3_label=False)
union_21_27 = build_union(pp21_files, "2021-2027", has_nuts3_label=True)

all_unions = []
if union_14_20:
    all_unions.append(union_14_20)
if union_21_27:
    all_unions.append(union_21_27)

full_union = "UNION ALL".join(all_unions)

kohesio = con.execute(f"""
    WITH all_projects AS (
        {full_union}
    ),
    deduped AS (
        SELECT
            Operation_Unique_Identifier,
            NUTS3_Code, NUTS3_Label, Programming_Period, country_code,
            Total_Eligible_Expenditure_amount, Project_EU_Budget, Cofinancing_Rate
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY Operation_Unique_Identifier) AS rn
            FROM all_projects
        ) t
        WHERE rn = 1
    )
    SELECT
        NUTS3_Code                                           AS nuts_code,
        country_code,
        Programming_Period                                   AS programming_period,
        ANY_VALUE(NUTS3_Label)                               AS nuts3_label,
        COUNT(DISTINCT Operation_Unique_Identifier)          AS project_count,
        ROUND(SUM(Total_Eligible_Expenditure_amount), 0)     AS total_expenditure_eur,
        ROUND(SUM(Project_EU_Budget), 0)                     AS total_eu_budget_eur,
        ROUND(AVG(Cofinancing_Rate), 1)                      AS avg_cofinancing_pct
    FROM deduped
    GROUP BY 1, 2, 3
    ORDER BY country_code, nuts_code, programming_period
""").arrow()
write_dashboard_arrow(kohesio, "kohesio_nuts3.arrow")

# Summary
# Summary from the in-memory kohesio table
con.register("kohesio_tbl", kohesio)
summary = con.execute("""
    SELECT country_code, programming_period,
           COUNT(DISTINCT nuts_code) AS nuts3_regions,
           ROUND(SUM(total_expenditure_eur)/1e9, 1) AS total_expenditure_bn_eur
    FROM kohesio_tbl
    GROUP BY 1, 2
    ORDER BY 1, 2
""").fetchall()
print("\n  Coverage summary:")
for row in summary:
    print(f"    {row[0]} {row[1]}: {row[2]} NUTS3, \u20ac{row[3]}B")

print("Done.")

