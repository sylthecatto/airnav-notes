---
tags:
  - aixm-gis
  - gdal
  - reference
created: 2026-09-07
---

# 07 — Command and option reference

> [!abstract] What this is
> Copy-paste reference for the `ogrinfo` / `ogr2ogr` commands and OGR options
> used across this folder, with the official doc page for each. QGIS bundles
> these — call them through the Flatpak.

All commands assume you're in `GIS/QGIS/sample-data/`. Prefix with:

```
flatpak run --command=ogrinfo  org.qgis.qgis   # for ogrinfo
flatpak run --command=ogr2ogr  org.qgis.qgis   # for ogr2ogr
```

(or drop the prefix if you have a system GDAL: `dnf install gdal` on the host.)

## Inspecting

| Task | Command |
|---|---|
| GDAL version | `ogrinfo --version` |
| Is the AIXM driver present? | `ogrinfo --formats \| grep -i -E 'aixm\|gml'` → expect **GML** and **GMLAS**, no dedicated AIXM |
| List layers (GML driver) | `ogrinfo -so -al EA_AIP_DS_FULL_20170701.xml` |
| List layers (GMLAS driver) | `ogrinfo -so "GMLAS:EA_AIP_DS_FULL_20170701.xml"` |
| One layer, summary only | `ogrinfo -so EA_AIP_DS_FULL_20170701.xml Airspace` |
| One layer, full dump | `ogrinfo EA_AIP_DS_FULL_20170701.xml VOR` |
| Run SQL | `ogrinfo -sql "SELECT designator,name,type FROM Navaid" donlon.gpkg` |
| GMLAS metadata layer | `ogrinfo "GMLAS:EA_AIP_DS_FULL_20170701.xml" _ogr_layers_metadata -oo EXPOSE_METADATA_LAYERS=YES` |

## Converting

**AIXM → GeoPackage, via the GML driver** (fast, for mapping):

```
ogr2ogr -f GPKG donlon.gpkg EA_AIP_DS_FULL_20170701.xml -skipfailures
```

**AIXM → GeoPackage, via GMLAS** (faithful, for data work):

```
ogr2ogr -f GPKG donlon_gmlas.gpkg "GMLAS:EA_AIP_DS_FULL_20170701.xml" \
  -nlt CONVERT_TO_LINEAR \
  -oo REMOVE_UNUSED_LAYERS=YES -oo REMOVE_UNUSED_FIELDS=YES
```

**One feature type only:**

```
ogr2ogr -f GPKG airspace_only.gpkg EA_AIP_DS_FULL_20170701.xml Airspace
```

**GeoPackage → GeoJSON (for a web map, one layer):**

```
ogr2ogr -f GeoJSON airspace.geojson donlon.gpkg Airspace -t_srs EPSG:4326
```

**GMLAS database → back to AIXM XML:**

```
ogr2ogr -f GMLAS out.xml donlon_gmlas.gpkg
```

## Flags used above

| Flag | Effect | Doc |
|---|---|---|
| `-f <FORMAT>` | output driver (`GPKG`, `GeoJSON`, `GMLAS`, `SQLite`…) | ogr2ogr |
| `-skipfailures` | keep going past features that fail (bad geometry) | ogr2ogr |
| `-nlt CONVERT_TO_LINEAR` | approximate GML arcs/circles as line segments | ogr2ogr |
| `-nlt PROMOTE_TO_MULTI` | force MultiPolygon/MultiLineString when a layer mixes single + multi | ogr2ogr |
| `-t_srs EPSG:4326` | reproject output to this CRS | ogr2ogr |
| `-sql "<query>"` | select/transform with OGR SQL | ogr2ogr / ogrinfo |
| `-so` / `-al` | summary only / all layers | ogrinfo |
| `-if GMLAS` | force the input driver (GDAL ≥ 3.10) | ogr2ogr |

## Open options (`-oo`) — GMLAS

| Option | Values (default) | Purpose |
|---|---|---|
| `XSD=<path\|url>` | – | supply schemas explicitly (comma-separate several) |
| `CONFIG_FILE=<file>` | built-in `gmlasconf.xml` | tune schema resolution / caching / xlink handling |
| `EXPOSE_METADATA_LAYERS=YES/NO` | NO | add `_ogr_*_metadata` tables (needed for round-trip) |
| `VALIDATE=YES/NO` | NO | validate against the schema while reading |
| `FAIL_IF_VALIDATION_ERROR=YES/NO` | NO | make validation errors fatal |
| `SWAP_COORDINATES=AUTO/YES/NO` | AUTO | axis order (lat/long vs long/lat) |
| `REFRESH_CACHE=YES/NO` | NO | re-download cached schemas |
| `REMOVE_UNUSED_LAYERS=YES/NO` | NO | drop empty tables the big schema generates |
| `REMOVE_UNUSED_FIELDS=YES/NO` | NO | drop empty columns |

Schema cache location: **`~/.gdal/gmlas_xsd_cache/`**.

## Config options (`--config`) — GML driver

| Option | Values | Purpose |
|---|---|---|
| `OGR_GEOMETRY_ACCEPT_UNCLOSED_RING` | YES/**NO** | tolerate rings that aren't perfectly closed (common in AIXM samples) |
| `GML_SKIP_RESOLVE_ELEMS` | ALL/NONE/HUGE… | control xlink resolution on big files |
| `GML_ATTRIBUTES_TO_OGR_FIELDS` | YES/NO | expose XML attributes (not just elements) as fields |

Example:

```
ogr2ogr --config OGR_GEOMETRY_ACCEPT_UNCLOSED_RING YES \
  -f GPKG donlon.gpkg EA_AIP_DS_FULL_20170701.xml -skipfailures
```

## The `.gfs` sidecar

The GML driver writes `<name>.gfs` next to the source `.xml` — an XML file
recording the layers/fields/geometry it discovered. Faster reloads; **delete it
to force a re-scan** after editing the source.

## Sources

- GDAL — *ogr2ogr*: <https://gdal.org/en/stable/programs/ogr2ogr.html>
- GDAL — *ogrinfo*: <https://gdal.org/en/stable/programs/ogrinfo.html>
- GDAL — *GML driver*: <https://gdal.org/en/stable/drivers/vector/gml.html>
- GDAL — *GMLAS driver*: <https://gdal.org/en/stable/drivers/vector/gmlas.html>
- GDAL — *Configuration options*: <https://gdal.org/en/stable/user/configoptions.html>
- GDAL — *OGR SQL dialect*: <https://gdal.org/en/stable/user/ogr_sql_dialect.html>
