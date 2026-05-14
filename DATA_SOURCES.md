# Data Sources & Coverage

This document describes every dataset available in this repository, its coverage,
local paths, key columns, and how to join it with other sources.

---

## 1. EU-NED — European NUTS-level Election Dataset

**Source:** Harvard Dataverse — DOI [10.7910/DVN/IQRYP5](https://doi.org/10.7910/DVN/IQRYP5)  
**Local path:** `data/elections/eu_ned/`  
**NUTS version:** NUTS 2016  
**Years covered:** 1979–2020 (varies by country)  
**Prepared by:** `sql/prepare_eu_ned_elections.sql`

### Raw files

| File | Rows | Description |
|---|---|---|
| `eu_ned_joint.tab` | ~120k | All elections (Parliament + EP) combined |
| `eu_ned_national.tab` | ~60k | National parliamentary elections only |
| `eu_ned_ep.tab` | ~60k | European Parliament elections only |
| `eu_ned_joint_codebook.pdf` | — | Variable definitions |

### Derived outputs

| File | Description |
|---|---|
| `eu_ned_party_results.parquet` | Party-level rows with `party_vote_share_pct`, `turnout_pct` |
| `eu_ned_winners.parquet` | Winner (top party) per country/type/year/NUTS region |
| `eu_ned_latest_winners.parquet` | Latest available winner per country/type/NUTS level |
| `eu_ned_latest_winners.csv` | Same, CSV format for quick inspection |
| `eu_ned_coverage.csv` | Coverage summary by country/type/NUTS level |

### Schema (joint file)

```
country, country_code, nuts_level (int), nuts_code (NUTS 2016), region_name,
election_type (Parliament/EP), election_year, party_abbreviation, party_english,
party_native, partyfacts_id, party_vote, electorate, total_vote, valid_vote
```

Derived: `party_vote_share_pct = party_vote / valid_vote × 100`, `turnout_pct = total_vote / electorate × 100`

### Country / NUTS-level coverage (election-results phase)

| Country | Type | NUTS level | Years | Regions |
|---|---|---|---|---|
| AT | Parliament | 3 | 1990–2019 | 36 |
| AT | EP | 3 | 1996–2019 | 35 |
| BE | Parliament | 2 | 1991–2019 | 11 |
| BE | EP | 2 | 1994–2019 | 12 |
| BG | Parliament | 3 | 2005–2017 | 29 |
| BG | EP | 3 | 2007–2019 | 29 |
| CH | Parliament | 3 | 1991–2019 | 26 |
| CZ | Parliament | 3 | 2002–2017 | 14 |
| CZ | EP | 3 | 2004–2019 | 14 |
| DE | Parliament | 3 | 1990–2017 | 401 |
| DE | EP | 3 | 1994–2019 | 401 |
| DK | Parliament | 3 | 1990–2019 | 11 |
| DK | EP | 3 | 1994–2019 | 11 |
| EE | Parliament | 3 | 2003–2019 | 5 |
| ES | Parliament | 3 | 1993–2019 | 49 |
| ES | EP | 3 | 1994–2019 | 51 |
| FI | Parliament | 3 | 1983–2019 | 19 |
| FR | Parliament | 3 | 1993–2017 | 101 |
| FR | EP | 3 | 1994–2019 | 102 |
| GR | Parliament | 3 | 1990–2019 | 45 |
| GR | EP | 3 | 1994–2019 | 46 |
| HR | Parliament | 3 | 2011–2020 | 22 |
| HU | Parliament | 3 | 1990–**2018** | 20 |
| HU | EP | 3 | 2004–**2019** | 21 |
| IT | Parliament | 3 | 1992–2018 | 110 |
| IT | EP | 3 | 1989–2019 | 110 |
| LT | Parliament | 3 | 2000–2020 | 11 |
| LV | Parliament | 3 | 2002–2018 | 7 |
| NL | EP | 3 | 1994–2019 | 40 |
| PL | EP | 3 | 2004–2019 | 73 |
| PT | Parliament | 3 | 1991–2019 | 25 |
| RO | Parliament | 3 | 2004–2016 | 42 |
| RO | EP | 3 | 2007–2019 | 42 |
| SE | Parliament | 3 | 1991–2018 | 21 |
| SK | Parliament | 3 | 2006–2020 | 8 |
| SI | Parliament | 1 | 2004–2018 | 1 |

> **Note:** EU-NED cuts off around 2018–2020. For more recent elections use LGC or HU 2022 derived data.

### Join keys

```sql
-- To EU-NED party results:
eu_ned.nuts_code  ↔  Eurostat NUTS 2016 code  (e.g. CZ010)
eu_ned.country_code  ↔  ISO 3166-1 alpha-2     (e.g. CZ)

-- To EP party-group mapping (approximate, needs fuzzy match):
eu_ned.party_abbreviation  ≈  party_group_mapping.party_acronym
  WHERE party_group_mapping.country_id = eu_ned.country_code
  AND   party_group_mapping.term covers eu_ned.election_year
```

---

## 2. Le Grand Continent (LGC) — Recent Elections at NUTS Level

**Source:** Datawrapper charts embedded in [legrandcontinent.eu/fr/elections/](https://legrandcontinent.eu/fr/elections/)  
**Scraped by:** `_02_scrape_lgc_election_raw.py`  
**Raw path:** `data/elections/raw/legrandcontinent/{country_slug}/`  
**Normalized path:** `data/elections/normalized/lgc_nuts_elections.csv`  
**Normalized by:** `sql/normalize_lgc_nuts_elections.sql`

### Normalized coverage (`lgc_nuts_elections.csv`)

| Country | Election year | NUTS level | Regions | Turnout | Winner | Notes |
|---|---|---|---|---|---|---|
| BE | 2019 | NUTS2 | 11 | ✓ | — | Turnout only |
| BG | 2024 | NUTS3 | 28 | — | ✓ | Winner + share only |
| CZ | 2021 | NUTS3 | 14 | ✓ | ✓ | Full |
| DE | 2021 | NUTS3 | 400 | ✓ | ✓ | Full |
| ES | 2023 | NUTS3 | 59 | ✓ | ✓ | Full |
| IT | 2022 | NUTS3 | 106 | ✓ | ✓ | Full |

### Schema (`lgc_nuts_elections.csv`)

```
country_code, slug, chart_id, election_family, election_year,
nuts_level, nuts_code, region_name, registered, turnout, turnout_pct,
winner, winner_share_pct, winner_color, source_metric, source_path
```

### Raw LGC files — other countries (not yet normalized)

Countries scraped but not yet added to the normalized view:

| Country slug | Charts | Notable content |
|---|---|---|
| `hongrie` | `Lux34`, `y31Hs` | 3,155 communes (LAU level), 2022 legislative — **use HU aggregated file instead** |
| `autriche`, `france`, `pologne`, … | varies | Check `data/elections/raw/legrandcontinent/files_index.csv` |

### Join keys

```sql
-- To Eurostat GDP / population:
lgc_nuts_elections.nuts_code  ↔  Eurostat NUTS code  (NUTS 2021 version used by LGC)

-- To EU-NED (same country, overlapping years):
lgc_nuts_elections.nuts_code ≈ eu_ned.nuts_code
-- Note: LGC uses NUTS 2021; EU-NED uses NUTS 2016.
-- Use Eurostat NUTS correspondence table for version mismatches.
```

---

## 3. HU 2022 Legislative — LAU→NUTS3 Aggregated

**Source:** LGC `Lux34.data.csv` (commune level) joined with Eurostat LAU-NUTS 2022 table  
**Produced by:** `sql/aggregate_hu_lau_to_nuts3.sql`  
**Local path:** `data/elections/normalized/HU_nuts3_2022_legislative.csv`

### Coverage

| Regions | Communes aggregated | Election year | Parties |
|---|---|---|---|
| 20 NUTS3 | 3,155 LAU | 2022 | FIDESZ-KDNP, EM (opposition coalition), MNOÖ |

### Schema

```
nuts3_code, communes, registered, turnout, turnout_pct,
votes_em, votes_fidesz, votes_mnoö,
em_pct, fidesz_pct, mnoö_pct, winner
```

> **Vote share logic:** LGC stores votes as fraction of registered voters (0–1).
> Absolute votes = `share × registered`. NUTS3 share = `sum(absolute votes) / sum(turnout)`.

### Correspondence table used

`data/population/HU_LAU_NUTS3_2022.csv` — extracted from  
`EU-27-LAU-2022-NUTS-2021.xlsx` (Eurostat, sheet `HU`).  
Join key: `EU LAU CODE` = `GISCO_ID` (format `HU_NNNNN`), 6,258 communes, 0 unmatched.

---

## 4. European Parliament Results JSON — EP Official

**Source:** [results.elections.europa.eu/en/tools/download-datasheets/](https://results.elections.europa.eu/en/tools/download-datasheets/)  
**Downloaded by:** `scripts/download_ep_results_json.ps1`  
**Local path:** `data/elections/raw/european_parliament_results/json/`  
**Manifest:** `data/elections/raw/european_parliament_results/json_manifest.csv`  
**531 JSON files, 3.7 MB total, 0 parse errors**

### Structure

```
json/
  labels.json                    # EU-wide label translations
  turnout.json                   # EU-wide turnout by election year
  {term}/                        # e.g. 2024-2029/
    election-results/
      parties.json               # All parties per country (candidateId, acronym, long name)
      groups.json                # EP group definitions with multilingual names
      eu.json                    # EU-level summary
      {country_code}.json        # Per-country: seats by party + groupDistribution
      gender-balance.json
    outgoing-parliament/
      (same structure for the previous parliament composition)
```

### Terms covered

`1979-1984`, `1984-1989`, `1989-1994`, `1994-1999`, `1999-2004`,
`2004-2009`, `2009-2014`, `2014-2019`, `2019-2024`, `2024-2029`

### Party → EP group mapping

**Extracted to:** `data/elections/raw/european_parliament_results/party_group_mapping.csv`  
**EP group reference:** `data/elections/raw/european_parliament_results/ep_groups.csv`  
**Extracted by:** `scripts/extract_ep_party_group_mapping.py`

#### `party_group_mapping.csv` schema

```
term, phase, country_id, party_id, party_acronym, party_long_name,
candidate_type, coalition_id, coalition_acronym,
ep_group_id, ep_group_acronym, seats_total, votes_percent
```

#### Coverage (election-results phase)

| Term | Countries | Party entries | With EP group |
|---|---|---|---|
| 1979–1984 | 13 | 82 | 69 |
| 1984–1989 | 14 | 91 | 77 |
| … | … | … | … |
| 2019–2024 | 33 | 367 | 201 |
| 2024–2029 | 30 | 387 | 268 |

Parties with no seats typically have `ep_group_id = NULL`.

#### Known EP groups (2024–2029)

`EPP`, `S&D`, `Renew Europe` (ALDE), `Greens/EFA`, `ECR`, `PfE` (Patriots for Europe, incl. Fidesz),
`ESN` (Europe of Sovereign Nations), `The Left`, `NI` (Non-Inscrits)

#### Join to EU-NED

```sql
-- Approximate: match by party acronym + country + election year within term
SELECT n.*, g.ep_group_acronym
FROM eu_ned_party_results n
LEFT JOIN party_group_mapping g
  ON g.country_id = n.country_code
 AND g.party_acronym = n.party_abbreviation   -- may need fuzzy match
 AND g.phase = 'election-results'
 AND CAST(left(g.term, 4) AS INT) <= n.election_year
 AND CAST(right(g.term, 4) AS INT) >= n.election_year;
```

---

## 5. Eurostat — Population (NUTS3)

**Source:** Eurostat `demo_r_pjanaggr3`  
**Local path:** `data/population/estat_demo_r_pjanaggr3.tsv`  
**Rows:** 31,230 (all NUTS levels, sexes, age groups)  
**NUTS version:** matches file vintage (NUTS 2021)

### Key filter for analysis

```sql
WHERE "freq,unit,sex,age,geo\TIME_PERIOD" LIKE '%T,TOTAL%'
-- column split: split_part(..., ',', -1) = nuts_code
-- use latest available year: 2023 → 2022 → 2021
```

### Join key

`nuts_code` (NUTS 2021) ↔ any other dataset's `nuts_code` / `NUTS3` column.

---

## 6. Eurostat — GDP per Capita (NUTS3)

**Source:** Eurostat `nama_10r_3gdp`  
**Local path:** `data/population/estat_nama_10r_3gdp.tsv`  
**Rows:** 12,453  
**Unit used:** `EUR_HAB` (EUR per inhabitant, current prices)

### Key filter

```sql
WHERE "freq,unit,geo\TIME_PERIOD" LIKE '%EUR_HAB,%'
-- use latest: 2021 → 2020 → 2019
```

### Join key

`nuts_code` ↔ any other dataset's NUTS3 column.

---

## 7. Kohesio — EU Cohesion Fund Projects (Czech Republic only)

**Source:** [kohesio.ec.europa.eu](https://kohesio.ec.europa.eu) — snapshot 2026-03-17  
**Local path:** `data/kohesio_current/`  
**Analysis script:** `sql/czech_nuts3_election_kohesio_analysis.sql`

### Files

| File | Rows | Description |
|---|---|---|
| `CZ_projects_2014_2020.csv` | ~85k | 2014–2020 programming period |
| `CZ_projects_2021_2027.csv` | ~15k | 2021–2027 programming period |
| `CZ_beneficiaries.csv` | — | Beneficiary details |
| `CZ_nuts.csv` | — | NUTS lookup for CZ |
| `nuts/` | one CSV per country | NUTS3 lookup tables (`nuts3code`, `nuts3Label`) |

### Coverage (both periods combined)

| Metric | Value |
|---|---|
| Projects | 100,648 |
| NUTS3 regions | 315 (all countries in CZ files) |
| Eligible expenditure | €52.28 bn |
| EU budget | €37.84 bn |
| Date range | 2003-03-01 – 2025-07-01 |

### Key columns

```
Operation_Unique_Identifier, Beneficiary_Unique_Identifier,
NUTS3_Code, NUTS3_Label, country_code,
Total_Eligible_Expenditure_amount, Project_EU_Budget,
Operation_Start_Date, Operation_End_Date, Cofinancing_Rate,
Fund (ERDF / CF / ESF / …), Policy_Objective
```

### Join key

`NUTS3_Code` (NUTS 2021) ↔ other datasets' NUTS3 column.

---

## 8. Eurostat — LAU to NUTS3 Correspondence (Hungary)

**Source:** Eurostat LAU 2022 — NUTS 2021  
**Downloaded from:** `ec.europa.eu/eurostat/documents/345175/501971/EU-27-LAU-2022-NUTS-2021.xlsx`  
**Local paths:**
- `data/population/EU-27-LAU-2022-NUTS-2021.xlsx` (full EU file, 15 MB)
- `data/population/HU_LAU_NUTS3_2022.csv` (HU sheet extracted)

### Schema (`HU_LAU_NUTS3_2022.csv`)

```
nuts3_code, lau_code, gisco_id, lau_name_national, lau_name_latin, population
```

`gisco_id` = `HU_{lau_code}` — matches LGC Hungary's `GISCO_ID` column exactly.

> The same Excel file contains all EU-27 countries. To extend to another country:
> load the relevant sheet, extract columns 0 (NUTS3), 1 (LAU CODE), 2 (EU LAU CODE).

---

## Cross-Dataset Join Map

```
┌─────────────────────┐      nuts_code (NUTS 2016)     ┌──────────────────────┐
│   EU-NED            │ ──────────────────────────────► │  Eurostat GDP        │
│  (party results)    │                                  │  (estat_nama_10r_3…) │
└──────┬──────────────┘                                  └──────────────────────┘
       │ nuts_code (NUTS 2016)                                    ▲
       │  ⚠ NUTS version gap — use Eurostat                       │
       │  NUTS correspondence table for 2016→2021                 │
       ▼                                                          │ nuts_code (NUTS 2021)
┌─────────────────────┐      nuts_code (NUTS 2021)     ┌──────────────────────┐
│   LGC Normalized    │ ──────────────────────────────► │  Eurostat Population │
│  (lgc_nuts_elec…)   │                                  │  (estat_demo_r_…)    │
└──────┬──────────────┘                                  └──────────────────────┘
       │ nuts_code (NUTS 2021)                                    ▲
       │                                                          │ NUTS3_Code (NUTS 2021)
       ▼                                                          │
┌─────────────────────┐                                  ┌──────────────────────┐
│   HU 2022 NUTS3     │ ──────────────────────────────► │  Kohesio Projects    │
│  (HU_nuts3_2022_…)  │      nuts3_code (NUTS 2021)     │  (CZ only today)     │
└─────────────────────┘                                  └──────────────────────┘

┌─────────────────────┐  party_acronym + country + year  ┌──────────────────────┐
│   EU-NED            │ ──────────────────────────────► │  EP Party-Group Map  │
│  (party results)    │   (approximate / fuzzy join)     │  (party_group_…csv)  │
└─────────────────────┘                                  └──────────────────────┘
```

### NUTS version alignment

| Dataset | NUTS version | Action needed to join |
|---|---|---|
| EU-NED | 2016 | Convert with [Eurostat NUTS 2016→2021 correspondence](https://ec.europa.eu/eurostat/web/nuts/correspondence-tables) |
| LGC normalized | 2021 | No conversion needed for Eurostat 2021 files |
| HU 2022 NUTS3 | 2021 | No conversion needed |
| Kohesio | 2021 | No conversion needed |
| Eurostat GDP/pop | 2021 | No conversion needed |
| EP JSON / party-group | N/A (national level) | Join on country + year, not NUTS |

---

## File Tree Summary

```
data/
├── elections/
│   ├── eu_ned/                          # EU-NED raw + derived
│   │   ├── eu_ned_joint.tab             # Raw: all elections, party level
│   │   ├── eu_ned_party_results.parquet # Derived: vote shares
│   │   ├── eu_ned_winners.parquet       # Derived: winners per year
│   │   ├── eu_ned_latest_winners.parquet
│   │   ├── eu_ned_latest_winners.csv
│   │   └── eu_ned_coverage.csv
│   ├── normalized/
│   │   ├── lgc_nuts_elections.csv       # LGC: BE/BG/CZ/DE/ES/IT NUTS
│   │   ├── lgc_nuts_elections_coverage.csv
│   │   └── HU_nuts3_2022_legislative.csv  # HU 2022, aggregated from LAU
│   └── raw/
│       ├── legrandcontinent/            # Raw LGC CSV per country/chart
│       │   ├── files_index.csv
│       │   └── {country_slug}/
│       └── european_parliament_results/
│           ├── json/                    # 531 EP result JSON files
│           ├── json_manifest.csv
│           ├── party_group_mapping.csv  # Party → EP group (all terms)
│           └── ep_groups.csv
└── population/
    ├── estat_demo_r_pjanaggr3.tsv      # Eurostat NUTS3 population
    ├── estat_nama_10r_3gdp.tsv         # Eurostat NUTS3 GDP per capita
    ├── EU-27-LAU-2022-NUTS-2021.xlsx   # LAU → NUTS3 (all EU-27)
    └── HU_LAU_NUTS3_2022.csv           # HU LAU → NUTS3 extracted
```
