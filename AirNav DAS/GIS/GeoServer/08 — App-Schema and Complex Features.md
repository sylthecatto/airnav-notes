---
tags:
  - gis
  - geoserver
  - app-schema
  - aixm
created: 2026-09-09
---

# 08 — App-Schema and Complex Features

> [!abstract] The 30-second version
> A normal GeoServer layer is a **simple feature**: a flat row — one geometry,
> scalar attributes. **AIXM, INSPIRE, GeoSciML** and friends need **complex
> features**: nested sub-features, repeating elements, multiple geometries,
> `xlink` references between features. GeoServer's **app-schema** extension
> builds those by reading flat tables from a store (PostGIS) and **mapping**
> them onto a target **GML application schema (XSD)** via an XML **mapping
> file**. It's WFS-focused, read-mostly, and fiddly — but it's the only way to
> serve real AIXM.

## Simple vs complex — the shape of the problem

```
SIMPLE FEATURE (a shapefile row)          COMPLEX FEATURE (aixm:AirportHeliport)
┌───────────────────────────┐             AirportHeliport
│ geom  name   type  elev   │               ├─ timeSlice → AirportHeliportTimeSlice
│ POINT "DON"  VOR   145    │               │    ├─ designator, name, type
└───────────────────────────┘               │    ├─ ARP → ElevatedPoint (geometry)
                                            │    ├─ servedCity (0..*)
                                            │    └─ annotation → Note (0..*)
                                            └─ (another timeSlice…)
```

Complex features carry: **nesting**, **cardinality > 1**, **multiple
geometries per feature**, **nillable/`xsi:nil`**, and **feature chaining**
(feature A holds an `xlink:href` to feature B rather than embedding it).

## How app-schema works

```
PostGIS tables  ──►  mapping file (XML)  ──►  target XSD (the GML app-schema)
 airport_heliport         "column X → XPath   http://www.aixm.aero/schema/
 runway                    aixm:...            5.1.1/AIXM_Features.xsd"
 note                      + feature chaining
                          │
                          ▼
             GeoServer app-schema DataStore  ──►  WFS DescribeFeatureType / GetFeature
                                                   emit schema-valid AIXM GML
```

- It's an extension: unzip `geoserver-*-app-schema-plugin.zip` jars into
  `WEB-INF/lib` (match the GeoServer version exactly).
- You create an **app-schema store** whose only parameter is the path to the
  **mapping file**.
- One complex type can be assembled from **several** source stores/tables.

## The mapping file — the pieces

```xml
<as:AppSchemaDataAccess xmlns:as="http://www.geotools.org/app-schema">
  <namespaces> … aixm, gml, xlink … </namespaces>

  <sourceDataStores>
    <DataStore><id>db</id><parameters> … PostGIS params … </parameters></DataStore>
  </sourceDataStores>

  <targetTypes>
    <FeatureType><schemaUri>AIXM_Features.xsd</schemaUri></FeatureType>
  </targetTypes>

  <typeMappings>
    <FeatureTypeMapping>
      <sourceDataStore>db</sourceDataStore>
      <sourceType>airport_heliport</sourceType>          <!-- a table -->
      <targetElement>aixm:AirportHeliport</targetElement> <!-- an XSD element -->
      <attributeMappings>

        <AttributeMapping>
          <targetAttribute>aixm:AirportHeliportTimeSlice/aixm:designator</targetAttribute>
          <sourceExpression><OCQL>designator_col</OCQL></sourceExpression>
        </AttributeMapping>

        <AttributeMapping>                                <!-- feature chaining -->
          <targetAttribute>aixm:annotation</targetAttribute>
          <sourceExpression>
            <OCQL>id</OCQL><linkElement>aixm:Note</linkElement>
            <linkField>FEATURE_LINK[1]</linkField>
          </sourceExpression>
          <isMultiple>true</isMultiple>
        </AttributeMapping>

      </attributeMappings>
    </FeatureTypeMapping>

    <FeatureTypeMapping>                                  <!-- the chained type -->
      <sourceType>note</sourceType>
      <targetElement>aixm:Note</targetElement>
      …
    </FeatureTypeMapping>
  </typeMappings>
</as:AppSchemaDataAccess>
```

| Element | Does |
|---|---|
| `sourceExpression/OCQL` | a CQL expression over the source row (a column, a function, a concat) |
| `idExpression` | what becomes `gml:id` |
| `ClientProperty` | attributes on the target element — e.g. `xlink:href`, `uom` |
| `isMultiple` | this target path repeats (cardinality > 1) |
| `linkElement` + `linkField` | **feature chaining**: join `FEATURE_LINK` fields to nest/reference another `FeatureTypeMapping` |
| `<includedTypes>` | split mappings across multiple files |

## hale studio — build the mapping visually

Hand-writing AIXM mappings is brutal. **hale studio** (wetransform, free) loads
your **source schema** (the DB) and the **AIXM target schema**, lets you draw
the mappings, validates them, and **exports a GeoServer app-schema config**
(mapping file + the datastore). This is how teams actually do it.

## Constraints to expect

- **Read-focused** — WFS-T on complex features is limited.
- **Performance** — feature chaining = joins per feature; needs indexes, tuned
  connection pools, and often materialised views. Don't chain what you can
  denormalise.
- **Schema resolution** — GeoServer must reach every imported `.xsd`. Ship the
  AIXM schemas **locally** (`app-schema-cache/` or bundled) rather than relying
  on `http://www.aixm.aero/schema/...` at runtime.
- **Security** — **CVE-2024-36401** (RCE 9.8) hit *every* GeoServer, but its
  emergency workaround was "delete `gt-complex-*.jar`" — which **breaks
  app-schema**. An AIXM deployment could only patch. Know which mitigations
  your stack rules out *before* the incident ([[12 — Hardening and the CVE Track]]).

Next: [[09 — Serving AIXM]] applies all of this to the real schema.

## Sources

- GeoServer — *Application schemas* + *Tutorial* + *Mapping File*: <https://docs.geoserver.org/latest/en/user/data/app-schema/index.html>
- GeoServer — *App-schema mapping file reference*: <https://docs.geoserver.org/latest/en/user/data/app-schema/mapping-file.html>
- GeoServer — *Feature Chaining*: <https://docs.geoserver.org/latest/en/user/data/app-schema/feature-chaining.html>
- GeoSolutions — *Complex Features with GeoServer and HALE* training: <https://geoserver.geosolutionsgroup.com/edu/en/complex_features/index.html>
- hale studio: <https://www.wetransform.to/products/halestudio/>
