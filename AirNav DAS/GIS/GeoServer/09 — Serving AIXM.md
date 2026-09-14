---
tags:
  - gis
  - geoserver
  - aixm
  - app-schema
created: 2026-09-09
---

# 09 — Serving AIXM

> [!abstract] The 30-second version
> AIXM 5.1 / 5.1.1 is a **GML 3.2 application schema**, so GeoServer's
> [[08 — App-Schema and Complex Features|app-schema]] extension can publish it
> as a schema-valid **WFS**. In practice you: load AIXM into **PostGIS** in a
> shape app-schema can map, write (or hale-generate) the **mapping file**,
> pin the **AIXM XSDs locally**, and publish. The hard parts are **temporality**
> (time slices → feature chaining) and **geometry** (AIXM's GML profile).

## The stack

```
AIXM source (.xml datasets, EAD extracts, digital NOTAM)
      │  load / ETL  (GDAL GMLAS, hale, FME, custom)
      ▼
PostGIS  —  tables shaped for mapping (one per feature type + child tables
            for notes, timeslices, geometry components)
      │  app-schema mapping file  (targets AIXM_Features.xsd)
      ▼
GeoServer app-schema store  →  workspace `aixm` (ns http://www.aixm.aero/schema/5.1.1)
      ▼
WFS 2.0  —  aixm:AirportHeliport, aixm:Airspace, aixm:Navaid, aixm:RouteSegment …
```

## Getting AIXM into PostGIS

Options, roughly easiest → most control:

| Tool | Notes |
|---|---|
| **GDAL `ogr2ogr` with GMLAS** | `ogr2ogr -f PostgreSQL PG:"…" GMLAS:dataset.xml` — explodes the message into ~faithful relational tables. Good starting shape. See [[05 — GMLAS and GeoPackage (the robust route)\|QGIS 05]]. |
| **hale studio** | transform source → a PostGIS schema *designed* for the app-schema mapping; exports both sides |
| **FME** | commercial; strong AIXM reader/writer |
| **custom ETL** | full control; most work |

The Donlon sample (`GIS/QGIS/sample-data/EA_AIP_DS_FULL_20170701.xml`) is the
dataset to practise the whole chain on.

## The two hard parts

### 1 · Temporality → feature chaining

Every AIXM feature is a wrapper around one or more **TimeSlices**
(`BASELINE` / `PERMDELTA` / `TEMPDELTA`) each with a `validTime` and
`interpretation` ([[22 — AIXM Temporality Model]]). In the model:

- `aixm:Airspace` (the identity — `gml:identifier` = the UUID) **chains to**
- `aixm:AirspaceTimeSlice` rows (child table, FK to the feature),
- which chain again to geometry components, limits, activations.

So the mapping is: feature table → `isMultiple` chained `*TimeSlice` mapping →
further chained geometry/limit mappings. A WFS client then filters to the slice
valid at its time of interest.

### 2 · Geometry → the AIXM GML profile

AIXM constrains GML geometry to the **OGC GML Profile for Aviation Data
(OGC 12-028r1)**: points, curves (incl. arcs/circles by centre+radius),
surfaces. PostGIS stores plain geometry; the mapping must emit the right AIXM
geometry elements (`aixm:ElevatedPoint`, `aixm:ElevatedSurface`,
`gml:Curve` with `gml:ArcByCenterPoint`, etc.). Arcs/circles are the usual
pain — decide early whether you densify to line segments or preserve arcs.

## Pin the schemas locally

Do **not** let GeoServer fetch `http://www.aixm.aero/schema/5.1.1/...` at
runtime (slow, fragile, and a network dependency). Put the AIXM XSD set on disk
and
point app-schema at it via the schema cache / `OASIS catalog`
(`app-schema.properties` / `oasis-catalog.xml`). Bundle it with your config so
deploys are reproducible.

## Serve it, then check it

- **`DescribeFeatureType`** should return the AIXM schema (or an import of it).
- **`GetFeature`** output should **validate** against `AIXM_Features.xsd` — run
  it through `xmllint --schema` or the EUROCONTROL AIXM validator.
- Cross-check the same features in **QGIS** (WFS connection to your GeoServer)
  and against the source in the [[06 — Exercise — Donlon airspace map|QGIS exercise]].
- Filtering: `CQL_FILTER` over nested paths uses the target XPath, e.g.
  `aixm:AirspaceTimeSlice/aixm:type = 'R'`.

## Where this fits operationally

This is the pattern behind parts of **[[25 — EAD|EAD]]** and **[[26 — SWIM|SWIM]]**
aeronautical information services — a database of record, published as
standards-based services. If your team runs it for a client ANSP, the
GeoServer instance is **operational aeronautical infrastructure**: patch
cadence, availability and integrity all matter, and it's squarely in scope for
[[12 — Hardening and the CVE Track]] and the aviation-cyber frameworks in
`Roadmap.md` Track 3 (ED-205A, EASA Part-IS).

## Sources

- AIXM — *Specification* (XSD, primer): <https://aixm.aero/page/aixm-51-specification>
- AIXM Coding Guidelines — *GML Profile* / *Geometry*: <https://ext.eurocontrol.int/aixm_confluence/display/ACG/GML+Profile>
- OGC 12-028r1 — *GML 3.2.1 Application Schema – Aviation*: <https://www.ogc.org/standard/aviation/>
- GeoServer — *app-schema* (see [[08 — App-Schema and Complex Features]] sources)
- GeoSolutions — *Complex Features / HALE* training: <https://geoserver.geosolutionsgroup.com/edu/en/complex_features/index.html>
