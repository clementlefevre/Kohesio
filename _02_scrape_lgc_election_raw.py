import argparse
import copy
import csv
import json
import re
import time
import unicodedata
from pathlib import Path
from urllib.parse import urlparse

import requests
from lxml import html


BASE_URL = "https://legrandcontinent.eu/fr/elections/tchequie/"
COUNTRY_LINK_RE = re.compile(r"^https://legrandcontinent\.eu/fr/elections/[^/#?]+/?$")
DATAWRAPPER_RE = re.compile(r"https://datawrapper\.dwcdn\.net/([A-Za-z0-9]+)/embed\.js")
DATAWRAPPER_RENDER_RE = re.compile(
    r"window\.datawrapper\.render\((\{.*\})\);\s*$", re.DOTALL
)
DOWNLOAD_FILES = ("data.csv", "dataset.csv")
NUTS_COLUMN_RE = re.compile(r"^nuts(?:_|$|\d)", re.IGNORECASE)


def slug_from_url(url: str) -> str:
    path_parts = [part for part in urlparse(url).path.split("/") if part]
    return path_parts[-1]


def fetch_text(session: requests.Session, url: str, timeout: int) -> str:
    response = session.get(url, timeout=timeout)
    response.raise_for_status()
    return response.content.decode("utf-8")


def normalize_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    return "".join(
        character for character in normalized if not unicodedata.combining(character)
    ).lower()


def discover_country_pages(
    session: requests.Session, index_url: str, timeout: int
) -> list[dict[str, str]]:
    page_text = fetch_text(session, index_url, timeout)
    doc = html.fromstring(page_text)
    links: dict[str, dict[str, str]] = {}

    for anchor in doc.xpath("//a[@href]"):
        href = anchor.get("href")
        if not href:
            continue
        if href.startswith("/"):
            href = f"https://legrandcontinent.eu{href}"
        if not COUNTRY_LINK_RE.match(href):
            continue

        label = " ".join(anchor.text_content().split())
        slug = slug_from_url(href)
        if slug in {"elections", "europeennes-2024"}:
            continue
        if not label or len(label) > 3:
            label = slug.upper()

        if slug not in links or (
            len(label) <= 3 and len(links[slug]["country_code"]) > 3
        ):
            links[slug] = {"country_code": label, "slug": slug, "url": href}

    return sorted(links.values(), key=lambda item: item["slug"])


def discover_datawrapper_ids(page_text: str) -> list[str]:
    return sorted(set(DATAWRAPPER_RE.findall(page_text)))


def extract_chart_metadata(embed_text: str) -> dict[str, object]:
    match = DATAWRAPPER_RENDER_RE.search(embed_text)
    if not match:
        return {}
    payload = json.loads(match.group(1))
    chart = payload.get("chart", {})
    metadata = chart.get("metadata", {})
    describe = metadata.get("describe", {})
    visualize = metadata.get("visualize", {})
    axes = metadata.get("axes", {})
    assets = payload.get("assets", {})

    return {
        "chart_id": chart.get("id"),
        "chart_title": chart.get("title", ""),
        "chart_type": chart.get("type", ""),
        "source_name": describe.get("source-name", ""),
        "source_url": describe.get("source-url", ""),
        "intro": describe.get("intro", ""),
        "byline": describe.get("byline", ""),
        "notes": metadata.get("annotate", {}).get("notes", ""),
        "basemap": visualize.get("basemap", ""),
        "map_key_attr": visualize.get("map-key-attr", ""),
        "axes_keys": axes.get("keys", ""),
        "axes_values": axes.get("values", ""),
        "created_at": chart.get("createdAt", ""),
        "last_modified_at": chart.get("lastModifiedAt", ""),
        "public_url": chart.get("publicUrl", ""),
        "public_version": chart.get("publicVersion", ""),
        "assets": sorted(assets.keys()),
    }


def fetch_chart_metadata(
    session: requests.Session, chart_id: str, timeout: int
) -> dict[str, object]:
    embed_url = f"https://datawrapper.dwcdn.net/{chart_id}/1/embed.js"
    response = session.get(embed_url, timeout=timeout)
    response.raise_for_status()
    metadata = extract_chart_metadata(response.content.decode("utf-8"))
    metadata["embed_url"] = embed_url
    return metadata


