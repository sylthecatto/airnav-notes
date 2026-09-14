---
tags:
  - aixm-gis
  - aixm
created: 2026-09-07
---

# 01 — AIXM essentials for GIS

> [!abstract] The 30-second version
> An AIXM file is an **XML message** that carries a list of **features**
> (airspace, runway, navaid…). Each feature has a **stable identity**, a
> **geometry** in standard GML, and one or more **time slices** that say *what
> was true, and when*. A GIS reads the geometry and the "now" slice; the rest
> is why AIXM looks more complicated than a shapefile.

For the full concept treatment see [[21 — AIXM]] and [[22 — AIXM Temporality Model]].
This note is only the parts you need to make sense of what shows up in QGIS.

## The four ideas

### 1 · The model has three layers

| Layer | What it is |
|---|---|
| **Logical model (UML)** | ~150 feature classes — `AirportHeliport`, `Runway`, `Airspace`, `Navaid`, `DesignatedPoint`, `RouteSegment`… — with their properties and relationships. Format-neutral. |
| **XML Schema (XSD)** | the concrete file format the UML is mapped to. |
| **GML profile** | geometry (points, curves, surfaces) uses the OGC **Geography Markup Language**, so AIXM geometry *is* standard [[20 — GIS|GIS]] geometry. |

Plus **usage rules** for temporality and for how features identify and
reference each other. AIXM is **jointly governed by EUROCONTROL and the FAA**
through a global Change Control Board.

### 2 · Everything is a "feature" with an identity

A feature is a modelled real-world thing. Every one carries:

- a **`gml:id`** — unique within the file;
- a **UUID** (`gml:identifier`) — globally unique and **stable across
  updates**, so "the same runway" can be recognised in next month's dataset.

Features **reference** each other by UUID (a `Runway` points to its
`AirportHeliport`; a `RouteSegment` points to its start/end points). In a GIS
these show up as ID columns you can join on — not as ready-made relationships.

### 3 · Time slices — the bit that surprises you

An AIXM feature does **not** hold its properties directly. It holds a list of
**time slices**, each valid for a period:

| Time slice | Meaning |
|---|---|
| **BASELINE** | the normal, full picture from a date onward |
| **PERMDELTA** | a permanent change from a date (only the changed properties) |
| **TEMPDELTA** | a temporary change for a stated window (e.g. an activation, a closure) — this is how a **digital [[15 — NOTAMs|NOTAM]]** is expressed |

A plain AIP dataset (like the Donlon file you have) is almost all BASELINE
slices, so in QGIS you mostly see one row per feature. When you load data with
deltas, you get **multiple rows per feature** and must filter to the slice
valid at your time of interest. More in [[22 — AIXM Temporality Model]].

### 4 · The message wrapper

The file's outermost element is an **`AIXMBasicMessage`**. Inside, each feature
is wrapped in a **`hasMember`** element:

```xml
<message:AIXMBasicMessage gml:id="...">
  <message:hasMember>
    <aixm:Airspace gml:id="...">
      <aixm:timeSlice>
        <aixm:AirspaceTimeSlice> ... geometry, class, limits ... </aixm:AirspaceTimeSlice>
      </aixm:timeSlice>
    </aixm:Airspace>
  </message:hasMember>
  <message:hasMember> <aixm:Navaid .../> </message:hasMember>
  ...
</message:AIXMBasicMessage>
```

GDAL turns each **feature type** into a **layer** and each **`hasMember`** into
a **row**.

## Versions you'll meet

| Version | Notes |
|---|---|
| **4.5** | pre-GML; legacy interfaces only |
| **5.1 / 5.1.1** | GML-based; introduced the temporality model; still the most widely deployed (the Donlon sample and FAA NASR are 5.1.1 / 5.1) |
| **5.2** | current, released **January 2025** — adds GNSS/SBAS/GBAS elements, runway-condition reporting, PBN alignment, IDs on complex properties. Reads in the same tools. |

## What a GIS keeps and drops

| AIXM has… | In QGIS you get… |
|---|---|
| feature geometry (GML point/curve/surface) | a normal layer geometry |
| scalar properties (name, class, frequency, limits) | attribute columns |
| nested/repeating properties (notes, schedules, limits with units) | columns flattened with `\|`-joined paths, or `StringList`/JSON — readable but awkward |
| UUID references between features | plain text ID columns (join them yourself) |
| multiple time slices | multiple rows — filter by validity |

That mismatch is exactly why [[05 — GMLAS and GeoPackage (the robust route)]]
exists for serious work.

## Sources

- AIXM 5.2 overview: <https://aixm.aero/page/aixm-52>
- AIXM 5.2 Specification: <https://aixm.aero/page/aixm-52-specification>
- AIXM Versions: <https://aixm.aero/page/versions>
- AIXM Governance: <https://aixm.aero/page/governance>
- OGC Geography Markup Language (GML): <https://www.ogc.org/standard/gml/>
