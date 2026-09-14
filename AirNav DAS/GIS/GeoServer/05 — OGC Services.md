---
tags:
  - gis
  - geoserver
  - ogc
created: 2026-09-09
---

# 05 — OGC Services

> [!abstract] The 30-second version
> GeoServer speaks a family of HTTP APIs defined by the **OGC**. The classic
> "WxS" set — **WMS** (map pictures), **WFS** (raw features), **WCS**
> (rasters), **WMTS** (tiles) — uses `GET`/`POST` with `request=` parameters
> and returns XML/images. The newer **OGC API** set is REST + JSON. Every
> service publishes a **Capabilities** document listing what it offers. Each
> operation that takes a filter, property name or style is attack surface —
> keep that in view ([[12 — Hardening and the CVE Track]]).

## The service family

| Service | Versions GeoServer speaks | Returns | You'd use it to… |
|---|---|---|---|
| **WMS** | 1.1.1, 1.3.0 | map images, legends | draw a styled map in a browser/QGIS |
| **WFS** | 1.0, 1.1, **2.0** | GML / GeoJSON / CSV / shapefile | pull the actual geometry + attributes (and, with **WFS-T**, edit them) |
| **WCS** | 1.0, 1.1, **2.0** | GeoTIFF and other coverages | grab a raster subset / band |
| **WMTS** | 1.0 | tiles (via GeoWebCache) | fast slippy-map tiles ([[07 — GeoWebCache]]) |
| **WPS** | 1.0 (extension) | process results | run server-side geoprocessing — **high risk, usually disable** |
| **OGC API – Features / Tiles / Maps / Styles** | current | JSON, links | the modern REST equivalent of WFS/WMTS/WMS |

## WMS — the operations

| Operation | What it does |
|---|---|
| `GetCapabilities` | the catalogue: layers, styles, CRSs, bbox, formats |
| `GetMap` | render `layers=` + `styles=` for `bbox` / `width` / `height` / `crs` → image |
| `GetFeatureInfo` | attributes at pixel `i,j` — "identify" |
| `GetLegendGraphic` | a legend swatch for a layer+style |
| `DescribeLayer` | (SLD helper) maps a WMS layer to its WFS/WCS type |

Example:

```
/geoserver/aixm/wms?service=WMS&version=1.3.0&request=GetMap
 &layers=aixm:Airspace&styles=airspace_by_type
 &bbox=-42,-37,54,58&width=1024&height=1024&crs=EPSG:4326&format=image/png
```

Vendor params worth knowing: `CQL_FILTER=`, `SLD_BODY=` / `SLD=`, `env=`
(style variable substitution), `format_options=`, `tiled=true`.

## WFS — the operations

| Operation | What it does |
|---|---|
| `GetCapabilities` | feature types on offer |
| `DescribeFeatureType` | the schema (XSD) of a feature type — for AIXM this is the full app-schema |
| `GetFeature` | return features; supports `count`, `startIndex`, `sortBy`, `srsName`, `propertyName`, `filter` / `CQL_FILTER`, `bbox` |
| `GetPropertyValue` | one property's values (WFS 2.0) |
| `LockFeature` / `Transaction` | locking and **writes** (WFS-T: Insert/Update/Delete) |

```
/geoserver/aixm/ows?service=WFS&version=2.0.0&request=GetFeature
 &typeNames=aixm:Airspace&count=10&outputFormat=application/json
 &CQL_FILTER=type='R'
```

> [!warning] `GetFeature`, `GetPropertyValue`, `GetMap`, `GetLegendGraphic`,
> `WPS Execute` were **all** exploitable paths for CVE-2024-36401 (property
> name → XPath eval → RCE). If you don't need WFS-T, turn it off; if you don't
> need WPS, don't install it.

## Filtering: CQL / ECQL and OGC Filter

- **OGC Filter** — the verbose XML filter language (in `filter=` or a POST
  body).
- **CQL / ECQL** — the compact text form GeoServer accepts in `CQL_FILTER=`:
  `type = 'R' AND upperLimit > 1000 AND BBOX(geom, -42,-37,54,58)`. Learn this
  — it's how you test and subset everything.

## OGC API

The modern face: `/geoserver/ogc/features/v1/collections` → JSON list →
`/collections/aixm:Airspace/items?f=json&limit=10&bbox=…`. Same data, cleaner
for web apps. Being promoted from community → core service by service.

## Service settings you control

Per service (WMS/WFS/…) and optionally **per workspace**:

- **Enabled** on/off; **strict CITE compliance**; **max features**,
  **max rendering time/errors**, **max requested dimensions**.
- WMS: allowed **SRS list**, **watermark**, **decoration** layouts, anti-alias,
  interpolation, `GetFeatureInfo` limits.
- WFS: **service level** (Basic / Transactional / Complete), max features,
  encode `featureMember` vs `featureMembers`, return bounds.

> [!tip] "Service Level = Basic" (WFS) and disabling unused services is the
> first item on the production hardening list — fewer operations, smaller
> surface.

## Sources

- GeoServer — *Services*: <https://docs.geoserver.org/latest/en/user/services/index.html>
- GeoServer — *WMS reference*: <https://docs.geoserver.org/latest/en/user/services/wms/reference.html>
- GeoServer — *WFS reference*: <https://docs.geoserver.org/latest/en/user/services/wfs/reference.html>
- GeoServer — *CQL and ECQL*: <https://docs.geoserver.org/latest/en/user/filter/ecql_reference.html>
- GeoServer — *OGC API*: <https://docs.geoserver.org/latest/en/user/services/ogcapi/index.html>
