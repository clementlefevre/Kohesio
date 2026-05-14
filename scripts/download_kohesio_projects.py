"""
Download Kohesio project CSVs for all EU countries from the official snapshot URLs.
2014-2020: https://kohesio.ec.europa.eu/api/data/object?id=data/projects-2014-2020/2023-09-29/{CC}-pp14-20-20230929.csv
2021-2027: https://kohesio.ec.europa.eu/api/data/object?id=data/projects-2021-2027/2025-11-10/{CC}-pp21-27-20251110.csv
"""
import requests
from pathlib import Path

OUT = Path("data/kohesio_current/projects")
OUT.mkdir(parents=True, exist_ok=True)

PERIODS = {
    "2014-2020": {
        "snapshot": "2023-09-29",
        "suffix": "pp14-20-20230929",
    },
    "2021-2027": {
        "snapshot": "2025-11-10",
        "suffix": "pp21-27-20251110",
    },
}

# EU countries with cohesion policy (no UK, CH, NO, TR)
COUNTRIES = [
    "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "ES", "FI",
    "FR", "GR", "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT",
    "NL", "PL", "PT", "RO", "SE", "SI", "SK",
]

BASE = "https://kohesio.ec.europa.eu/api/data/object?id="

for period, cfg in PERIODS.items():
    snap = cfg["snapshot"]
    suffix = cfg["suffix"]
    print(f"\n=== {period} (snapshot {snap}) ===")
    for cc in COUNTRIES:
        fname = f"{cc}-{suffix}.csv"
        dest = OUT / fname
        if dest.exists() and dest.stat().st_size > 10_000:
            print(f"  {cc}: already exists ({dest.stat().st_size // 1024} KB)")
            continue
        url = f"{BASE}data/projects-{period}/{snap}/{fname}"
        try:
            r = requests.get(url, timeout=180, stream=True)
            if r.status_code == 200:
                content = r.content
                if len(content) > 10_000 and b"<!DOCTYPE" not in content[:200]:
                    dest.write_bytes(content)
                    print(f"  {cc}: {len(content) // 1024} KB")
                else:
                    print(f"  {cc}: not available (HTML or too small)")
            else:
                print(f"  {cc}: HTTP {r.status_code}")
        except Exception as e:
            print(f"  {cc}: error — {e}")

print("\nDone.")
