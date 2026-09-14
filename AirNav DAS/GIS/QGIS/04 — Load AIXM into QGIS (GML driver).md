---
tags:
  - aixm-gis
  - qgis
  - aixm
created: 2026-09-07
---

# 04 — Load AIXM into QGIS (GML driver)

> [!abstract] The 30-second version
> Point QGIS at a bare AIXM `.xml` and its **GML driver** turns it into **one
> layer per feature type** — `Airspace`, `Navaid`, `AirportHeliport`,
> `RouteSegment`, and so on. This is the fast route and it's enough for
> mapping. GDAL calls its AIXM handling *"partial"* — good for geometry,
> awkward for deeply nested attributes.

## Route A — just look (30 seconds)

`sample-data/donlon.gpkg` is already built. **Data Source Manager ▸ Vector ▸
Database** isn't even needed — drag `donlon.gpkg` from the **Browser** onto the
map, or **Layer ▸ Add Layer ▸ Add Vector Layer**, pick the file, tick the
layers. Skip to [[06 — Exercise — Donlon airspace map]] if you only want to
practise cartography.

## Route B — load the AIXM file yourself

1. **`Ctrl+L`** → **Vector** tab → **File**.
2. Browse to `sample-data/EA_AIP_DS_FULL_20170701.xml` — **set the filter to
   "All files"** so the `.xml` shows.
3. **Add**. In **Select Items to Add**, use the **Feature count** column to
   pick the layers with data. Tick **Add layers to a group**. **Add**, then
   **Close**.

### What you get (Donlon sample)

| Layer | Geometry | ~count |
|---|---|---|
| `Airspace` | polygons | 20 |
| `Navaid` | point | 14 |
| `VOR` / `DME` / `NDB` / `TACAN` / `MarkerBeacon` | point | 7 / 7 / … |
| `Localizer` / `Glidepath` | point | ILS components |
| `AirportHeliport` | point | a handful |
| `Runway` / `RunwayDirection` / `RunwayCentrelinePoint` | (mixed) | |
| `RouteSegment` | line | 22 |
| `DesignatedPoint` | point | 14 |
| `GeoBorder` | line | |
| `HoldingPattern` / `TouchDownLiftOff` / `AeronauticalGroundLight` | point / polygon / point | |
| `OrganisationAuthority`, `Unit`, `AirTrafficControlService`, `RadioCommunicationChannel`, `Route`, … | no geometry | attribute-only — open the **Attribute Table**, don't expect them on the map |

QGIS/GDAL also drops a **`.gfs`** file next to the `.xml` — a cache of the
structure it discovered. Keep it (loads are faster next time); delete it to
force a fresh scan after editing the XML.

## The two rough edges

### 1 · Geometry warnings

AIXM samples often contain rings that aren't perfectly closed or curved
segments GDAL can't resolve. You'll see:

```
Warning 1: Non closed ring detected...
ERROR 1: GML geometry id='S002': Invalid exterior ring
```

The layer still loads; a few features may be missing geometry. To be more
tolerant, set the GDAL config option **`OGR_GEOMETRY_ACCEPT_UNCLOSED_RING=YES`**
before loading:

- **In QGIS:** *Settings ▸ Options ▸ Advanced* → add the setting under
  `gdal/config`, **or** launch QGIS from a terminal with it set:
  ```
  OGR_GEOMETRY_ACCEPT_UNCLOSED_RING=YES flatpak run org.qgis.qgis
  ```
- **On the command line:** `--config OGR_GEOMETRY_ACCEPT_UNCLOSED_RING YES`

### 2 · Nested attributes

Simple properties (`name`, `type`, `frequency`, `designator`) become clean
columns. Repeating or deeply nested ones (notes, schedules, vertical limits
with their units and references) come through as:

- long `|`-joined column names like
  `timeSlice|AirspaceTimeSlice|geometryComponent|…|upperLimit`, and
- **`StringList`** values (semicolon-packed lists).

Readable, but not nice to work with. When that starts to hurt, switch to
[[05 — GMLAS and GeoPackage (the robust route)]].

## Make it permanent: convert to GeoPackage

Don't keep re-reading the XML. Convert once to a **GeoPackage** (`.gpkg`) — a
single-file spatial database QGIS loves:

```
flatpak run --command=ogr2ogr org.qgis.qgis \
  -f GPKG donlon.gpkg EA_AIP_DS_FULL_20170701.xml -skipfailures
```

- `-f GPKG` — output format.
- `-skipfailures` — keep going past the bad-geometry features.
- add `-nlt PROMOTE_TO_MULTI` if a layer mixes single and multi geometries.
- `StringList` columns are auto-converted to JSON text (a warning says so) —
  fine.

This is exactly how `sample-data/donlon.gpkg` was made. Full flag reference:
[[07 — Command and option reference]].

## Check without QGIS

`ogrinfo` is the quickest way to see what's in a file:

```
# list layers + geometry types + feature counts
flatpak run --command=ogrinfo org.qgis.qgis -so -al EA_AIP_DS_FULL_20170701.xml

# dump one layer in full
flatpak run --command=ogrinfo org.qgis.qgis EA_AIP_DS_FULL_20170701.xml VOR
```

## Sources

- GDAL — *GML driver* ("partial support for reading AIXM", `.gfs`, `SWAP_COORDINATES`): <https://gdal.org/en/stable/drivers/vector/gml.html>
- GDAL — *ogr2ogr*: <https://gdal.org/en/stable/programs/ogr2ogr.html>
- GDAL — *ogrinfo*: <https://gdal.org/en/stable/programs/ogrinfo.html>
- GDAL — configuration options (`OGR_GEOMETRY_ACCEPT_UNCLOSED_RING`): <https://gdal.org/en/stable/user/configoptions.html>
- QGIS User Manual — *Opening Data*: <https://docs.qgis.org/3.44/en/docs/user_manual/managing_data_source/opening_data.html>
