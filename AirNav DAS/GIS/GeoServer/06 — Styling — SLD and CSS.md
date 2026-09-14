---
tags:
  - gis
  - geoserver
  - styling
  - sld
created: 2026-09-09
---

# 06 — Styling — SLD and CSS

> [!abstract] The 30-second version
> A GeoServer style says *how to draw a layer*. The standard is **SLD** — an
> XML document of **Rules**, each with an optional **Filter** and
> **scale range**, containing **Symbolizers** (point / line / polygon / text /
> raster). It's verbose, so GeoServer also accepts **CSS**, **YSLD** and
> **MBStyle** and converts them to SLD internally. You can design in **QGIS**
> and export to SLD — with caveats.

## The SLD structure

```
StyledLayerDescriptor
└── NamedLayer  (the layer this applies to)
    └── UserStyle
        └── FeatureTypeStyle
            ├── Rule
            │   ├── Filter            (ogc:Filter or none)
            │   ├── MinScaleDenominator / MaxScaleDenominator
            │   └── Symbolizer(s)     Point | Line | Polygon | Text | Raster
            └── Rule …
```

Rendering: for each feature, GeoServer runs every rule whose **filter matches**
*and* whose **scale range** includes the current map scale, and draws its
symbolizers in order. Multiple `FeatureTypeStyle`s = multiple passes (useful
for "all casings first, then all fills").

## The five symbolizers

| Symbolizer | Draws | Key sub-elements |
|---|---|---|
| **PointSymbolizer** | markers | `Graphic` → `Mark` (`WellKnownName`: circle, square, triangle, star…) or external `Graphic` (SVG/PNG); `Size`, `Rotation`, `Fill`, `Stroke` |
| **LineSymbolizer** | strokes | `Stroke` → `stroke`, `stroke-width`, `stroke-dasharray`, `stroke-linecap`; `PerpendicularOffset` |
| **PolygonSymbolizer** | fills + outlines | `Fill` (colour / **GraphicFill** = hatching), `Stroke` |
| **TextSymbolizer** | labels | `Label` (an expression), `Font`, `LabelPlacement` (point/line), `Halo`, and **vendor options**: `group`, `conflictResolution`, `maxDisplacement`, `followLine`, `repeat`, `autoWrap` |
| **RasterSymbolizer** | coverages | `ColorMap` (ramp / intervals / values), `Opacity`, `ContrastEnhancement`, `ChannelSelection` |

## Rules, filters, scale

```xml
<Rule>
  <Name>restricted</Name>
  <ogc:Filter><ogc:PropertyIsEqualTo>
    <ogc:PropertyName>type</ogc:PropertyName><ogc:Literal>R</ogc:Literal>
  </ogc:PropertyIsEqualTo></ogc:Filter>
  <MaxScaleDenominator>3000000</MaxScaleDenominator>
  <PolygonSymbolizer>
    <Fill><GraphicFill><Graphic><Mark>
      <WellKnownName>shape://slash</WellKnownName>
      <Stroke><CssParameter name="stroke">#cc7700</CssParameter></Stroke>
    </Mark></Graphic></GraphicFill></Fill>
  </PolygonSymbolizer>
</Rule>
```

- **Filter functions** — SLD/GeoTools has ~200 functions (`Categorize`,
  `Interpolate`, `Recode`, `env`, string/math/geometry). `Recode` is how you
  do "colour by category" in one rule instead of ten.
- **`<ElseFilter/>`** — the catch-all rule.
- Scale: `1:MaxScaleDenominator` … work out denominators from zoom levels.

## Dynamic styling

- **`env()`** + `&env=key:value` on the request → runtime substitution
  (thresholds, colours, a chosen band).
- **`SLD_BODY=`** / **`SLD=`** on `GetMap` → send an ad-hoc style. Powerful;
  also a reason to think about who can call your WMS.

## CSS — the sane way to hand-write styles

Install the **CSS extension**, then:

```css
[type = 'R'] {
  fill: #cc7700; fill-opacity: 0.3;
  stroke: #cc7700; stroke-width: 1;
}
[type = 'FIR'] { fill: none; stroke: #555; stroke-width: 1.5; }
* { label: [designator]; font-fill: #222; halo-color: white; halo-radius: 1; }
```

GeoServer compiles it to SLD. Much shorter, same power for most cases. **YSLD**
(YAML) and **MBStyle** (Mapbox GL JSON) are the other two options.

## From QGIS to GeoServer

QGIS layer → right-click → **Export → Save as SLD…** (or *Properties →
Symbology → Style ▾ → Save Style → SLD*).

> [!warning] The round-trip is lossy
> QGIS renderer features that **don't** map to SLD 1.0: many blend modes,
> some data-defined overrides, geometry generators, certain symbol layers.
> SLD features QGIS won't re-import cleanly: `GraphicFill` hatching,
> perpendicular offsets, some label vendor options. **Export, then open the
> SLD and fix it by hand** — treat QGIS as a starting point, not the source of
> truth. The [[06 — Exercise — Donlon airspace map|QGIS Donlon exercise]]
> style is a good candidate to export and clean.

## Sources

- GeoServer — *Styling*: <https://docs.geoserver.org/latest/en/user/styling/index.html>
- GeoServer — *SLD reference* + *cookbook*: <https://docs.geoserver.org/latest/en/user/styling/sld/reference/index.html> · <https://docs.geoserver.org/latest/en/user/styling/sld/cookbook/index.html>
- GeoServer — *CSS styling*: <https://docs.geoserver.org/latest/en/user/styling/css/index.html>
- OGC — *Symbology Encoding* / *SLD*: <https://www.ogc.org/standards/se/>
