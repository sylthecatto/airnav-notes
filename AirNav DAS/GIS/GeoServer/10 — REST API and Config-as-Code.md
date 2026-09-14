---
tags:
  - gis
  - geoserver
  - automation
  - rest
created: 2026-09-09
---

# 10 — REST API and Config-as-Code

> [!abstract] The 30-second version
> Everything the admin console does, the **REST API** does — create
> workspaces, stores, layers, styles, reload config, seed tiles. It's under
> **`/geoserver/rest/`**, HTTP Basic auth, XML or JSON. This is how you make
> GeoServer **reproducible**: script the setup, keep it in git, and stop
> clicking. It also matches your team's "improve efficiency" habit and your
> `Roadmap.md` Track 1e automation goal.

## The shape of the API

```
/geoserver/rest/
├── workspaces[/<ws>]
│   ├── datastores[/<ds>][/featuretypes[/<ft>]]
│   └── coveragestores[/<cs>][/coverages[/<c>]]
├── layers[/<layer>]            layergroups[/<lg>]
├── styles[/<style>]            (SLD/CSS upload)
├── security/  (acl, self, …)   settings/  logging/
├── reload    (POST — re-read the data dir)
├── reset     (POST — clear caches)
└── about/version   about/status   about/manifest
```

- **Auth:** HTTP Basic (`-u admin:***`) over **HTTPS only** in production.
- **Format:** append `.json` or `.xml`, or set `Accept` / `Content-type`.
- **Idempotency:** `POST` to create, `PUT` to modify, `DELETE` to remove
  (`?recurse=true` to cascade).

## Worked examples

```bash
GS=https://host/geoserver/rest
AUTH='-u admin:***'

# version (compare to the security advisories)
curl -s $AUTH $GS/about/version.json | jq '.about.resource[0].Version'

# create a workspace with a namespace URI
curl $AUTH -XPOST -H 'Content-type: application/json' $GS/workspaces \
  -d '{"workspace":{"name":"aixm"}}'
curl $AUTH -XPUT -H 'Content-type: application/json' $GS/namespaces/aixm \
  -d '{"namespace":{"prefix":"aixm","uri":"http://www.aixm.aero/schema/5.1.1"}}'

# a PostGIS store
curl $AUTH -XPOST -H 'Content-type: application/json' \
  $GS/workspaces/aixm/datastores -d @postgis-store.json

# publish a table as a layer
curl $AUTH -XPOST -H 'Content-type: application/json' \
  $GS/workspaces/aixm/datastores/db/featuretypes \
  -d '{"featureType":{"name":"Airspace","srs":"EPSG:4326"}}'

# upload a style and assign it
curl $AUTH -XPOST -H 'Content-type: application/vnd.ogc.sld+xml' \
  --data-binary @airspace.sld "$GS/styles?name=airspace_by_type"
curl $AUTH -XPUT -H 'Content-type: application/json' $GS/layers/aixm:Airspace \
  -d '{"layer":{"defaultStyle":{"name":"airspace_by_type"}}}'

# force a config reload after editing data-dir files
curl $AUTH -XPOST $GS/reload
```

Python: `requests` + a dict of desired state, diffed against `GET` responses —
a ~150-line script gives you declarative GeoServer.

## Backup and Restore (do this, not `tar` alone)

Install the **Backup & Restore** extension → `/geoserver/rest/br/backup`:

```bash
curl $AUTH -XPOST -H 'Content-type: application/json' $GS/br/backup \
  -d '{"backup":{"archiveFile":"/var/backups/gs-$(date +%F).zip",
       "overwrite":true}}'
```

It bundles the catalog config (and optionally the file data). Schedule it;
keep the last N; test a restore. The whole **data directory** is still the
belt-and-braces backup ([[02 — Install and Run]]).

## The Importer extension

`/geoserver/rest/imports` — point it at a file or a directory and it batch-
creates stores + layers with sensible defaults. Good for bulk-onboarding
reference data; less so for the carefully-shaped app-schema setup.

## Config-as-code pattern

```
repo/
├── geoserver/
│   ├── 00-workspaces.json      10-stores/      20-layers/
│   ├── styles/*.sld
│   └── mappings/aixm.appschema.xml
├── apply.sh   (curl calls, ordered)
└── README
```

Now a rebuilt server is a script run, code review covers style changes, and
`git log` is your change history.

## Sources

- GeoServer — *REST*: <https://docs.geoserver.org/latest/en/user/rest/index.html>
- GeoServer — *REST API reference* (OpenAPI): <https://docs.geoserver.org/latest/en/api/>
- GeoServer — *Backup and Restore*: <https://docs.geoserver.org/latest/en/user/community/backuprestore/index.html>
- GeoServer — *Importer*: <https://docs.geoserver.org/latest/en/user/extensions/importer/index.html>
- `geoserver-restconfig` (Python client): <https://pypi.org/project/geoserver-restconfig/>