def read_csv_profile(csv_path: Path) -> dict[str, object]:
    if not csv_path.exists():
        return {"columns": [], "row_count": 0, "has_nuts": False, "date_columns": []}

    with csv_path.open("r", encoding="utf-8-sig", newline="") as file_obj:
        reader = csv.reader(file_obj)
        try:
            columns = next(reader)
        except StopIteration:
            return {
                "columns": [],
                "row_count": 0,
                "has_nuts": False,
                "date_columns": [],
            }
        row_count = sum(1 for _ in reader)

    date_columns = [
        column
        for column in columns
        if re.search(r"date|year|annee|annee|mois", column, re.IGNORECASE)
    ]
    has_nuts = any(NUTS_COLUMN_RE.search(column) for column in columns)

    return {
        "columns": columns,
        "row_count": row_count,
        "has_nuts": has_nuts,
        "date_columns": date_columns,
    }


def infer_election_context(
    chart_title: str, basemap: str, columns: list[str]
) -> dict[str, object]:
    normalized_title = normalize_text(chart_title)
    years = sorted(set(re.findall(r"(?:19|20)\d{2}", chart_title)))
    has_nuts = (
        any(NUTS_COLUMN_RE.search(column) for column in columns)
        or "nuts" in basemap.lower()
    )

    if (
        "europe" in normalized_title
        or "europeenne" in normalized_title
        or "europeen" in normalized_title
    ):
        election_family = "european"
    elif "legislative" in normalized_title or "legislatives" in normalized_title:
        election_family = "legislative"
    elif "president" in normalized_title:
        election_family = "presidential"
    elif "regional" in normalized_title:
        election_family = "regional"
    else:
        election_family = "unknown"

    return {
        "election_family": election_family,
        "election_years": years,
        "has_nuts": has_nuts,
    }


def download_chart_file(
    session: requests.Session,
    chart_id: str,
    file_name: str,
    output_path: Path,
    timeout: int,
) -> dict[str, object]:
    url = f"https://datawrapper.dwcdn.net/{chart_id}/1/{file_name}"
    response = session.get(url, timeout=timeout)
    result = {
        "chart_id": chart_id,
        "file": file_name,
        "url": url,
        "status_code": response.status_code,
        "path": str(output_path),
        "bytes": 0,
    }

    if response.status_code == 200 and response.content:
        output_path.write_bytes(response.content)
        result["bytes"] = len(response.content)

    return result


