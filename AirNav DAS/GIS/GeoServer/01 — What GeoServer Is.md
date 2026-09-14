---
tags:
  - gis
  - geoserver
created: 2026-09-09
---

# 01 — What GeoServer Is

> [!abstract] The 30-second version
> **GeoServer** is an open-source **Java web application** that publishes
> geospatial data as **standard OGC web services**. You point it at data
> (PostGIS, files), configure *layers* and *styles* through a web admin console
> or a REST API, and clients then request maps (**WMS**), raw features
> (**WFS**), rasters (**WCS**) or tiles (**WMTS**) over HTTP. It is
> **stateless config over a data store** — it stores almost nothing itself.

## What it does, precisely

| Client asks for… | Service | GeoServer returns |
|---|---|---|
| a rendered map image | **WMS** GetMap | a PNG/JPEG of the styled data for a bbox |
| the actual geometry + attributes | **WFS** GetFeature | GML / GeoJSON / shapefile of the features |
| raster pixel values | **WCS** GetCoverage | a GeoTIFF subset |
| pre-rendered map tiles | **WMTS** / GeoWebCache | 256×256 tiles, cached |
| a modern REST/JSON feed | **OGC API – Features / Tiles / Maps** | JSON collections, links, tiles |
| "what's here?" | **WMS** GetFeatureInfo | attributes at a clicked pixel |

It also does **on-the-fly reprojection**, **filtering** (CQL / OGC Filter),
**rendering transformations** (heatmaps, contours), and **WFS-T** (writing
features back to the store).

## The stack it sits on

```
        HTTP request (WMS/WFS/OGC API …)
                  │
        ┌─────────▼──────────┐
        │  GeoServer          │  services, admin UI, REST, security
        ├─────────────────────┤
        │  GeoTools            │  the Java GIS engine: data stores, rendering,
        │                     │  referencing (CRS), filtering, GML/SLD
        ├─────────────────────┤
        │  GeoWebCache (GWC)   │  tile cache, bundled and integrated
        ├─────────────────────┤
        │  Servlet container   │  Tomcat / Jetty  →  a JVM
        └─────────────────────┘
                  │ reads
        ┌─────────▼──────────┐
        │  PostGIS · GeoTIFF · GeoPackage · shapefile · cascaded WMS/WFS │
        └────────────────────┘
```

- **GeoTools** does the real work — every data format, CRS transform, filter
  and SLD symbolizer is GeoTools. Most GeoServer CVEs are actually GeoTools
  bugs (see [[12 — Hardening and the CVE Track]]).
- **GeoWebCache** is built in — it intercepts tiled requests and serves cached
  tiles ([[07 — GeoWebCache]]).
- The **data directory** (`GEOSERVER_DATA_DIR`) holds *all* configuration as
  XML files plus the styles — it is the entire state of the server and the
  unit of backup ([[02 — Install and Run]]).

## The request lifecycle (why this matters for security)

```
HTTP → dispatcher → service (WMS/WFS/…) → security filter chain
     → GeoTools data store → SLD render / GML encode → response
```

Any OGC operation that takes a **property name**, a **filter**, or a
**style/SLD** is passing user input into GeoTools evaluation code. That is
exactly the surface that **CVE-2024-36401** (RCE via property-name XPath eval)
abused — through WFS GetFeature, WMS GetMap, WMS GetLegendGraphic and WPS
Execute. Keep that map in mind: **every enabled service widens the attack
surface.**

## Where it sits vs the alternatives

| Tool | Role |
|---|---|
| **GeoServer** | full OGC service engine + admin UI + REST + security + app-schema; best for a standalone service component in a larger stack |
| **QGIS Server** | serves a QGIS *project* file directly (same renderer as the desktop → WYSIWYG); great if the team already lives in QGIS |
| **MapServer** | C, config-file driven, very fast, lighter; no admin UI |
| **PostGIS** | the database underneath — not a web service by itself |
| **pygeoapi / ldproxy** | lightweight OGC API – Features servers |

Your team chose GeoServer — the reason is almost always **app-schema** (complex
features / AIXM) plus the admin UI and REST, which the lighter tools don't do.

## Jargon buster

| Term | Meaning |
|---|---|
| OGC | Open Geospatial Consortium — writes the WMS/WFS/… standards |
| WMS / WFS / WCS / WMTS | Web Map / Feature / Coverage / Map Tile Service |
| OGC API | the modern JSON+REST successors to the WxS services |
| Capabilities | the XML/JSON document listing what a service offers |
| GeoTools | the Java library GeoServer is built on |
| GWC | GeoWebCache — the tile cache |
| Data directory | `GEOSERVER_DATA_DIR` — all config + styles, as files |
| Coverage | GeoServer's word for raster data |
| Cascading | GeoServer re-serving another remote WMS/WFS as its own |

## Sources

- GeoServer — *Introduction* / *Overview*: <https://docs.geoserver.org/latest/en/user/introduction/overview.html>
- GeoTools: <https://geotools.org>
- OGC standards: <https://www.ogc.org/standards/>
