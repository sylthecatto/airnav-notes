---
tags:
  - gis
  - geoserver
  - postgis
created: 2026-09-09
---

# 04 — Connecting Data

> [!abstract] The 30-second version
> In production the answer is almost always **PostGIS** — PostgreSQL with the
> spatial extension. GeoServer connects with a pooled JDBC store, reads tables
> and views as feature types, and pushes filters down into SQL. Files
> (**GeoPackage**, **GeoTIFF**) are fine for static reference data; the
> **shapefile** is legacy and should be avoided for anything real.

## PostGIS — the production store

### Set it up (RHEL)

```
dnf install postgresql-server postgresql-contrib postgis
postgresql-setup --initdb && systemctl enable --now postgresql
sudo -u postgres createdb aixm
sudo -u postgres psql -d aixm -c "CREATE EXTENSION postgis;"
sudo -u postgres psql -c "CREATE USER gs_ro WITH PASSWORD '…';"
sudo -u postgres psql -d aixm -c "GRANT USAGE ON SCHEMA public TO gs_ro; \
  GRANT SELECT ON ALL TABLES IN SCHEMA public TO gs_ro;"
```

> [!warning] Use a **read-only** DB user
> GeoServer only needs `SELECT` unless you run **WFS-T** (writes). A read-only
> role removes SQL-injection impact and accidental data loss. This is in the
> official production checklist. ([[12 — Hardening and the CVE Track]])

### Connect it

Stores → Add store → **PostGIS**. Key params:

| Param | Note |
|---|---|
| host / port / database | the obvious |
| schema | `public` by default; app-schema often uses a dedicated schema |
| user / passwd | the **read-only** role |
| `Loose bbox` | faster bbox filtering, slight inaccuracy at edges — usually ON |
| `Expose primary keys` | needed for stable feature IDs / WFS-T |
| `preparedStatements` | ON — performance + injection resistance |
| connection pool: `max connections`, `min`, `validate connections`, `Test while idle` | tune for concurrency ([[13 — Production and Ops]]) |

### What GeoServer sees

- Every **table/view with a geometry column** → a publishable feature type.
- **SQL views** — Layer config → *Create SQL view*: publish a hand-written
  query, optionally with `%param%` placeholders validated by regex. Great for
  joins, filtered subsets, computed columns — without touching the DB schema.
- Geometry metadata comes from PostGIS's `geometry_columns` view / typmod.

## File-based stores

| Format | Use | Notes |
|---|---|---|
| **GeoPackage** (`.gpkg`) | static vector *and* raster reference data | one SQLite file, modern, indexed — the good file format |
| **GeoTIFF** | single raster | use **Cloud-Optimized GeoTIFF** + internal overviews for big ones |
| **ImageMosaic** | many rasters as one coverage (tiles, time series) | index shapefile/db of footprints |
| **Shapefile** | legacy interchange only | 2 GB limit, 10-char field names, no nulls, `.dbf` encoding pain — don't build on it |
| **Directory of shapefiles** | a folder → many layers | migration convenience |

## SRS / CRS handling (read this before debugging "my data moved")

Each layer has:

- **Native SRS** — what the data actually is (from PostGIS `srid`, the `.prj`,
  the GeoTIFF header).
- **Declared SRS** — what GeoServer advertises.
- **SRS handling**:
  - *Force declared* — trust your declared code, ignore native (use when native
    is missing/wrong).
  - *Reproject native to declared* — actually transform.
  - *Keep native* — pass through.

AIXM data is **WGS 84 lon/lat = EPSG:4326** (`urn:ogc:def:crs:EPSG::4326` uses
lat/lon **axis order** — a classic source of swapped coordinates; set
`-Dorg.geotools.referencing.forceXY=true` unless you specifically need URN
axis order). See [[20 — GIS]] and [[03 — QGIS and the Data Source Manager|QGIS 03]].

## Cascading another service

Stores → **WMS** or **WMTS**: GeoServer becomes a client of a remote OGC
service and re-publishes its layers as your own — useful to put a consistent
security/caching layer in front of a third-party feed.

## Sources

- GeoServer — *Working with PostGIS*: <https://docs.geoserver.org/latest/en/user/data/database/postgis.html>
- GeoServer — *SQL Views*: <https://docs.geoserver.org/latest/en/user/data/database/sqlview.html>
- GeoServer — *GeoPackage*: <https://docs.geoserver.org/latest/en/user/data/vector/geopkg.html>
- GeoServer — *Coverage stores*: <https://docs.geoserver.org/latest/en/user/data/raster/index.html>
- PostGIS manual: <https://postgis.net/documentation/>
