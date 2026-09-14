---
tags:
  - aixm-gis
  - aixm
  - data
created: 2026-09-07
---

# 02 — Sample data

> [!abstract] The 30-second version
> Practise on **Donlon** — an official, deliberately fictitious AIP dataset
> published by EUROCONTROL/FAA specifically for learning AIXM. A copy is
> already in **`sample-data/`**. For real-world data, the **FAA NASR** 28-day
> subscription is free and public.

## Donlon (use this)

A fictitious country "somewhere in the middle of the Atlantic", coded to ICAO
Annex 15 (16th ed.) / PANS-AIM in **AIXM 5.1.1**. Published by the AIXM team as
the canonical teaching dataset. **BSD-licensed, © EUROCONTROL & FAA.**

> [!warning] Never operational
> The licence and every file header say it in capitals: this data is
> fictitious and **shall never be used as operational data**. It exists only
> for learning and testing.

### Already downloaded

`sample-data/EA_AIP_DS_FULL_20170701.xml` — a full **AIP BASELINE** (~380 KB):
airports (Donlon Intl **EADD**, Downtown Heliport **EADH**, Akvin **EADA**…),
airspace, VOR/DME/NDB/ILS navaids, designated points, routes and route
segments, runways. Small enough to open instantly, complete enough to be
representative.

`sample-data/donlon.gpkg` — the same data pre-converted to a GeoPackage (see
[[04 — Load AIXM into QGIS (GML driver)]]). Open this first for an instant look;
then learn to reproduce it.

`sample-data/EA_AIP_DS_FULL_20170701.gfs` — a sidecar GDAL writes automatically
(schema it discovered). Leave it; delete it to force a re-scan.

### The wider Donlon repositories (download if you want more)

| Repo | What's extra | Get it |
|---|---|---|
| **`aixm/donlon`** (archived) | the single file above, plus **Obstacle** datasets, a **`DigitalNOTAM/`** folder (43 TEMPDELTA examples) and a **Temporality** folder with BASELINE + DELTA AIRAC snapshots | <https://github.com/aixm/donlon> |
| **`aixm/Donlon_2025`** (current) | much larger; per-feature / per-airport "ADM upload" files, coordination-event examples, digital NOTAM, "EAD-SDD temporality cases" | <https://github.com/aixm/Donlon_2025> |

> [!tip] Clone with git
> ```
> cd "GIS/QGIS/sample-data"
> git clone https://github.com/aixm/donlon.git
> git clone https://github.com/aixm/Donlon_2025.git
> ```
> The digital-NOTAM and temporality folders are what you use once
> [[22 — AIXM Temporality Model]] clicks.

## FAA NASR — real data, AIXM 5.1

The US **National Airspace System Resources** subscription, refreshed every
**28 days** (an [[14 — AIRAC|AIRAC]] cycle). The **Navigation Aid, Airport,
ASOS/AWOS and Airway** subscriber files are provided as **AIXM 5.1**.

- Landing page pattern:
  `https://www.faa.gov/air_traffic/flight_info/aeronav/aero_data/NASR_Subscription/<YYYY-MM-DD>/`
- Free, no login. Download the AIXM 5.1 subscriber files (`.zip` of `.xml`).

Real data is messier than Donlon — good second step, not a first one.

## EUROCONTROL EAD

Europe's operational data comes from **[[25 — EAD|EAD]]** as AIXM. Access needs an
account and is role-restricted, so it's out of scope for self-study, but it's
the "where this actually lives" answer.

## Sources

- Donlon (current): <https://github.com/aixm/Donlon_2025>
- Donlon (archived, single-file + digital NOTAM + temporality): <https://github.com/aixm/donlon>
- Donlon AIP Data Set Specimen (EUROCONTROL AIXM Confluence): <https://ext.eurocontrol.int/aixm_confluence/pages/viewpage.action?pageId=20415246>
- FAA 28-Day NASR Subscription: <https://www.faa.gov/air_traffic/flight_info/aeronav/aero_data/>
