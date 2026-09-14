---
tags:
  - gis
  - geoserver
  - aixm
  - moc
aliases:
  - GIS Start Here
  - GeoServer Track
  - GIS MOC
created: 2026-09-09
---

# 00 — Start Here (GIS)

> [!abstract] The 30-second version
> `GIS/` has two halves. **`QGIS/`** is the *desktop* tool — open a dataset,
> look at it, style it, check it. **This level** is **GeoServer** — the
> *server* that publishes geospatial data to other systems as standard **OGC
> web services**. Your team uses GeoServer to serve **[[21 — AIXM|AIXM]] / aeronautical
> data**, so that's where this track goes deep — including the parts that
> overlap your vulnerability-management job (GeoServer is a Java web app you
> patch and harden).

## Desktop vs server — how the pieces fit

```
        author / inspect / style              publish / serve
        ┌───────────────────┐                ┌───────────────────┐
data ──▶│      QGIS          │── SLD style ─▶ │     GeoServer      │──▶ WMS / WFS / OGC API ──▶ clients
        │  (GIS/QGIS/)       │◀── WMS/WFS ────│   (this folder)    │        (browsers, QGIS,
        └───────────────────┘   as a client  └─────────┬─────────┘         other servers, apps)
                                                       │ reads from
                                              ┌────────▼─────────┐
                                              │  PostGIS / files │
                                              └──────────────────┘
```

- **QGIS** — a person's workbench. Not a server. Used here to *design styles*
  and *verify* what GeoServer publishes.
- **PostGIS** — a spatial database (PostgreSQL + geometry). The usual store
  GeoServer reads from in production.
- **GeoServer** — turns whatever is in PostGIS / files into **WMS** (a picture
  of a map), **WFS** (the actual features/geometry), **WCS** (rasters),
  **WMTS/tiles**, and **OGC API** endpoints — over HTTP, to any client.
- **AIXM** on GeoServer uses the **app-schema** extension: it maps database
  tables to the AIXM GML schema and serves true **complex features**.

## The path through this folder

| # | Note | Covers |
|---|---|---|
| 01 | [[01 — What GeoServer Is]] | architecture, the stack (GeoTools, GeoWebCache), request lifecycle, alternatives |
| 02 | [[02 — Install and Run]] | WAR / binary / Docker, on RHEL + Tomcat, the data directory, first login |
| 03 | [[03 — The Data Model]] | workspace → store → layer → style; layer groups; the config tree |
| 04 | [[04 — Connecting Data]] | PostGIS (primary), GeoPackage, shapefile, GeoTIFF; SRS handling |
| 05 | [[05 — OGC Services]] | WMS / WFS / WCS / WMTS / OGC API — operations, GetCapabilities, settings |
| 06 | [[06 — Styling — SLD and CSS]] | SLD structure, rules/filters/symbolizers/labels; CSS; exporting from QGIS |
| 07 | [[07 — GeoWebCache]] | tile caching, gridsets, seeding, integrated vs standalone |
| 08 | [[08 — App-Schema and Complex Features]] | the mapping file, source→target, feature chaining, hale studio |
| 09 | [[09 — Serving AIXM]] | AIXM 5.1 as an app-schema, PostGIS backing, the EAD pattern, the traps |
| 10 | [[10 — REST API and Config-as-Code]] | the REST config API, `curl`/Python, backup/restore, the Importer |
| 11 | [[11 — Security Model]] | auth chain, users/groups/roles, service/data/REST rules, the admin console |
| 12 | [[12 — Hardening and the CVE Track]] | production security checklist + GeoServer's CVE history (your job) |
| 13 | [[13 — Production and Ops]] | JVM/GC, control-flow, monitoring, logging, clustering, upgrades |
| 14 | [[14 — Learning Resources]] | official docs, GeoSolutions training, tutorials, books |

Read `01`→`07` in order to get the model, then `08`+`09` for the AIXM job,
then `10`–`13` are the operator's reference. `12` is the one that ties to
`CVEs/`.

## How it links to the rest of the vault

| GIS topic | Concept / other note |
|---|---|
| what AIXM *is*, features, GML | [[21 — AIXM]], [[01 — AIXM essentials for GIS\|QGIS 01]] |
| time slices (BASELINE / DELTA) as feature chaining | [[22 — AIXM Temporality Model]] |
| CRS, projections, GML geometry | [[20 — GIS]] |
| where operational AIXM services live | [[25 — EAD]] · [[26 — SWIM]] |
| GeoServer as a patch/harden target | [[AirNav WINGS Cadet/AirNav DAS/CVEs/00 — Start Here\|CVEs track]], `Roadmap.md` Track 3 |

## Sources

- GeoServer — *User Manual*: <https://docs.geoserver.org/latest/en/user/>
- GeoServer project site (downloads, blog, security advisories): <https://geoserver.org>
- GeoSolutions — free *GeoServer Training* modules: <https://geoserver.geosolutionsgroup.com/edu/en/>
