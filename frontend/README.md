# Kohesio Dashboard

Svelte/Vite dashboard for exploring the joined election, NUTS3, and Kohesio project aggregates.

## Run

```bash
npm install
npm run dev
```

## Runtime data

The dashboard only needs these local runtime files:

- `public/data/election_nuts3.arrow`
- `public/data/kohesio_nuts3.arrow`

The map layer is fetched at runtime from Eurostat GISCO:

- `https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson/NUTS_RG_20M_2021_4326_LEVL_3.geojson`

OpenStreetMap tiles are also fetched remotely by Leaflet.

## Regenerating dashboard data

From the repository root, run:

```bash
python scripts/export_arrow_files.py
```

The script reads `data/analysis/master_nuts3.parquet` and `data/kohesio_current/projects/*.csv`, then writes Arrow files to both `data/analysis/` and `frontend/public/data/`.

To rebuild `data/analysis/master_nuts3.parquet`, run the upstream SQL pipeline in `sql/build_master_nuts3_table.sql`. That pipeline depends on the raw and normalized source data under `data/`, which are large local inputs and are intentionally ignored by Git.
