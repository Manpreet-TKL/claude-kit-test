# Identifier, settings, and lookup tables (volatile schema)

Tables that look secondary but quietly drive a lot of behaviour.

## Patient identifiers

- `PatientIdentifier` — the modern identifier rows.
- `PatientIdentifierType` — the type taxonomy (NHS num, hospital num, MRN, study ID, …).
- `PatientIdentifierStatus` — active / merged / withdrawn.
- `PatientIdentifierHelper` (component, not a table) — resolves "the hospital number for site X" without hard-coding columns. **Always go through the helper.**
- Legacy `patient.hos_num` and `patient.nhs_num` are kept for read-back compatibility but should not be the source for new code.

## Settings

- `Setting` (and `SettingMetadata`) — the settings master table. Backed by `BaseSetting` AR.
- `settingCache` component caches reads; clear by invalidating the APCu key (see `c-oe-code`).
- Settings are typically scoped per `Institution` (`SettingInstallation`, `SettingInstitution`, `SettingUser`, etc. — exact set drifts; grep first).

## Authentication wiring

- `UserAuthenticationMethod` — selects local password, LDAP/PIN, SAML, OIDC for a given user-institution pair.
- `InstitutionAuthentication` — per-institution config (which methods are enabled, defaults, sweep policy).
- `UserPincode` — per-user PIN for clinic-touchscreen PIN-only login.
- `SSO` module + `params.SAML_settings` / `params.OIDC_settings` (in config, not DB).

## Lookups (the long tail)

Most lookup tables follow `<name>` / `<name>_lookup` / `<name>_type` conventions. Common ones:

- `EthnicGroup`, `Gender`, `Title`, `CountryCode`.
- `EpisodeStatus`, `EventType`, `EventSubtype`.
- `Allergy*`, `Medication*`, `Disorder*` (see `diagnoses-allergies-medications.md`).
- `LetterMacro` family (see `letters-and-esign.md`).
- `BaseTree` + `TreeBehavior` underpin the hierarchical lookups (subspecialty trees, procedure trees, …); `BuildTreeCommand` rebuilds.

## Custom-deployment add-ons

A deployment can add tables via its own custom-deployment modules listed in `/config/modules.conf`. **Custom modules carry their own migrations** — they're not in core. Look in `protected/modules/<DeploymentName>*/migrations/`.
