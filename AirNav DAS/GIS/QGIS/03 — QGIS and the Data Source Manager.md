---
tags:
  - aixm-gis
  - qgis
created: 2026-09-07
---

# 03 — QGIS and the Data Source Manager

> [!abstract] The 30-second version
> **All data loading in QGIS goes through the Data Source Manager** (`Ctrl+L`).
> For AIXM you use its **Vector** tab. Set the **project CRS to `EPSG:4326`**
> (or leave QGIS to reproject on the fly) and AIXM's lat/long coordinates land
> in the right place.

## Launch and layout

Start QGIS: application menu → **QGIS Desktop**, or a terminal:

```
flatpak run org.qgis.qgis
```

The panels you need:

| Panel | Use |
|---|---|
| **Browser** (left) | a file-tree; double-click or drag a layer onto the map |
| **Layers** (left) | the layers currently in your project; order = draw order |
| **map canvas** (centre) | the map |
| status bar (bottom-right) | current **coordinate**, **scale**, and **project CRS** button |

If a panel is missing: **View ▸ Panels ▸** tick it.

## The Data Source Manager

Open it any of these ways:

- toolbar button **Open Data Source Manager**
- **`Ctrl+L`**
- menu **Layer ▸ Add Layer ▸ Add Vector Layer…** (jumps straight to the Vector tab)

It's one dialog with a tab per data type down the left. **Vector** is the one
for AIXM (shortcut **`Ctrl+Shift+V`**).

### The Vector tab

Pick a **Source type** (radio buttons across the top):

| Source type | When |
|---|---|
| **File** | a local file — **this is the one for AIXM** |
| **Directory** | folder-based formats (not AIXM) |
| **Database** | PostGIS, GeoPackage, SpatiaLite… (use this for `donlon.gpkg`) |
| **Protocol: HTTP(S), cloud, etc.** | data at a URL or in object storage |
| **OGC API** | live OGC API – Features / Maps servers |

Then, for **File**:

1. Click the **… (Browse)** button next to *Vector Dataset(s)*.
2. Select the file. **Set the file-type filter to "All files"** — AIXM's `.xml`
   is not in the default vector filter list.
3. **Open**, then **Add**. (You can also just paste a full OGR string like
   `GMLAS:/path/file.xml` into the *Vector Dataset(s)* box — see
   [[05 — GMLAS and GeoPackage (the robust route)]].)
4. **Close** the dialog.

### The "Select Items to Add" dialog

An AIXM file contains **many feature types**, so QGIS shows a list and asks
which to load. Options in that dialog:

- tick the layers you want (e.g. `Airspace`, `Navaid`, `AirportHeliport`,
  `RouteSegment`) — or **Select All**;
- **Add layers to a group** — keeps them tidy under one heading;
- **Show system and internal tables** — leave off for AIXM;
- a **Feature count** column tells you which layers actually hold data.

## Coordinate reference system (CRS)

AIXM geometry is **WGS 84 latitude/longitude** — EPSG code **`4326`** (often
written `CRS:84` / `OGC:CRS84`). QGIS reads the `srsName` from the file, so
each layer arrives already tagged with WGS 84 and the axis order handled.

Two things to set once per project:

| Setting | Where | Recommendation |
|---|---|---|
| **Project CRS** | status-bar CRS button, or **Project ▸ Properties ▸ CRS** | `EPSG:4326` to start; any projected CRS later for accurate distances/areas |
| **On-the-fly reprojection** | always on in QGIS 3+/4 | nothing to do — layers in other CRSs are drawn to match the project |

> [!tip] Sanity check
> After loading, right-click a navaid layer ▸ **Zoom to Layer**. Donlon should
> land in the Atlantic between roughly 40–57° N and 20–42° W. If points sit off
> the coast of Africa at 0° / 0°, the geometry didn't parse — check you loaded
> the right layer and used "All files".

## Sources

- QGIS User Manual — *Opening Data* (Data Source Manager, Vector tab, Browser): <https://docs.qgis.org/3.44/en/docs/user_manual/managing_data_source/opening_data.html>
- QGIS User Manual — *Working with Projections*: <https://docs.qgis.org/3.44/en/docs/user_manual/working_with_projections/working_with_projections.html>
