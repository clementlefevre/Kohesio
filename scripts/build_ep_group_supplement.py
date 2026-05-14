"""
Build data/elections/supplements/party_ep_group_overrides.csv

This covers two classes of mismatch between the EU-NED national election winner names
and the BLUE EP election party_group_mapping.csv:

  (A) Country code divergence: Greece is "EL" in BLUE but "GR" in EU-NED/NUTS.
      Handled by the SQL EL→GR remap; we only need the supplemental rows for party
      name variants that still don't match after the code remap.

  (B) Party name variants: "OVP" vs "ÖVP", "MOVIMENTO 5 STELLE" vs "M5S", etc.

  (C) Parties not in the BLUE dataset at all (e.g. France's REM, Sweden's SAP,
      Bulgaria's GERB under the full bilingual acronym, etc.).

Columns: country_code (NED/NUTS code), ned_party_name, ep_group_acronym
"""

import csv, pathlib

SUPPLEMENT = [
    # ── Greece (GR in NED, EL in BLUE) ──────────────────────────────────────
    # The SQL will also remap country_code GR→EL; these rows cover the name
    # variants that still don't match even with the remapped country.
    ("GR", "ND",      "EPP"),      # Νέα Δημοκρατία / New Democracy
    ("GR", "SYRIZA",  "GUE/NGL"), # Συνασπισμός Ριζοσπαστικής Αριστεράς
    ("GR", "PASOK",   "S&D"),
    ("GR", "KKE",     "GUE/NGL"),
    # ── Austria ─────────────────────────────────────────────────────────────
    # BLUE uses ÖVP / SPÖ / FPÖ with umlauts; NED stores OVP / SPO / FPO
    ("AT", "OVP",     "EPP"),
    ("AT", "ÖVP",     "EPP"),
    ("AT", "SPO",     "S&D"),
    ("AT", "SPÖ",     "S&D"),
    ("AT", "FPO",     "ID"),
    ("AT", "FPÖ",     "ID"),
    ("AT", "GRUNE",   "Greens/EFA"),
    ("AT", "JETZT",   "Greens/EFA"),
    ("AT", "NEOS",    "RE"),
    # ── Germany ─────────────────────────────────────────────────────────────
    # BLUE has "AfD", NED sometimes stores "AFD" (all-caps)
    ("DE", "AFD",     "ID"),
    ("DE", "AfD",     "ID"),
    ("DE", "CDU",     "EPP"),
    ("DE", "CSU",     "EPP"),
    # ── Italy ───────────────────────────────────────────────────────────────
    # NED stores full Italian names; BLUE uses short acronyms
    ("IT", "MOVIMENTO 5 STELLE", "NI"),
    ("IT", "M5S",                "NI"),
    ("IT", "LEGA NORD",          "ID"),
    ("IT", "LEGA",               "ID"),
    ("IT", "LN",                 "ID"),
    ("IT", "PARTITO DEMOCRATICO","S&D"),
    ("IT", "PD",                 "S&D"),
    ("IT", "FdI",                "ECR"),
    ("IT", "FDI",                "ECR"),
    ("IT", "FRATELLI D'ITALIA",  "ECR"),
    ("IT", "FORZA ITALIA",       "EPP"),
    ("IT", "FI",                 "EPP"),
    ("IT", "SVP",                "EPP"),
    # ── France ──────────────────────────────────────────────────────────────
    # REM / LREM = La République En marche → Renew Europe / RE
    ("FR", "REM",     "RE"),
    ("FR", "LREM",    "RE"),
    ("FR", "LR",      "EPP"),
    ("FR", "RN",      "ID"),
    ("FR", "FI",      "GUE/NGL"),
    ("FR", "EELV",    "Greens/EFA"),
    # ── Sweden ──────────────────────────────────────────────────────────────
    # BLUE "S" = Socialdemokraterna; NED abbreviates as SAP
    ("SE", "SAP",     "S&D"),
    ("SE", "S",       "S&D"),
    ("SE", "M",       "EPP"),   # Moderaterna
    ("SE", "SD",      "ECR"),   # Sverigedemokraterna (note: in 2024 joined Patriots)
    ("SE", "KD",      "EPP"),
    ("SE", "V",       "GUE/NGL"),
    ("SE", "C",       "RE"),
    ("SE", "L",       "RE"),
    ("SE", "MP",      "Greens/EFA"),
    # ── Hungary ─────────────────────────────────────────────────────────────
    # FIDESZ expelled from EPP March 2021; 2022 national election → NI
    ("HU", "FIDESZ-KDNP",       "NI"),
    ("HU", "Coal (FIDESZ + KDNP)","NI"),
    ("HU", "FIDESZ",            "NI"),
    ("HU", "JOBBIK",            "NI"),
    ("HU", "DK",                "S&D"),
    # ── Bulgaria ────────────────────────────────────────────────────────────
    # BLUE has "GERB/ГЕРБ"; NED stores "GERB"
    ("BG", "GERB",    "EPP"),
    ("BG", "GERB/ГЕРБ","EPP"),
    ("BG", "KB",      "S&D"),   # Koalitsiya za Bulgaria (BSP-led)
    ("BG", "BSP",     "S&D"),
    ("BG", "DPS",     "RE"),
    # ── Denmark ─────────────────────────────────────────────────────────────
    # BLUE "A (S)" = Socialdemokratiet; NED uses "SD"
    ("DK", "SD",      "S&D"),
    ("DK", "A (S)",   "S&D"),
    ("DK", "V (V)",   "RE"),    # Venstre
    ("DK", "V",       "RE"),
    ("DK", "C (KF)",  "EPP"),
    ("DK", "O (DF)",  "ID"),
    # ── Lithuania ───────────────────────────────────────────────────────────
    # "Homeland Union" = TS-LKD = EPP
    ("LT", "HOMELAND UNION",     "EPP"),
    ("LT", "TS-LKD",             "EPP"),
    ("LT", "LSDP",               "S&D"),
    ("LT", "LVŽS",               "Greens/EFA"),
    ("LT", "LRLS",               "RE"),
    # ── Latvia ──────────────────────────────────────────────────────────────
    ("LV", "JV",      "RE"),    # Jaunā Vienotība = New Unity = Renew Europe
    ("LV", "HARMONY", "S&D"),
    ("LV", "Saskaņa SDP","S&D"),
    ("LV", "NA",      "ECR"),   # Nacionālā apvienība
    # ── Slovakia ────────────────────────────────────────────────────────────
    ("SK", "OLANO",   "EPP"),
    ("SK", "Coal (OL'aNO + NOVA)","EPP"),
    ("SK", "SMER-SD", "NI"),    # SMER left S&D in 2024
    ("SK", "SMER",    "NI"),
    ("SK", "PS",      "RE"),    # Progresívne Slovensko
    # ── Czech Republic ──────────────────────────────────────────────────────
    ("CZ", "ANO",     "RE"),    # ANO 2011 was in RE/ALDE
    ("CZ", "ANO 2011","RE"),
    ("CZ", "SPOLU – ODS, KDU-ČSL, TOP 09","ECR"),  # SPOLU coalition led by ODS
    ("CZ", "SPOLU",   "ECR"),
    ("CZ", "ODS",     "ECR"),
    ("CZ", "PIRATE",  "Greens/EFA"),
    # ── Croatia ─────────────────────────────────────────────────────────────
    # Kukuriku = SDP-led coalition → S&D
    ("HR", "KUKURIKU","S&D"),
    ("HR", "SDP",     "S&D"),
    ("HR", "HDZ",     "EPP"),
    # ── Cyprus ──────────────────────────────────────────────────────────────
    ("CY", "DISY",    "EPP"),
    ("CY", "ΔΗΣΥ/DISY","EPP"),
    ("CY", "AKEL",    "GUE/NGL"),
    # ── Malta ───────────────────────────────────────────────────────────────
    ("MT", "PN",      "EPP"),
    ("MT", "PL",      "S&D"),
    ("MT", "PN/NP",   "EPP"),
    ("MT", "PL/MLP",  "S&D"),
    # ── Luxembourg ──────────────────────────────────────────────────────────
    ("LU", "CSV",     "EPP"),
    ("LU", "CSV/PCS", "EPP"),
    ("LU", "LSAP",    "S&D"),
    ("LU", "DP",      "RE"),
    # ── Ireland ─────────────────────────────────────────────────────────────
    ("IE", "FG",      "EPP"),
    ("IE", "FF",      "RE"),
    ("IE", "SF",      "GUE/NGL"),
    # ── Netherlands ─────────────────────────────────────────────────────────
    ("NL", "VVD",     "RE"),
    ("NL", "PVV",     "ID"),
    ("NL", "CDA",     "EPP"),
    ("NL", "D66",     "RE"),
    ("NL", "PvdA",    "S&D"),
    ("NL", "GL",      "Greens/EFA"),
    ("NL", "GroenLinks","Greens/EFA"),
    ("NL", "SP",      "GUE/NGL"),
    # ── Poland ──────────────────────────────────────────────────────────────
    ("PL", "PIS",     "ECR"),
    ("PL", "PiS",     "ECR"),
    ("PL", "PO",      "EPP"),
    ("PL", "KO",      "EPP"),   # Koalicja Obywatelska
    # ── Romania ─────────────────────────────────────────────────────────────
    ("RO", "PSD",     "S&D"),
    ("RO", "PNL",     "EPP"),
    ("RO", "USR",     "RE"),
    # ── Spain ───────────────────────────────────────────────────────────────
    # NED uses "PSOE" while BLUE EP data uses "PSOE/PSC"
    ("ES", "PSOE",    "S&D"),
    ("ES", "PSOE/PSC","S&D"),
    ("ES", "PP",      "EPP"),
    ("ES", "C's",     "RE"),
    ("ES", "VOX",     "ECR"),
    ("ES", "UP",      "GUE/NGL"),
    ("ES", "Sumar",   "GUE/NGL"),
    # ── Portugal ────────────────────────────────────────────────────────────
    # NED uses "PPD/PSD" while BLUE uses "PSD"
    ("PT", "PPD/PSD", "EPP"),
    ("PT", "PSD",     "EPP"),
    ("PT", "PS",      "S&D"),
    ("PT", "BE",      "GUE/NGL"),
    ("PT", "B.E.",    "GUE/NGL"),
    # ── Latvia ──────────────────────────────────────────────────────────────
    ("LV", "SC",      "S&D"),   # Saskaņa centrs (Social Coalition)
    ("LV", "KPV LV",  "NI"),    # Kam pieder valsts — populist, no clear EP group
    ("LV", "JKP",     "ECR"),   # Jaunā konservatīvā partija
    # ── Lithuania ───────────────────────────────────────────────────────────
    # NED uses the English long name; supplement adds the English variant
    ("LT", "LITHUANIAN PEASANT AND GREENS UNION", "Greens/EFA"),
    ("LT", "LVŽS",    "Greens/EFA"),
    # ── Croatia ─────────────────────────────────────────────────────────────
    # HDZ coalition variants all = EPP
    ("HR", "HDZ-HDS",  "EPP"),
    ("HR", "HDZ-HSLS", "EPP"),
    ("HR", "GREEN-LEFT","Greens/EFA"),
    # ── Malta ───────────────────────────────────────────────────────────────
    # MLP/PL is the same party as PL/MLP
    ("MT", "MLP/PL",   "S&D"),
    ("MT", "MLP",      "S&D"),
    # ── Italy ───────────────────────────────────────────────────────────────
    # SVP-PATT coalition (South Tyrol, EPP-affiliated)
    ("IT", "SVP - PATT","EPP"),
    ("IT", "SVP-PATT",  "EPP"),
    # ── Estonia ─────────────────────────────────────────────────────────────
    ("EE", "EK",       "RE"),   # Eesti Keskerakond → ALDE/Renew
    # ── Finland ─────────────────────────────────────────────────────────────
    ("FI", "RKP",      "RE"),   # SFP/RKP = Swedish People's Party → Renew
    ("FI", "SFP (RKP)","RE"),
    ("FI", "KOK",      "EPP"),
    ("FI", "KESK",     "RE"),
    ("FI", "SDP",      "S&D"),
    ("FI", "VAS",      "GUE/NGL"),
    ("FI", "VIHR",     "Greens/EFA"),
    ("FI", "PS",       "ECR"),
    # ── Spain regional/coalition variants ───────────────────────────────────
    ("ES", "ERC-SOBIRANISTES", "Greens/EFA"),  # Esquerra Republicana → G/EFA
    ("ES", "ERC",              "Greens/EFA"),
    ("ES", "NA+",              "NI"),  # small regional
    ("ES", "íTERUEL EXISTE!",  "NI"),  # local movement
    ("ES", "TERUEL EXISTE",    "NI"),
    # ── France misc ─────────────────────────────────────────────────────────
    ("FR", "MDM",       "RE"),  # Mouvement Démocrate = MoDem = Renew Europe
    ("FR", "OTHER LEFT","GUE/NGL"),
    ("FR", "REG",       "NI"),  # Regionalist party
]

outpath = pathlib.Path("data/elections/supplements/party_ep_group_overrides.csv")
outpath.parent.mkdir(parents=True, exist_ok=True)

with open(outpath, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["country_code", "ned_party_name", "ep_group_acronym"])
    seen = set()
    for row in SUPPLEMENT:
        key = (row[0], row[1])
        if key not in seen:
            seen.add(key)
            w.writerow(row)

print(f"Written {sum(1 for _ in seen)} rows to {outpath}")
