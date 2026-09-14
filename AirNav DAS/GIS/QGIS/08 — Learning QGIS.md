---
tags:
  - aixm-gis
  - qgis
  - aixm
  - reference
created: 2026-09-08
---

# 08 — Learning QGIS (for AIXM / aviation)

> [!abstract] The honest picture
> There is **no single polished "AIXM in QGIS, step by step" video course** — the
> niche is too small. What exists: (1) **official AIXM e-learning** from
> EUROCONTROL, (2) **one practitioner** who publishes aviation-GIS-in-QGIS
> tutorials for free, (3) a couple of **paid professional courses** aimed at
> AIS/charting staff, and (4) generic QGIS courses for the mechanics underneath.
> Combine 1 + 2 with the rest of this folder and you have a real curriculum.

## 1 · AIXM itself — official, free (start here)

**EUROCONTROL Training Zone** e-learning — the canonical AIXM courses:

| Course | Covers | Note |
|---|---|---|
| **IM-AIXM-1** — *AIXM 5 Information Modelling & Data Coding Basics* | UML, XML, GML — the modelling language AIXM is written in | ~8 h · **already registered** (approved 2026-09-04) |
| **IM-AIXM-2** — *AIXM 5 Purpose, Scope & Design Concepts* | the feature model, temporality, why AIXM is shaped as it is | for AIS + technical staff |
| **IM-AIXM-3** — *Coding & Provision of ICAO Digital Data Sets* | encoding real datasets (AIP, obstacle, aerodrome mapping…) | most hands-on of the three |

- Sign-up: <https://trainingzone.eurocontrol.int> → search "AIXM".
- **AIXM training archive** (seminar + Digital NOTAM workshop slide decks, no
  video): <https://aixm.aero/page/training>
- Pairs with [[01 — AIXM essentials for GIS]] and [[21 — AIXM]] / [[22 — AIXM Temporality Model]].

## 2 · QGIS applied to aviation data — free, the closest thing to what you want

**Antonio Locandro** — aeronautical cartographer & PANS-OPS designer, certified
QGIS trainer for aviation. Blog + YouTube, mostly free:

- Website: <https://antoniolocandro.com> (categories: *AIXM*, *QGIS*, *AIM*)
- YouTube: <https://www.youtube.com/AntonioLocandro>
- Directly relevant posts/videos:
  - ***Reading AIXM Obstacle Data*** — opening AIXM 5.1 `VerticalStructure` in QGIS
  - ***AIXM Import into ArcGIS using QGIS*** — the QGIS-as-converter pattern (same as [[05 — GMLAS and GeoPackage (the robust route)]])
  - ***Opensource Aeronautical Solution for Charting using QGIS*** — the full toolchain
  - ***Making an Instrument Approach Chart using QGIS*** (multi-part) — cartography workflow
  - QGIS **aviation symbol sets** (working toward ICAO Annex 4 parity), OLS / TOFPA surfaces

## 3 · Structured paid courses (if you want a syllabus + certificate)

| Provider | Course(s) | Focus |
|---|---|---|
| **MAIS Learning** (Managed AIS) — <https://www.mais-learning.com> | *Introduction to GIS for Aviation*; *Aeronautical Charting (CHART)*; new *QGIS Aviation Charting* courses | build Enroute / Area / ATS Surveillance Minimum charts in QGIS per ICAO docs |
| **FLYGHT7** — <https://flyght7.com/training> | *QGIS Fundamentals: Aviation Track* | extract-transform-load of aeronautical data, print layouts, simple web maps |
| **Antonio Locandro** | paid aviation-charting courses (linked from his site) | deeper than the free blog series |

## 4 · Real projects to pull apart

- **`jlmcgraw/aviationMap`** (GitHub) — a working QGIS project that renders an
  aeronautical map (airspace, airports, METAR, SIGMET) from **FAA open data**.
  Open it, read the layer styles and label expressions — that's how experienced
  people set up aviation QGIS. <https://github.com/jlmcgraw/aviationMap>
- **Donlon** in `sample-data/` — your own sandbox ([[02 — Sample data]]).

## 5 · AIXM-native viewers (not QGIS, but worth knowing)

- **Luciad AIXM 5 Viewer** (Hexagon) — free; view/verify AIXM 5 data and see
  changes over time. Good for sanity-checking what QGIS shows you.
- **ArcGIS Aviation** (Esri) — the commercial incumbent for AIXM + charting;
  useful to know it exists even if you use QGIS.

## 6 · The generic QGIS mechanics underneath

You only need the basics, and only the parts [[04 — Load AIXM into QGIS (GML driver)]]
and [[06 — Exercise — Donlon airspace map]] use. Any *one* of these covers them:

- **Ujaval Gandhi — *Introduction to QGIS*** (Spatial Thoughts) — free video
  course + data: <https://courses.spatialthoughts.com/introduction-to-qgis.html>
- **QGIS Tutorials and Tips** (same author) — free written how-tos: <https://www.qgistutorials.com/>
- **Official QGIS Training Manual** — <https://docs.qgis.org/latest/en/docs/training_manual/>

The 20% to make sure you can do: Data Source Manager · CRS (project vs layer,
`EPSG:4326`) · Attribute Table + **filter** · **expressions** · **Categorized**
symbology · labels · Print Layout · DB Manager SQL. Skip rasters, analysis
models, QGIS Server for now.

## A suggested order

1. **IM-AIXM-1** (you're enrolled) + [[01 — AIXM essentials for GIS]].
2. One QGIS intro (§6) — just the basics, ~4–6 h.
3. This folder's [[04 — Load AIXM into QGIS (GML driver)]] → [[06 — Exercise — Donlon airspace map]].
4. Antonio Locandro's *Reading AIXM Obstacle Data* + *Charting using QGIS*.
5. **IM-AIXM-2 / IM-AIXM-3**, then pull apart `aviationMap` and try FAA NASR data.

## Sources

- EUROCONTROL Training Zone: <https://trainingzone.eurocontrol.int>
- AIXM — *Training* (archive + course links): <https://aixm.aero/page/training>
- Antonio Locandro — AIM / aeronautical charting / QGIS: <https://antoniolocandro.com>
- MAIS Learning — GIS for Aviation / Aeronautical Charting: <https://www.mais-learning.com>
- `jlmcgraw/aviationMap`: <https://github.com/jlmcgraw/aviationMap>
- Spatial Thoughts — *Introduction to QGIS*: <https://courses.spatialthoughts.com/introduction-to-qgis.html>
