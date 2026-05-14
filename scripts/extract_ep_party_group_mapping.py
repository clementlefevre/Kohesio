"""
Extract national party → EP political group mapping from the downloaded
European Parliament results JSON files.

Outputs:
  data/elections/raw/european_parliament_results/party_group_mapping.csv
  data/elections/raw/european_parliament_results/ep_groups.csv

Usage:
  python scripts/extract_ep_party_group_mapping.py
"""

import csv
import json
from pathlib import Path

JSON_ROOT = Path("data/elections/raw/european_parliament_results/json")
OUT_PARTIES = Path("data/elections/raw/european_parliament_results/party_group_mapping.csv")
OUT_GROUPS = Path("data/elections/raw/european_parliament_results/ep_groups.csv")

TERMS = [
    "1979-1984", "1984-1989", "1989-1994", "1994-1999",
    "1999-2004", "2004-2009", "2009-2014", "2014-2019",
    "2019-2024", "2024-2029",
]
PHASES = ["election-results", "outgoing-parliament"]


def load_json(path: Path):
    if not path.exists():
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def extract_groups(term: str, phase: str) -> dict[str, str]:
    """Return {groupId: groupAcronym_EN} for the term/phase."""
    data = load_json(JSON_ROOT / term / phase / "groups.json")
    if not data:
        return {}
    result = {}
    for g in data.get("groups", []):
        gid = g.get("groupId", "")
        # prefer English acronym, fall back to groupId
        acronym = gid
        for t in g.get("translations", []):
            if t.get("languageId") == "EN":
                acronym = t.get("groupAcronym", gid)
                break
        result[gid] = acronym
    return result


def extract_parties(term: str, phase: str) -> dict[str, dict]:
    """Return {candidateId: {acronym, longName, countryId}} for the term/phase."""
    data = load_json(JSON_ROOT / term / phase / "parties.json")
    if not data:
        return {}
    result = {}
    for country in data.get("countries", []):
        cid = country.get("countryId", "")
        for c in country.get("candidates", []):
            pid = c.get("candidateId", "")
            result[pid] = {
                "country_id": cid,
                "party_id": pid,
                "party_acronym": c.get("candidateAcronym", ""),
                "party_long_name": c.get("candidateLongName", ""),
                "candidate_type": c.get("candidateType", ""),
            }
    return result


def extract_country_party_groups(term: str, phase: str, parties: dict) -> list[dict]:
    """Walk all country JSON files and resolve party→group from seatsByParty."""
    rows = []
    base = JSON_ROOT / term / phase
    for country_file in sorted(base.glob("*.json")):
        if country_file.stem in ("parties", "groups", "gender-balance", "eu", "turnout", "labels"):
            continue
        country_id = country_file.stem.upper()
        data = load_json(country_file)
        if not data:
            continue

        seats_by_party = (
            data.get("partySummary", {}) or {}
        ).get("seatsByParty", []) or []

        def process_entry(entry, coalition_id=None, coalition_acronym=None):
            pid = entry.get("id", "")
            pinfo = parties.get(pid, {})
            group_dist = entry.get("groupDistribution") or []

            ep_groups = [g["id"] for g in group_dist if g.get("id")]
            ep_group = ep_groups[0] if ep_groups else None

            rows.append({
                "term": term,
                "phase": phase,
                "country_id": country_id,
                "party_id": pid,
                "party_acronym": pinfo.get("party_acronym", ""),
                "party_long_name": pinfo.get("party_long_name", ""),
                "candidate_type": entry.get("type") or pinfo.get("candidate_type", ""),
                "coalition_id": coalition_id,
                "coalition_acronym": coalition_acronym,
                "ep_group_id": ep_group,
                "seats_total": entry.get("seatsTotal", 0),
                "votes_percent": entry.get("votesPercent"),
            })

        for entry in seats_by_party:
            process_entry(entry)
            # handle coalition members
            for member in entry.get("members") or []:
                process_entry(
                    member,
                    coalition_id=entry.get("id"),
                    coalition_acronym=parties.get(entry.get("id", ""), {}).get("party_acronym", ""),
                )

    return rows


def main():
    all_rows: list[dict] = []
    all_groups: list[dict] = []
    seen_groups: set[str] = set()

    for term in TERMS:
        for phase in PHASES:
            parties = extract_parties(term, phase)
            groups = extract_groups(term, phase)

            for gid, acronym in groups.items():
                key = f"{term}|{phase}|{gid}"
                if key not in seen_groups:
                    seen_groups.add(key)
                    all_groups.append({"term": term, "phase": phase, "group_id": gid, "group_acronym": acronym})

            rows = extract_country_party_groups(term, phase, parties)
            # attach group acronym
            for r in rows:
                r["ep_group_acronym"] = groups.get(r["ep_group_id"], r["ep_group_id"]) if r["ep_group_id"] else None
            all_rows.extend(rows)
            print(f"  {term}/{phase}: {len(rows)} party entries")

    # write party-group mapping
    OUT_PARTIES.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "term", "phase", "country_id", "party_id", "party_acronym", "party_long_name",
        "candidate_type", "coalition_id", "coalition_acronym",
        "ep_group_id", "ep_group_acronym", "seats_total", "votes_percent",
    ]
    with open(OUT_PARTIES, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(all_rows)

    # write group reference
    with open(OUT_GROUPS, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["term", "phase", "group_id", "group_acronym"])
        w.writeheader()
        w.writerows(all_groups)

    print(f"\nWrote {len(all_rows)} rows → {OUT_PARTIES}")
    print(f"Wrote {len(all_groups)} group entries → {OUT_GROUPS}")

    # quick summary: parties with known EP group, 2024-2029
    print("\n--- 2024-2029 election-results: party→group sample (first 15 with group) ---")
    shown = 0
    for r in all_rows:
        if r["term"] == "2024-2029" and r["phase"] == "election-results" and r["ep_group_id"] and r["candidate_type"] != "COALITION":
            print(f"  {r['country_id']} | {r['party_acronym']:<25} | {r['ep_group_acronym']}")
            shown += 1
            if shown >= 15:
                break


if __name__ == "__main__":
    main()
