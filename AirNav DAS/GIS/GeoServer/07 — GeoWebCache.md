---
tags:
  - gis
  - geoserver
  - performance
created: 2026-09-09
---

# 07 — GeoWebCache

> [!abstract] The 30-second version
> **GeoWebCache (GWC)** is a tile cache bundled inside GeoServer. Instead of
> re-rendering a map on every request, it cuts the world into a fixed pyramid
> of **256×256 tiles** per zoom level, renders each **once**, and serves the
> stored image after that. It turns a slow WMS into a fast slippy map. You
> reach it via **WMTS**, **TMS**, or `WMS?tiled=true`.

## Why tiling changes performance

| Plain WMS `GetMap` | Tiled (GWC) |
|---|---|
| arbitrary bbox / size → render every time | fixed grid → render once, then disk read |
| CPU-bound, scales badly under load | I/O-bound, scales well |
| great for one-off / analytic queries | great for basemaps, dashboards, many users |

## Core concepts

| Term | Meaning |
|---|---|
| **Gridset** | the tiling scheme: a CRS, an origin, and a list of resolutions (zoom levels). Built-ins: `EPSG:4326`, `EPSG:900913`/`EPSG:3857` (web mercator). Define custom ones for other CRSs. |
| **Tile matrix** | one zoom level of a gridset |
| **Blob store** | where tiles are kept — file system (default, under `<data_dir>/gwc`), or S3 |
| **Seeding** | pre-generating tiles for an area/zoom range, ahead of demand |
| **Truncating** | deleting cached tiles (after the data or style changes) |
| **Metatiling** | render a 4×4 block at once, slice into tiles — avoids label clipping at tile edges |

## Integrated vs standalone

- **Integrated** (default): GWC lives in GeoServer, configured under
  *Tile Caching* in the admin UI, per-layer *Tile Caching* tab. This is what
  you use.
- **Standalone** GeoWebCache is a separate webapp — only for large dedicated
  caching tiers.

## Per-layer setup (admin UI → layer → *Tile Caching*)

- **Create a cached layer** for it; pick the **gridsets** and **image formats**
  (`image/png`, `image/jpeg`, `image/png8`).
- **Enabled cached styles** — each style you want tileable.
- **Metatiling factor** (4×4 typical), **gutter** (px) to fix edge artefacts.
- **Expire** rules (server + client cache headers).
- **In-memory** tile cache (Caffeine/Guava) on top of the blob store.

## Seeding and truncating

*Tile Caching → Tile Layers → Seed/Truncate*, or the REST API:

```
# seed zoom 0–6 for a bbox
curl -u admin:*** -XPOST -H 'Content-type: application/json' \
  -d '{"seedRequest":{"name":"aixm:Airspace","gridSetId":"EPSG:4326",
       "zoomStart":0,"zoomStop":6,"type":"seed","threadCount":4}}' \
  http://host/geoserver/gwc/rest/seed/aixm:Airspace.json
```

> [!warning] Truncate after every change
> Cached tiles are **stale** the moment the data or the style changes. Wire a
> truncate into your data-load / style-deploy process, or you serve
> yesterday's airspace.

## Disk quota

*Tile Caching → Disk Quota*: cap total cache size, choose an eviction policy
(LFU / LRU). Without it, a public WMTS can fill the disk.

## When *not* to cache

- Data that changes often relative to how often it's viewed (a live
  **[[15 — NOTAMs|NOTAM]]** / TEMPDELTA feed).
- Layers queried with arbitrary `CQL_FILTER` — the cache key is the tile, not
  the filter, so filtered + tiled = wrong results unless you cache per-style.

## Sources

- GeoServer — *Tile Caching (GeoWebCache)*: <https://docs.geoserver.org/latest/en/user/geowebcache/index.html>
- GeoWebCache project docs: <https://www.geowebcache.org/docs/current/>
- GeoServer — *GWC REST API*: <https://docs.geoserver.org/latest/en/user/geowebcache/rest/index.html>
