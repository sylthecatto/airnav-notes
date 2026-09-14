---
tags:
  - aixm-gis
  - qgis
  - exercise
created: 2026-09-07
---

# 06 — Exercise — Donlon airspace map

> [!abstract] The goal
> Start from the AIXM file, finish with a **styled, labelled map** of Donlon's
> airspace and navaids that you could export as a PDF. ~30 minutes. Every step
> uses real field names from the sample data.

Work from `sample-data/donlon.gpkg` (already built — see
[[04 — Load AIXM into QGIS (GML driver)]] if you want to rebuild it).

## 1 · Load the layers

**Browser panel** → expand `donlon.gpkg` → **Ctrl-click** to select:
`Airspace`, `Navaid`, `AirportHeliport`, `RouteSegment`, `DesignatedPoint`,
`GeoBorder` → drag onto the map.

In the **Layers** panel drag them into this top-to-bottom order (top draws
last):

```
DesignatedPoint
Navaid
AirportHeliport
RouteSegment
GeoBorder
Airspace
```

## 2 · Set a sensible CRS

Bottom-right status bar → click the CRS button → set the **project CRS**. For
Donlon (mid-Atlantic, ~47° N) a good choice is **EPSG:3395** (World Mercator)
or just leave **EPSG:4326** for now. Layers reproject on the fly.

## 3 · Style the airspace by type

Double-click **Airspace** → **Symbology** tab → switch the top dropdown from
*Single Symbol* to **Categorized**.

- **Value:** `type`
- Click **Classify**.

You'll get categories `A`, `D`, `FIR`, `P`, `R`, `TMA`. Set:

| `type` | Meaning                   | Suggested fill          |
| ------ | ------------------------- | ----------------------- |
| `FIR`  | Flight Information Region | no fill, grey outline   |
| `TMA`  | Terminal control area     | light blue, 25% opacity |
| `A`    | Class A / controlled      | pale blue, 20%          |
| `R`    | Restricted area           | orange hatch, 30%       |
| `D`    | Danger area               | red hatch, 30%          |
| `P`    | Prohibited area           | solid red, 35%          |

Set each: click the symbol → **Simple Fill** → *Fill color* (drop the opacity
in the colour dialog) → *Stroke*. **OK**.

> [!tip] Make FIR a background, not a blob
> For the `FIR` category, set fill to *No Brush* and give it a 0.6 mm dark-grey
> outline so it frames the map instead of hiding everything.

## 4 · Style the navaids by type

Double-click **Navaid** → **Symbology** → **Categorized** → Value `type` →
**Classify**. Categories will include `VOR`, `VOR_DME`, `NDB`, `DME`.

- Give VOR/VOR_DME a hexagon marker, NDB a circle, DME a small square.
- Marker size ~3–4 mm.

## 5 · Label everything useful

**Airspace** → **Labels** tab → *Single Labels* → Value **`designator`**.
- Placement: *Using perimeter* or *Offset from centroid*.
- Add a subtle white buffer (Labels ▸ Buffer ▸ Draw text buffer, 1 mm).

**Navaid** → **Labels** → *Single Labels* → expression:

```
"designator" || ' (' || "name" || ')'
```

→ e.g. `DON (DONLON)`. Placement *Around point*, offset 2 mm.

**AirportHeliport** → **Labels** → Value `name` or `designator` (e.g. `EADD`),
bold.

## 6 · Filter to what's current (temporality preview)

The flattened table still carries the time columns. Right-click **Airspace** →
**Filter…** and try:

```
"interpretation" = 'BASELINE'
```

In this AIP-only file that changes nothing (it's all BASELINE) — but it's the
exact move you'll need on a dataset with `PERMDELTA` / `TEMPDELTA` rows. See
[[22 — AIXM Temporality Model]].

## 7 · Inspect a feature

Use the **Identify Features** tool (`Ctrl+Shift+I`) and click a restricted
area. Read off `type`, `designator`, `name`, and the vertical-limit columns.
Cross-check against the AIXM concept: this is an `Airspace` feature, its
geometry came from an `AirspaceGeometryComponent`, its limits from an
`AirspaceVolume` ([[01 — AIXM essentials for GIS]]).

## 8 · Make a layout

**Project ▸ New Print Layout** → name it *Donlon Airspace*.

- **Add Item ▸ Add Map** → drag a rectangle.
- **Add Item ▸ Add Legend** (it reads your layer names — rename layers first if
  they're ugly).
- **Add Item ▸ Add Scale Bar**, **Add Label** for a title.
- **Layout ▸ Export as PDF**.

## Done — what you practised

| Skill | Transfers to |
|---|---|
| categorized rendering on a code-list field | every AIXM feature type (airspace class, navaid type, route type…) |
| label expressions | building chart-style annotation from AIXM attributes |
| attribute filter on `interpretation` | working with real temporality data |
| Identify → map back to the model | reading any unfamiliar AIXM dataset |

### Next

- Redo this on **FAA NASR** data (real, messy) — [[02 — Sample data]].
- Load a **digital NOTAM** TEMPDELTA from `aixm/donlon`'s `DigitalNOTAM/`
  folder and see the temporary airspace activation as extra rows.
- Try the **GMLAS** route ([[05 — GMLAS and GeoPackage (the robust route)]]) and
  join `Navaid` to `AirportHeliport` on `servedAirport_href` in DB Manager.

## Sources

- QGIS User Manual — *Symbology Properties* (Categorized renderer): <https://docs.qgis.org/3.44/en/docs/user_manual/working_with_vector/vector_properties.html#symbology-properties>
- QGIS User Manual — *Labels*: <https://docs.qgis.org/3.44/en/docs/user_manual/working_with_vector/vector_properties.html#labels-properties>
- QGIS User Manual — *Print Layout*: <https://docs.qgis.org/3.44/en/docs/user_manual/print_composer/index.html>
