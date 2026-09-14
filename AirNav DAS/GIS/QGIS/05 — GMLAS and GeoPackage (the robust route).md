---
tags:
  - aixm-gis
  - qgis
  - aixm
  - gdal
created: 2026-09-07
---

# 05 — GMLAS and GeoPackage (the robust route)

> [!abstract] The 30-second version
> The **GMLAS** driver ("GML, Application-Schema driven") reads the AIXM **XSD
> schemas** and reproduces the data faithfully as a **set of related tables** —
> nothing flattened away, references preserved. Heavier and more verbose than
> the plain GML driver, but the right tool when you need *all* the data, not
> just a map.

## GML driver vs GMLAS driver

| | **GML** ([[04 — Load AIXM into QGIS (GML driver)]]) | **GMLAS** (this note) |
|---|---|---|
| Needs the XSD schema? | no (guesses structure, writes `.gfs`) | **yes** — reads the real schema |
| Output shape | one layer per feature type, nesting flattened | many tables: features **+** child tables **+** junction tables, mirroring the schema |
| Attribute fidelity | lossy for nested/repeating properties | faithful |
| Geometry | ready to map | present, but spread across the relational structure |
| Best for | **looking at / mapping** AIXM | **extracting, transforming, validating, round-tripping** AIXM |
| Speed & size | fast, small | slower, large (hundreds of tables) |

Rule of thumb: **map with GML, engineer with GMLAS.**

## Connection string

Prefix the path with **`GMLAS:`** —

```
GMLAS:/home/aw16/Documents/airnav/AirNav DAS/GIS/QGIS/sample-data/EA_AIP_DS_FULL_20170701.xml
```

> [!warning] Omit the prefix and you get the wrong driver
> `ogrinfo file.xml` → GML driver. `ogrinfo GMLAS:file.xml` → GMLAS driver.
> In QGIS, paste the whole `GMLAS:…` string into the *Vector Dataset(s)* box of
> the Data Source Manager (don't use Browse).

## Schemas download themselves

GMLAS reads the `schemaLocation` in the file
(`http://www.aixm.aero/schema/5.1.1/...`), **fetches the XSDs over the
internet**, and caches them in:

```
~/.gdal/gmlas_xsd_cache/
```

So the **first run needs a network connection**; later runs are offline. To
force a refresh: open option `REFRESH_CACHE=YES`. To supply schemas yourself
(air-gapped machine): `-oo XSD=/path/to/AIXM_Features.xsd`.

## Look at the structure

```
flatpak run --command=ogrinfo org.qgis.qgis -so \
  "GMLAS:sample-data/EA_AIP_DS_FULL_20170701.xml"
```

You'll see tables like `airspace`, `airspace_geometrycomponent`,
`navaid`, `navaid_timeslice`, plus ISO-19139 metadata tables
(`ci_citation`, `ci_responsibleparty`…) and the message tables
(`aixmbasicmessage`, `aixmbasicmessage_hasmember`). It is a lot — that's the
point.

### Key open options

| Option | Default | Why you'd change it |
|---|---|---|
| `EXPOSE_METADATA_LAYERS=YES` | NO | adds `_ogr_layers_metadata`, `_ogr_fields_metadata`, `_ogr_layer_relationships` — needed for a lossless round-trip back to XML |
| `VALIDATE=YES` | NO | check the file against the schema while reading |
| `FAIL_IF_VALIDATION_ERROR=YES` | NO | stop on the first schema violation (otherwise validation only warns) |
| `SWAP_COORDINATES=AUTO\|YES\|NO` | AUTO | force lat/long axis order if a dataset gets it wrong |
| `REMOVE_UNUSED_LAYERS=YES` / `REMOVE_UNUSED_FIELDS=YES` | NO | drop the empty tables/columns AIXM's huge schema generates — makes the output far more manageable |
| `CONFIG_FILE=…` | built-in `gmlasconf.xml` | fine-tune schema resolution, caching, `xlink:href` handling |

## Convert to a database

The recommended workflow (from the GDAL docs) is **GMLAS → SpatiaLite/GeoPackage
→ work there**:

```
flatpak run --command=ogr2ogr org.qgis.qgis \
  -f GPKG donlon_gmlas.gpkg \
  "GMLAS:sample-data/EA_AIP_DS_FULL_20170701.xml" \
  -nlt CONVERT_TO_LINEAR \
  -oo REMOVE_UNUSED_LAYERS=YES -oo REMOVE_UNUSED_FIELDS=YES
```

- `-nlt CONVERT_TO_LINEAR` — turn GML arcs/circles into line segments (SQLite
  and GeoPackage store linear geometry more happily).
- add `-oo EXPOSE_METADATA_LAYERS=YES` if you plan to export back to XML later.

Then open `donlon_gmlas.gpkg` in QGIS (**Browser ▸ double-click**), or explore
it with **DB Manager** (*Database ▸ DB Manager*) where you can run SQL joins
across the feature and child tables.

## Round-trip back to AIXM

Because GMLAS is schema-driven it can also **write** XML — edit features in the
database, then:

```
flatpak run --command=ogr2ogr org.qgis.qgis \
  -f GMLAS out.xml donlon_gmlas.gpkg
```

The metadata layers (from `EXPOSE_METADATA_LAYERS=YES`) let it rebuild the
structure without re-specifying schemas. Note the docs' caveat: the writer
doesn't *guarantee* full schema-constraint compliance — validate the output.

## How GMLAS maps XML to tables

| XML construct | Becomes |
|---|---|
| a top-level element | a **layer/table** |
| a simple attribute or child element | a **field** |
| a complex child, max one occurrence | **flattened** into the parent table |
| a complex child, repeating | a **separate table**, linked by parent id (or a junction table for many-to-many) |
| `xlink:href` reference | a text field holding the target id |

## Sources

- GDAL — *GMLAS driver* (connection string, open options, schema cache, mapping, round-trip): <https://gdal.org/en/stable/drivers/vector/gmlas.html>
- GDAL — *GMLAS mapping examples*: <https://gdal.org/en/stable/drivers/vector/gmlas_mapping_examples.html>
- GDAL — *GMLAS metadata layers*: <https://gdal.org/en/stable/drivers/vector/gmlas_metadata_layers.html>
- QGIS User Manual — *DB Manager*: <https://docs.qgis.org/3.44/en/docs/user_manual/plugins/core_plugins/plugins_db_manager.html>
