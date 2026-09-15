# OpenEyes API families

The legacy names describe separate historical interfaces. They are not one API
that clients are expected to traverse from v1 to v2 to v3.

| Family | Shape | Main purpose | Important difference |
|---|---|---|---|
| Core REST v1 | JSON under `/api/v1` | Patient search, signing and attachment display | Contains endpoints that were never reproduced as a complete v2 set |
| Core REST v2 | JSON under `/api/v2` | Documents, attachment data and leaflets | A disjoint group of newer resources, not a replacement for every v1 route |
| PASAPI V1 | XML under `/PASAPI/V1` | Patient and appointment integration | Identifier type is carried in paths and payloads are relatively small |
| PASAPI V2 | XML under `/PASAPI/V2` | Richer PAS integration | Adds GP, practice, commissioning and contact data, institution context and identifier type in the payload |
| PASAPI V3 | XML under `/PASAPI/V3` | Current PAS integration contract | Moves identifier resolution to a header, adds identifier lists and restores worklist definitions |
| xAPI | JSON under `/xapi` | Resource-style external integration | Has its own generated OpenAPI contract, authentication and explicit context rules; it is not PASAPI v3 |
| Browser AJAX | Mixed internal routes | Supports the legacy user interface | It is an implementation detail, not a customer integration contract |

## Rewrite decision

The Laravel application has one canonical, unversioned `/api` contract within
each OpenEyes release. Do not add `/api/v1` by default. A release supports one
API behavior, and incompatible changes follow the normal OpenEyes release and
LTS process.

Legacy routes are adapters at the edge. Add one only when a customer integration
inventory proves it is required. An adapter translates its legacy request into
the canonical application service and translates the result back. It must not
contain a second implementation of clinical behavior.

The cutover process therefore inventories every external caller, records its
family and operations, moves it to the canonical API where practical, and keeps
the smallest measured adapter set for callers that cannot change in time. xAPI,
PASAPI and future MCP services remain optional integration surfaces rather than
namespaces for the application's own frontend.

## Source locations

- Core REST controllers: `protected/modules/Api/controllers/v1` and
  `protected/modules/Api/controllers/v2`
- PASAPI controllers and XML schemas: `protected/modules/PASAPI/controllers`
  and `protected/modules/PASAPI/schema`
- xAPI resources and schema generation: `protected/modules/XAPI`

Recheck these locations against the exact source release being migrated. The
families have accumulated changes over time and customer integrations may rely
on behavior that is not obvious from the route name alone.
