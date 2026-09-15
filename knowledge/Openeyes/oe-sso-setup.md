# Setting up Single Sign-On (SSO) in OpenEyes

This guide walks a client administrator through enabling SSO so staff can log into OpenEyes (OE) with their existing organisational credentials instead of an OE-specific password.

OpenEyes supports two SSO protocols out of the box:

- **OIDC** (OpenID Connect) — use this with Microsoft Entra ID / Azure AD, Okta, Keycloak, Google, Auth0, etc.
- **SAML 2.0** — use this with ADFS, Shibboleth, Entra ID (SAML mode), Ping, etc.

You only need **one**. Pick whichever your identity provider (IdP) team prefers — see the decision aid in Section 2.

> **Two teams, one setup.** This is a joint job between your **OpenEyes administrator** (Sections 4–10, 13) and your **IdP team** (Section 11). Agree who owns each side before you start; the values you exchange are summarised in Section 1.

---

## Contents

1. [How it works](#1-how-it-works)
2. [SAML or OIDC?](#2-saml-or-oidc)
3. [Before you start](#3-before-you-start)
4. [Collect these values first](#4-collect-these-values-first)
5. [Step A — Create the SSO Configuration](#5-step-a--create-the-sso-configuration)
6. [Step B — Map the identity fields](#6-step-b--map-the-identity-fields)
7. [Worked examples](#7-worked-examples)
8. [Step C — Switch SSO on for the institution](#8-step-c--switch-sso-on-for-the-institution)
9. [Step D — Decide how users get their access](#9-step-d--decide-how-users-get-their-access)
10. [Provisioning users across several institutions](#10-provisioning-users-across-several-institutions)
11. [Your IdP team's side — what to register](#11-your-idp-teams-side--what-to-register)
12. [Security & operational notes](#12-security--operational-notes)
13. [Go-live checklist](#13-go-live-checklist)
14. [Test it](#14-test-it)
15. [Troubleshooting](#15-troubleshooting)
16. [Glossary](#16-glossary)

---

## 1. How it works

1. A user opens the OE login page and selects their **Institution** (and **Site**).
2. If that institution has SSO enabled, a **"Continue with \<name>"** button appears.
3. Clicking it sends the user to your IdP to authenticate.
4. The IdP sends the user back to OpenEyes at **`https://<your-oe-host>/sso/login`** with a signed token.
5. OpenEyes reads the user's **username, email, name** (and optionally **roles**) from that token, creates or updates their OE account, assigns their access, and logs them in.

Throughout this guide, replace **`<your-oe-host>`** with your real OpenEyes hostname (for example `openeyes.example-trust.nhs.uk`).

### The values the two sides exchange

| Your IdP team needs from OpenEyes | OpenEyes needs from your IdP team |
|---|---|
| The **Return/Reply URL**: `https://<your-oe-host>/sso/login` | The IdP's URLs, IDs, and signing certificate / client secret (details below) |
| (SAML) The SP **Entity ID** you chose | (SAML) IdP Entity ID, Sign-on URL, x509 signing certificate |
| (OIDC) The **Redirect URI** (same `/sso/login` URL) | (OIDC) Provider/Issuer URL, Client ID, Client Secret |
| The exact OE user fields you need claims for: **username, email, first name, last name** (+ roles) | The exact **claim/attribute names** the IdP will release for each of those fields |

> **The single most important value:** your IdP must return users to **`https://<your-oe-host>/sso/login`**. This is the SAML **ACS / Reply URL** *and* the OIDC **Redirect URI** — the same URL for both protocols. It must be **HTTPS**.

---

## 2. SAML or OIDC?

Either works well; OpenEyes treats them as equal. If your IdP team has no preference:

| Consider… | OIDC | SAML 2.0 |
|---|---|---|
| Typical fit | Modern cloud IdPs (Entra ID, Okta, Google, Keycloak, Auth0) | Established enterprise/federation (ADFS, Shibboleth, Ping) |
| Credentials OE stores | Client ID + Client Secret | IdP signing certificate (x509) |
| What carries identity | **Claims** in a JSON token | **Attributes** in a signed XML assertion |
| Certificate rotation to plan for | Client secret expiry | IdP signing-certificate renewal |

**Bottom line:** ask your IdP team which they already run for other apps and use that. You configure exactly one.

---

## 3. Before you start

- An OpenEyes account with the **admin** role.
- OpenEyes reachable over **HTTPS** — required for secure SSO handshake cookies and for SAML behind a proxy/load balancer (see Section 12).
- The **Institution** your users belong to already exists in OE (**Admin → Core → Institutions**) and has at least one **Site**.
- Your IdP team is ready to register a new application / relying party for OpenEyes.
- You have agreed a strategy for who gets access and what roles they receive (Section 9) — decide this early, because it affects what you ask the IdP team to send.

---

## 4. Collect these values first

Fill in the worksheet for your chosen protocol *before* opening the admin screens. Anything marked **(you decide)** is chosen by your OpenEyes administrator; everything else comes from your IdP team.

### OIDC worksheet

| Value | Where it comes from | Your value |
|---|---|---|
| Provider URL (authority) | IdP team | |
| Client ID | IdP team | |
| Client Secret | IdP team | |
| Issuer (optional) | IdP team | |
| Redirect URL = `https://<your-oe-host>/sso/login` | **(you decide)** — then give it to the IdP team | |
| Scopes (e.g. `openid profile email`) | (you decide) / IdP team | |
| Encryption Key — a 16-character secret | **(you decide)** | |
| Claim name for **username** | IdP team | |
| Claim name for **email** | IdP team | |
| Claim name for **first name** | IdP team | |
| Claim name for **last name** | IdP team | |
| Claim name for **roles** (if used) | IdP team | |

### SAML worksheet

| Value | Where it comes from | Your value |
|---|---|---|
| SP Entity ID (e.g. `https://<your-oe-host>` or `openeyes`) | **(you decide)** | |
| ACS / Reply URL = `https://<your-oe-host>/sso/login` | **(you decide)** — then give it to the IdP team | |
| IdP Entity ID / Issuer | IdP team | |
| IdP Single Sign-On URL | IdP team | |
| IdP x509 **signing** certificate | IdP team | |
| Attribute name for **username** | IdP team | |
| Attribute name for **email** | IdP team | |
| Attribute name for **first name** | IdP team | |
| Attribute name for **last name** | IdP team | |
| Attribute name for **roles** (if used) | IdP team | |

---

## 5. Step A — Create the SSO Configuration

Go to **Admin → Core → SSO Configurations** (`/admin/ssoconfig`) → **Add**.

Fill in:

- **Description** — a short label users will recognise, e.g. `Trust Single Sign-On`. **This is the exact text shown on the "Continue with …" login button**, so make it meaningful to staff.
- **Protocol** — choose **OIDC** or **SAML**. The form then shows the matching fields below.

### If you chose OIDC

All fields below except **Issuer** are required by the form.

| Field | What to enter | Source |
|---|---|---|
| **Provider URL** | Your IdP's base/authority URL, e.g. `https://login.microsoftonline.com/<tenant>/v2.0` | IdP team |
| **Client ID** | The application/client ID registered for OpenEyes | IdP team |
| **Client Secret** | The client secret for that application | IdP team |
| **Issuer** | The token issuer value (often same as Provider URL). Optional — leave blank unless your provider needs it validated | IdP team |
| **Redirect URL** | `https://<your-oe-host>/sso/login` | **You set this; give it to the IdP team** |
| **Response Type** | `code` for the standard, recommended authorization-code flow | You |
| **Implicit Flow** | `false` for code flow | You |
| **Scopes** | Space-separated, e.g. `openid profile email` (add the scope that carries roles if you map roles) | You / IdP team |
| **Auth Params** | An extra authorization-request parameter. The form requires a value, but what's valid is provider-specific — **ask your IdP team what to put here** (and your OpenEyes implementer if standard values don't work) | IdP team |
| **Encryption Key** | A random secret **you** choose — use **16 characters**. OE uses it to encrypt the short-lived login-handshake cookies (AES-128); it is **not** supplied by the IdP. Keep it private | You |

> **Response Type, Implicit Flow and Auth Params** are passed straight through to the underlying OIDC library. The standard authorization-code values (`code` / `false`) suit almost all providers; if your IdP needs something different, confirm the exact values with your IdP team or OpenEyes implementer.

### If you chose SAML

| Field | What to enter | Source |
|---|---|---|
| **Service Provider Entity Id** | An identifier you choose for OpenEyes, e.g. `https://<your-oe-host>` or `openeyes` | You |
| **Service Provider ACS URL** | `https://<your-oe-host>/sso/login` | **You set this; give it to the IdP team** |
| **Service Provider ACS Binding** | `urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST` | You |
| **Service Provider Name ID Format** | Optional, e.g. `urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress` | You |
| **Identity Provider Entity Id** | Your IdP's Entity ID / Issuer | IdP team |
| **Identity Provider Single SignOn Service URL** | Your IdP's sign-on URL | IdP team |
| **Identity Provider Single SignOn Service Binding** | `urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect` | You |
| **Identity Provider Single Logout Service URL** | Optional — see the note below | IdP team |
| **Identity Provider Single Logout Service Binding** | Optional — see the note below | You |
| **Identity Provider x509 Certificate** | The IdP's **signing certificate** (the Base64 PEM body — you can paste it with or without the `BEGIN/END CERTIFICATE` header lines) | IdP team |

> **Required SAML fields:** SP Entity Id, SP ACS URL, SP ACS Binding, IdP Entity Id, IdP Sign-on URL, IdP Sign-on Binding, and the IdP x509 Certificate. Name ID Format and both Single Logout fields are optional.
>
> **Single Logout note:** the Single Logout fields are stored, but OpenEyes does **not** currently initiate SAML Single Logout. Signing out of OpenEyes ends the OpenEyes session only — it does not sign the user out at the IdP, and vice versa. Plan user comms accordingly (e.g. on shared workstations).

Click **Save**.

---

## 6. Step B — Map the identity fields

Still on the SSO Configuration form, the **SSO Field Mappings** section tells OE which claim/attribute from the token fills each OE user field.

Each row has three columns:
- **Key** — the OpenEyes user field.
- **Value** — the exact name of the claim (OIDC) or attribute (SAML) your IdP sends.
- **Contains Array of Institutions** — leave unticked unless you're doing multi-institution provisioning (Section 10).

Four keys are **mandatory** and pre-filled — they are locked, and you only supply their **Value**:

| Key (OE field) | Typical OIDC claim | Typical SAML attribute |
|---|---|---|
| `username` | `preferred_username` or `sub` | e.g. `…/claims/name` |
| `email` | `email` | e.g. `…/claims/emailaddress` |
| `first_name` | `given_name` | e.g. `…/claims/givenname` |
| `last_name` | `family_name` | e.g. `…/claims/surname` |

Add one more optional row if you want the IdP to drive OE access:
- **`roles`** → the claim/attribute carrying the user's roles. OE treats a string value as a **comma-separated** list. (See Section 9, Option B.)

Get the exact **Value** strings from your IdP team — they vary by provider and by how each IdP is configured. Avoid special characters in keys/values; the form rejects them. Click **Save**.

---

## 7. Worked examples

> These are **illustrative** — the exact claim/attribute names depend on how your IdP is configured. Always confirm them with your IdP team and verify against a real login using the audit log (Section 12).

### Example A — Microsoft Entra ID (OIDC)

Configuration fields:

| Field | Example value |
|---|---|
| Provider URL | `https://login.microsoftonline.com/<tenant-id>/v2.0` |
| Issuer | `https://login.microsoftonline.com/<tenant-id>/v2.0` (or leave blank) |
| Redirect URL | `https://<your-oe-host>/sso/login` |
| Response Type | `code` |
| Implicit Flow | `false` |
| Scopes | `openid profile email` |
| Encryption Key | *(your own 16-character secret)* |

Field mappings:

| Key (OE field) | Value (Entra claim) |
|---|---|
| `username` | `preferred_username` |
| `email` | `email` |
| `first_name` | `given_name` |
| `last_name` | `family_name` |
| `roles` | `roles` |

> Entra only emits an `email` claim if the user has a mail address (or the optional claim is configured), and emits `roles` only when **App Roles** are assigned to the user. Your IdP team controls both.

### Example B — Generic SAML IdP (ADFS / Shibboleth style)

Field mappings using the common claim-schema URIs:

| Key (OE field) | Value (SAML attribute) |
|---|---|
| `username` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` |
| `email` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` |
| `first_name` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname` |
| `last_name` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname` |
| `roles` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` |

Use the **HTTP-Redirect** binding for the IdP sign-on URL and the **HTTP-POST** binding for your SP ACS URL.

---

## 8. Step C — Switch SSO on for the institution

Creating the configuration does **not** turn SSO on. You attach it to an institution:

1. **Admin → Core → Institutions** → open the relevant institution.
2. Scroll to the **Authentication Methods** section and click **Add Authentication Method**.
3. Set:
   - **Site** — leave as *None specified* to allow SSO at every site of this institution, or pick one site.
   - **Description** — internal label (admin-facing).
   - **User Authentication Method** — choose **SSO**.
   - **SSO Config** — select the configuration you created in Step A.
   - **Active** — tick this.
4. **Save.**

The **"Continue with \<description>"** button now appears on the login page whenever a user selects this institution (and a matching site, or any site if you left it as *None specified*). You can attach more than one SSO configuration to an institution — each active one shows as its own button.

---

## 9. Step D — Decide how users get their access

When an SSO user logs in for the first time, OE creates their account. You choose **one** of two strategies for what roles/firms they receive. The switch is **Default permissions enabled** under **Admin → SSO settings → Default SSO Permissions** (`/sso/defaultssopermissions`).

**Option A — Same access for everyone (simplest).**
Turn **Default permissions enabled** **on**, then set the default firm rights (global firm rights, or a specific list of firms), the default roles, and the consultant/surgeon flags if relevant. Every SSO user receives these defaults, and **any roles in the token are ignored**. Good when all SSO users are the same kind of user.

**Option B — Roles driven by your IdP (granular).**
Leave **Default permissions enabled** **off**, and instead use **Admin → SSO settings → SSO Roles Mappings** (`/sso/ssorolesauthassignment`):
- Create an SSO Role whose **name** exactly matches a role string your IdP sends in the `roles` claim (e.g. `OpenEyes-Clinician`), and map it to one or more OpenEyes roles.
- Repeat for each IdP role you want to honour.

With Option B in force, on **every** login OpenEyes re-reads the token's roles and reassigns OE roles to match. Two cases are **denied**:
- A user whose token contains **no roles** → login refused (*"User has no roles assigned"*).
- A user whose roles **match none** of your SSO Role mappings → login refused (*"User has no valid OpenEyes roles assigned"*).

Because roles are re-applied on each login, removing a user's role in the IdP **revokes** the matching OE access at their next sign-in — making the IdP the single source of truth for who can log in and what they can do. This is usually what an enterprise client wants.

> **Clinical-safety caution:** roles control which clinical functions a user can access. Validate every mapping with a non-clinical pilot account before rolling out to real users.

---

## 10. Provisioning users across several institutions

If your IdP sends a claim listing all the institutions a user belongs to (a comma-separated list or array of codes), OE can keep the user's institution memberships in sync automatically on each login:

1. In **SSO Field Mappings**, add a row whose **Value** is that claim, and tick **Contains Array of Institutions**. (Only one mapping row may have this ticked.)
2. An **Institution Mappings** section appears. Map each code the IdP sends (**Key**) to the OpenEyes institution's **`remote_id`** (**Value**). If the IdP already sends the OE `remote_id` directly, the code matches `remote_id` as-is and you can skip the per-code mapping.

On login, OE grants the user the institutions named in the token (those whose mapped code matches an **active SSO** institution authentication's `remote_id`) and **removes** SSO-granted institutions no longer present in the token — keeping access aligned with your directory.

---

## 11. Your IdP team's side — what to register

Give your IdP team:

**For OIDC:**
- Redirect URI: `https://<your-oe-host>/sso/login`
- The scopes you configured (e.g. `openid profile email`)
- Ask them for: Provider/Authority URL, Issuer (if any), Client ID, Client Secret, and the exact claim names for username, email, given name, family name (and roles, if used).

**For SAML:**
- ACS / Reply URL: `https://<your-oe-host>/sso/login` (HTTP-POST binding)
- SP Entity ID: the value you chose in Step A
- Ask them for: IdP Entity ID, IdP Sign-on URL, the **signing certificate**, and the exact attribute names they'll release for username, email, given name, surname (and roles, if used).

---

## 12. Security & operational notes

- **HTTPS is mandatory.** The SSO handshake relies on cookies, and SAML behind a load balancer/proxy needs HTTPS to build correct response URLs. (When the SP Entity ID begins with `https`, OpenEyes enables proxy-aware URL handling automatically.)
- **Protect the secrets.** The OIDC **Client Secret**, the **Encryption Key**, and the SAML **IdP certificate** are sensitive. OpenEyes already obscures the Client Secret, Encryption Key and IdP certificate when redisplaying a saved configuration, so re-enter them only when changing them.
- **Least privilege.** Prefer Option B (role-driven) so access is granted from your directory, and map IdP roles to the **minimum** OE roles each group needs.
- **Audit trail.** Every SSO attempt is written to the OpenEyes audit log under the action group **`SSO`**, including the **full set of claims/attributes the IdP returned**. This is the fastest way to see exactly what the IdP sent and why a mapping did or didn't match.
- **Rotation.** Put reminders in place for **Client Secret expiry** (OIDC) and **IdP signing-certificate renewal** (SAML); when either changes, update the SSO Configuration promptly or logins will start failing.
- **Logout is local.** As noted in Step A, OpenEyes does not perform SAML Single Logout — signing out of OE does not sign the user out of the IdP.

---

## 13. Go-live checklist

A quick end-to-end pass before you let real users in:

- [ ] Institution exists with at least one Site (Section 3).
- [ ] Access strategy decided — Option A or B (Section 9).
- [ ] SSO Configuration created, protocol fields complete (Section 5).
- [ ] Required field mappings set: username, email, first_name, last_name (Section 6).
- [ ] Roles mapping or default permissions configured (Section 9).
- [ ] IdP app/relying party registered with Redirect/ACS = `https://<your-oe-host>/sso/login` (Section 11).
- [ ] Institution Authentication Method added, set to **SSO**, **Active** ticked (Section 8).
- [ ] Test login completed in a private window (Section 14).
- [ ] New user's account checked: name, email, roles, firms correct (Section 14).

---

## 14. Test it

1. Open the OpenEyes login page in a private/incognito window.
2. Select the **Institution** (and **Site**) you enabled.
3. Confirm the **"Continue with \<your description>"** button appears.
4. Click it — you should be redirected to your IdP, sign in there, and land back in OpenEyes logged in.
5. Check the new user's account under **Admin → Core → Users**: name, email, roles, and firms should match your mapping/permission choices.
6. If anything is off, open the **audit log** (action group `SSO`) for that attempt to see the exact claims the IdP returned — compare them against your field mappings.

---

## 15. Troubleshooting

| Symptom / message | Likely cause / fix |
|---|---|
| No SSO button on login page | The institution's Authentication Method isn't **Active**, the wrong institution/site was selected, or no SSO config is attached (Step C). |
| "SSO cookie not set." | `/sso/login` was reached directly rather than via the login-page button. Always start from the OE login page and click **Continue with …**. |
| "SAML Idp X509Certificate not found." | The **IdP x509 Certificate** field is empty — paste the IdP's signing certificate body. |
| "Error in SAML authentication: …" | The IdP's signed assertion doesn't validate against OE's config — usually a certificate mismatch, or the SP Entity ID / ACS URL doesn't match what the IdP registered. Recheck Step A against the IdP registration. |
| "Source for Username is not defined" / "Source for email is not defined" | The `username` or `email` field-mapping **Value** doesn't match a claim the IdP actually sent. Open the audit log to see the real claim names and correct the mapping. |
| "User has no roles assigned" | Option B (role-driven) and the user's token contained no `roles`. Assign a role in the IdP, or send the roles claim. |
| "User has no valid OpenEyes roles assigned" | Option B and the token's roles match **none** of your **SSO Roles Mappings**. Add a mapping whose name matches the IdP role string exactly. |
| "Site ID needs to be provided for user to login" | No site was selected and the institution has no default site. Pick a site at login, or set the institution's first/default site. |
| "User Authentication failed" / "The user cannot be logged in" | Identity was verified but the final OE login step failed (e.g. account state). Check the user record and the audit log entry for that attempt. |
| Redirect loops / returns to login | The IdP's Redirect/ACS URL doesn't exactly equal `https://<your-oe-host>/sso/login`, or OE isn't being served over HTTPS behind the proxy. |
| Need the full picture of a failed attempt | Every SSO attempt is in the **audit log** (action group `SSO`), including the attributes the IdP returned — the fastest diagnosis route. |

---

## 16. Glossary

| Term | Meaning |
|---|---|
| **SSO** | Single Sign-On — logging into OpenEyes with your organisational account. |
| **IdP** | Identity Provider — the system that authenticates the user (Entra ID, Okta, ADFS, …). |
| **SP** | Service Provider — OpenEyes, in this relationship. |
| **OIDC** | OpenID Connect — a modern SSO protocol built on OAuth 2.0; identity travels in a JSON token. |
| **SAML 2.0** | An XML-based SSO protocol; identity travels in a signed XML assertion. |
| **Claim / Attribute** | A piece of identity data the IdP sends (username, email, role…). "Claim" is OIDC's term, "attribute" is SAML's. |
| **ACS URL** | Assertion Consumer Service — the SAML endpoint that receives the IdP's response. For OpenEyes this is `/sso/login`. |
| **Redirect URI** | The OIDC equivalent of the ACS URL — where the IdP returns the user. Also `/sso/login`. |
| **Entity ID** | A unique identifier for a SAML party (the SP or the IdP). |
| **Issuer** | The identifier of the token's issuer (OIDC); often the same as the Provider URL. |
| **NameID** | The primary subject identifier in a SAML assertion. |
| **x509 certificate** | The IdP's public signing certificate, used to verify SAML assertions. |
| **Client ID / Secret** | The OIDC application credentials the IdP issues for OpenEyes. |
| **Scope** | An OIDC request for categories of claims (e.g. `openid`, `profile`, `email`). |
| **`remote_id`** | The external identifier OpenEyes stores for an institution, used to match codes in multi-institution provisioning. |
