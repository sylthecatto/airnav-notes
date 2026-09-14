---
tags:
  - gis
  - geoserver
created: 2026-09-09
---

# 03 — The Data Model

> [!abstract] The 30-second version
> Four nested things: a **Workspace** is a namespace; a **Store** is a
> connection to one data source; a **Layer** (a.k.a. resource + published
> layer) is one feature type or coverage from that store, made public; a
> **Style** says how to draw it. Plus **Layer Groups** to bundle layers into
> one WMS layer. Learn this tree and the admin UI stops being confusing.

## The tree

```
Workspace  (namespace + URI, e.g.  aixm  →  http://www.aixm.aero/schema/5.1.1)
└── Store  (a connection: "PostGIS on db01", "the GeoTIFF folder")
    └── Resource + Layer  (one feature type / coverage, published)
        └── default Style  (+ additional styles the client can pick)

Layer Group  (an ordered set of layers, served as one WMS layer,
              optionally with its own bounds, CRS, and mode)
```

## Each level, and what you set on it

### Workspace

- A **name** and a **namespace URI**. The URI matters for **WFS/GML output** —
  it becomes the XML namespace of the features (`aixm:AirportHeliport`).
- One workspace can be the **default** (used when a request omits the prefix).
- Services (WMS/WFS/…) and security rules can be scoped **per workspace** —
  "virtual services": `/geoserver/aixm/wms` only sees the `aixm` workspace.
- Settings (contact info, service metadata) can be overridden per workspace.

### Store

One store = one data source connection. Types:

| Category | Examples |
|---|---|
| **Vector** (`DataStore`) | PostGIS, GeoPackage, Shapefile, Oracle, SQL Server, Directory of shapefiles, **App-Schema**, WFS (cascade) |
| **Raster** (`CoverageStore`) | GeoTIFF, ImageMosaic, ImagePyramid, WorldImage, NetCDF |
| **Cascaded** | WMS, WMTS — GeoServer re-serves a remote service as its own |

A PostGIS store holds connection params (host, db, user, schema) and a
connection **pool**. See [[04 — Connecting Data]].

### Resource / Layer

Publishing a layer from a store lets you set:

- **Name** and **title/abstract** (shown in Capabilities).
- **Declared SRS** + **SRS handling** (force / reproject / keep native) — the
  #1 cause of "my data is in the ocean".
- **Bounding boxes** — native + lat/lon; click *Compute from data*.
- **Attributes** — which to expose, feature-type details.
- **Publishing** tab — which **services** expose this layer, default & extra
  **styles**, WMS settings, **WFS** per-layer settings, **tile caching**.
- A **SQL view** (PostGIS) — publish a parametrised query as a layer.

### Style

- An **SLD** (or CSS/YSLD/MBStyle) file plus `.xml` metadata.
- Can be **global** or scoped to a workspace.
- A layer has one **default** style and any number of **alternate** styles a
  client selects with `&styles=`. See [[06 — Styling — SLD and CSS]].

### Layer Group

- An ordered list of layers (+ their styles) served as **one** WMS layer.
- Modes: *single* (opaque group), *named tree*, *container tree*, *Earth
  Observation*. "Single" is what you want for a basemap-style bundle.
- Its own bounds and CRS; can be nested.

## Where it all lives

Every one of these is an XML file under
`<data_dir>/workspaces/<ws>/<store>/<layer>/…` and `<data_dir>/styles/`. You
can edit them by hand, template them, or drive them via the
[[10 — REST API and Config-as-Code|REST API]] — the UI is just one front-end
to the same files.

## Sources

- GeoServer — *Web Admin: Data*: <https://docs.geoserver.org/latest/en/user/data/webadmin/index.html>
- GeoServer — *Layer Groups*: <https://docs.geoserver.org/latest/en/user/data/webadmin/layergroups.html>
- GeoServer — *Virtual Services*: <https://docs.geoserver.org/latest/en/user/services/virtual-services.html>
