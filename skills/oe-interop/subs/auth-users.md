# User authentication (LDAP) and User Data API

## User authentication — LDAP / Active Directory

OE can authenticate users against any **LDAP-compatible** directory, including **Microsoft Active Directory**.

Configure an LDAP config at `Admin->Core->LDAP Configurations`, then reference it from an **Authentication Method** at `Admin->Institutions->Institution->Authentication Methods`.

Config options:

| Option | Notes |
|---|---|
| **LDAP Server** | FQDN of the TCP/IP LDAP endpoint |
| **LDAP Port** | default **389** |
| **LDAP Admin Distinguished Name** | service account OE binds as for queries, e.g. `CN=openeyes,CN=Users,dc=example,dc=com` |
| **LDAP Admin Password** | password for the service account |
| **LDAP Base Distinguished Name** | top-level OU for accounts with OE access, e.g. `CN=Users,dc=example,dc=com` |
| **LDAP Method** | one of `native`, `native-search`, `zend` |

Advanced parameters:

- `ldap_update_name` — `true`/`false` (default `true`): update the account's first/last name when it changes on the LDAP server.
- `ldap_update_email` — `true`/`false`: update the account's email when it changes on the LDAP server.

## User Data API (CSD) — staff details pull

OE can **pull** staff details (name, grade, role, access level, etc.) from an external source and keep each user updated, keyed on their **Active Directory username**. Useful when staff data is maintained in a separate database/application.

Config (env vars):

- `OE_CSD_API_URL` = `https://<API_SERVER_NAME>`
- `OE_CSD_API_KEY` = `<API SECRET KEY>`
- `OE_CSD_API_TIMEOUT` = `30`

API contract:

- A simple **SOAP** API with a single endpoint; query parameter name **`DomainUsername`**.
- Authentication via an **`APIKey`** header.
- Returns a JSON string of this shape:

```json
{
  "code": "MUUID000000",
  "username": "<Active directory username>",
  "first_name": "Firstname",
  "last_name": "Lastname",
  "title": "Miss/Mr/etc.",
  "qualifications": "",
  "role": "Staff Nurse",
  "registration_code": [
    { "PersonnelID": "200000", "ProfessionalRegistration": "NMC - 70Y0000E" }
  ],
  "is_doctor": "False",
  "is_clinical": "True",
  "is_consultant": "False",
  "is_surgeon": "False",
  "active": "1"
}
```

(Source describes it as a "simple SOAP API" yet specifies an `APIKey` header and JSON response — treat the JSON contract above as authoritative.)
