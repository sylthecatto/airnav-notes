---
tags:
  - gis
  - aixm
  - qgis
  - moc
aliases:
  - QGIS Start Here
  - AIXM in QGIS
created: 2026-09-07
---

# 00 — Start Here (QGIS)

> [!abstract] What this sub-folder is
> The **desktop** half of `GIS/` — working with **[[21 — AIXM|AIXM]]** data in **QGIS**:
> open real aeronautical data, inspect it, build maps. The **server** half
> (**GeoServer**, which your team uses) is one level up in `GIS/` — see
> [[00 — Start Here (GIS)]]. QGIS is still the tool you'll use to *author styles*
> and *check* what GeoServer publishes, so this track stays relevant.
> Everything here is drawn from **official documentation** (links at the foot of
> every note).

## Why AIXM + GIS go together

AIXM encodes aeronautical information — airspace, runways, navaids, routes — as
**geographic features** built on the OGC **GML** geometry standard. That means
a GIS can read it directly: no bespoke aviation software, just the same tools
used for any spatial data. QGIS is the free, standard desktop GIS, and its
underlying **GDAL/OGR** library can parse AIXM out of the box.

Getting fluent here means you can **see** what a dataset actually contains,
spot errors, prototype products, and speak precisely with data engineers.

## The path through this folder

| # | Note | You come out able to… |
|---|---|---|
| 01 | [[01 — AIXM essentials for GIS]] | explain features, GML, temporality and the message wrapper — the parts that matter when the data hits a GIS |
| 02 | [[02 — Sample data]] | get legitimate AIXM datasets to practise on (Donlon, FAA NASR) — one is already downloaded for you |
| 03 | [[03 — QGIS and the Data Source Manager]] | drive QGIS's data-loading UI and set the right coordinate system |
| 04 | [[04 — Load AIXM into QGIS (GML driver)]] | open an AIXM file and get one map layer per feature type |
| 05 | [[05 — GMLAS and GeoPackage (the robust route)]] | convert AIXM to a clean database for heavier work and round-tripping |
| 06 | [[06 — Exercise — Donlon airspace map]] | produce a finished, styled, labelled airspace map start to finish |
| 07 | [[07 — Command and option reference]] | look up every `ogrinfo` / `ogr2ogr` flag and open option used here |
| 08 | [[08 — Learning QGIS]] | pick the right courses/videos — AIXM-first, then the QGIS mechanics underneath |

Read `01` and `02`, then do `03`→`06` in order with QGIS open. `08` is the
outside-this-folder study plan (start it in parallel).

## What's already set up

- **QGIS 4.2** is installed (Flatpak, per-user). Launch: app menu → *QGIS
  Desktop*, or `flatpak run org.qgis.qgis`.
- **`sample-data/`** in this folder holds the **Donlon** fictitious AIP dataset
  (`EA_AIP_DS_FULL_20170701.xml`, AIXM 5.1.1) plus a ready-made `donlon.gpkg`
  so you can see results immediately.

## How this links to the concept notes

| GIS topic here | Concept note |
|---|---|
| the data model, features, versions | [[21 — AIXM]] |
| BASELINE / PERMDELTA / TEMPDELTA, time slices | [[22 — AIXM Temporality Model]] |
| coordinates, CRS, projections, GML | [[20 — GIS]] |
| where operational AIXM comes from | [[25 — EAD]] |
| digital NOTAM as an AIXM change | [[15 — NOTAMs]] · [[16 — OPADD]] |

## Sources

- AIXM — official site: <https://aixm.aero>
- QGIS Documentation (User Manual, 3.44): <https://docs.qgis.org/3.44/en/docs/user_manual/>
- GDAL/OGR vector drivers: <https://gdal.org/en/stable/drivers/vector/>
