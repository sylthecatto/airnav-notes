---
tags:
  - gis
  - geoserver
  - security
created: 2026-09-09
---

# 11 — Security Model

> [!abstract] The 30-second version
> GeoServer authenticates a request through a **filter chain**, resolves the
> caller to **users → groups → roles**, then checks three kinds of rule:
> **service** rules (may this role call WFS?), **data** rules (may this role
> read workspace `aixm`?), and **REST** rules (may this role hit
> `/rest/**`?). Everything is in `<data_dir>/security/`. Default is
> wide-open-ish — you lock it down deliberately.

## Authentication — the filter chain

A request passes through an ordered **authentication filter chain**:

```
anonymous ─ basic-auth ─ form-login ─ remember-me ─ [ others you add ]
```

Add filters for real deployments:

| Filter | For |
|---|---|
| **HTTP Basic** | REST + machine clients (over HTTPS only) |
| **Form login** | the web admin console |
| **Header / pre-auth** | a reverse proxy that already authenticated (e.g. SSO at nginx) |
| **LDAP / Active Directory** | enterprise user directory |
| **OAuth2 / OpenID Connect** | Keycloak, Azure AD, etc. (extension) |
| **CAS** | Jasig/Apereo CAS SSO |

The **master password** protects the keystore (URL-config passwords, etc.) —
separate from the `admin` account password. Change both on day one.

## Users, groups, roles

- **User/Group services** — where accounts live: the default XML file, or JDBC,
  or LDAP.
- **Role services** — where roles live and how they map to users/groups.
- Built-in roles: **`ROLE_ADMINISTRATOR`** (everything), **`ROLE_GROUP_ADMIN`**,
  **`ROLE_AUTHENTICATED`**, **`ROLE_ANONYMOUS`**.
- You define your own: `ROLE_AIXM_READER`, `ROLE_AIXM_EDITOR`, `ROLE_OPS`.

## The three rule sets

### Service security — `services.properties`

Which **roles** may call which **service.operation**:

```
wfs.GetFeature=ROLE_AIXM_READER,ROLE_OPS
wfs.Transaction=ROLE_AIXM_EDITOR
wps.Execute=ROLE_ADMINISTRATOR          # or don't install WPS at all
*.*=ROLE_AUTHENTICATED
```

### Data security — `layers.properties`

Which roles may **read (r)** / **write (w)** / **admin (a)** a
`workspace.layer`:

```
aixm.*.r=ROLE_AIXM_READER,ROLE_OPS
aixm.Airspace.w=ROLE_AIXM_EDITOR
*.*.r=ROLE_AUTHENTICATED
mode=HIDE          # HIDE | CHALLENGE | MIXED — how denied layers behave
```

- **HIDE** — denied layers simply don't appear in Capabilities (best for
  "these clients shouldn't know it exists").
- **CHALLENGE** — 401, prompt for credentials.
- **MIXED** — hide until explicitly requested, then challenge.

### REST security — `rest.properties`

```
/rest/**;GET=ROLE_OPS,ROLE_ADMINISTRATOR
/rest/**;POST,PUT,DELETE=ROLE_ADMINISTRATOR
```

## Finer-grained options

| Feature | What it adds |
|---|---|
| **GeoServer ACL** (was GeoFence) | rule engine: per-layer, **per-attribute**, **spatial** (only features inside a geometry), per-CQL-filter, time-limited — run as a sidecar service |
| **Per-workspace services** ("virtual services") | `/geoserver/aixm/wfs` only exposes `aixm` — combine with data rules |
| **Disable services** globally or per workspace | smallest surface ([[05 — OGC Services]]) |

## The security sandbox

GeoServer has a **file-system sandbox** and a **script sandbox** — restrict
what SLD external graphics, app-schema, WPS scripting and the `file://` scheme
can reach. Enable it: `GEOSERVER_FILEBROWSER_HIDEFS=true` and the sandbox
system properties. Relevant because several past CVEs were sandbox escapes /
arbitrary file reads.

## Minimum sane config for an internet-exposed instance

1. Strong `admin` + master passwords; no default accounts.
2. Admin console **not** internet-facing (proxy allow-list by IP, or a
   separate internal-only vhost).
3. HTTPS only; secure + httpOnly session cookies.
4. Own roles; `ROLE_ANONYMOUS` gets **nothing** (or only the intended public
   layers).
5. Data rule default `*.*.r=ROLE_AUTHENTICATED`, `mode=HIDE`.
6. WFS-T and WPS off unless required and role-gated.
7. REST writes = admin only.
8. GeoServer ACL if you need spatial/attribute masking.

Continue to [[12 — Hardening and the CVE Track]] for the full production
checklist and the patch story.

## Sources

- GeoServer — *Security*: <https://docs.geoserver.org/latest/en/user/security/index.html>
- GeoServer — *Service / Layer / REST security*: <https://docs.geoserver.org/latest/en/user/security/service.html>
- GeoServer ACL: <https://docs.geoserver.org/latest/en/user/extensions/acl/index.html>
- GeoServer — *Sandbox*: <https://docs.geoserver.org/latest/en/user/security/sandbox.html>