def write_country_manifest(
    country_dir: Path,
    country: dict[str, str],
    chart_results: list[dict[str, object]],
    chart_metadata: list[dict[str, object]],
) -> None:
    manifest_path = country_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(
            {"country": country, "charts": chart_metadata, "files": chart_results},
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def write_index(
    output_dir: Path, countries: list[dict[str, str]], rows: list[dict[str, object]]
) -> None:
    (output_dir / "countries.json").write_text(
        json.dumps(countries, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    with (output_dir / "files_index.csv").open(
        "w", newline="", encoding="utf-8"
    ) as file_obj:
        writer = csv.DictWriter(
            file_obj,
            fieldnames=[
                "country_code",
                "slug",
                "page_url",
                "chart_id",
                "file",
                "status_code",
                "bytes",
                "row_count",
                "has_nuts",
                "date_columns",
                "chart_title",
                "chart_type",
                "election_family",
                "election_years",
                "basemap",
                "source_name",
                "path",
                "url",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)


def scrape_all(
    index_url: str, output_dir: Path, timeout: int, delay: float, dry_run: bool
) -> None:
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": "Mozilla/5.0 (compatible; KohesioElectionDataScraper/1.0; +https://github.com/clementlefevre/Kohesio)"
        }
    )

    countries = discover_country_pages(session, index_url, timeout)
    output_dir.mkdir(parents=True, exist_ok=True)

    all_rows: list[dict[str, object]] = []
    print(f"Discovered {len(countries)} country pages from {index_url}")

    for country in countries:
        print(f"[{country['country_code']}] {country['url']}")
        page_text = fetch_text(session, country["url"], timeout)
        chart_ids = discover_datawrapper_ids(page_text)
        print(f"  Datawrapper charts: {len(chart_ids)}")

        country_dir = output_dir / country["slug"]
        chart_results: list[dict[str, object]] = []
        chart_metadata: list[dict[str, object]] = []
        if not dry_run:
            country_dir.mkdir(parents=True, exist_ok=True)
            (country_dir / "page.html").write_text(page_text, encoding="utf-8")

        for chart_id in chart_ids:
            metadata = (
                fetch_chart_metadata(session, chart_id, timeout)
                if not dry_run
                else {"chart_id": chart_id}
            )
            metadata.update(
                {
                    "country_code": country["country_code"],
                    "slug": country["slug"],
                    "page_url": country["url"],
                }
            )
            if not dry_run:
                (country_dir / f"{chart_id}.metadata.json").write_text(
                    json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8"
                )
            chart_metadata.append(metadata)

            for file_name in DOWNLOAD_FILES:
                output_path = country_dir / f"{chart_id}.{file_name}"
                if dry_run:
                    result = {
                        "country_code": country["country_code"],
                        "slug": country["slug"],
                        "page_url": country["url"],
                        "chart_id": chart_id,
                        "file": file_name,
                        "url": f"https://datawrapper.dwcdn.net/{chart_id}/1/{file_name}",
                        "status_code": "DRY_RUN",
                        "path": str(output_path),
                        "bytes": 0,
                        "row_count": 0,
                        "has_nuts": False,
                        "date_columns": "[]",
                        "chart_title": metadata.get("chart_title", ""),
                        "chart_type": metadata.get("chart_type", ""),
                        "election_family": "unknown",
                        "election_years": "[]",
                        "basemap": metadata.get("basemap", ""),
                        "source_name": metadata.get("source_name", ""),
                    }
                else:
                    result = download_chart_file(
                        session, chart_id, file_name, output_path, timeout
                    )
                    profile = read_csv_profile(output_path)
                    context = infer_election_context(
                        str(metadata.get("chart_title", "")),
                        str(metadata.get("basemap", "")),
                        copy.copy(profile["columns"]),
                    )
                    result.update(
                        {
                            "country_code": country["country_code"],
                            "slug": country["slug"],
                            "page_url": country["url"],
                            "row_count": profile["row_count"],
                            "has_nuts": context["has_nuts"],
                            "date_columns": json.dumps(
                                profile["date_columns"], ensure_ascii=False
                            ),
                            "chart_title": metadata.get("chart_title", ""),
                            "chart_type": metadata.get("chart_type", ""),
                            "election_family": context["election_family"],
                            "election_years": json.dumps(
                                context["election_years"], ensure_ascii=False
                            ),
                            "basemap": metadata.get("basemap", ""),
                            "source_name": metadata.get("source_name", ""),
                        }
                    )

                chart_results.append(result)
                all_rows.append(result)

        if not dry_run:
            write_country_manifest(country_dir, country, chart_results, chart_metadata)
        if delay > 0:
            time.sleep(delay)

    write_index(output_dir, countries, all_rows)
    print(f"Wrote raw data index to {output_dir}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scrape raw Le Grand Continent election Datawrapper CSVs by country."
    )
    parser.add_argument(
        "--index-url",
        default=BASE_URL,
        help="Election page used to discover country links.",
    )
    parser.add_argument(
        "--output-dir",
        default="data/elections/raw/legrandcontinent",
        help="Raw output directory.",
    )
    parser.add_argument(
        "--timeout", type=int, default=30, help="HTTP timeout in seconds."
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.2,
        help="Delay between country pages in seconds.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Discover pages/charts without downloading CSV files.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    scrape_all(
        index_url=args.index_url,
        output_dir=Path(args.output_dir),
        timeout=args.timeout,
        delay=args.delay,
        dry_run=args.dry_run,
    )
