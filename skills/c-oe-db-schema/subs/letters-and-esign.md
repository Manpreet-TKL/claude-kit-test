# Letters, esign, signatures (volatile schema)

## Letter body

- `et_ophcocorrespondence_letter` / `ElementLetter` — HTML body. TinyMCE on the way in, sanitised with HTMLPurifier, written back to PDF via Puppeteer (`DocumentRenderServicePuppeteer`) or TCPDF.

## Macros and snippets

- `LetterMacro` rows — scoped per `Firm`, `Site`, `Subspecialty`, `Institution`.
- `LetterString` / `FirmLetterString` — stringy snippets composing address / sign-off blocks.

## Recipients and enclosures

- `LetterRecipient`, `LetterEnclosure`.

## Shortcodes

Each module declares `shortcodes/` handlers that expand `[patient.last_name]`-style placeholders in letter bodies. Resolved at print time.

## Esign

Every event type that needs signature has an `Element_<Module>_Esign`:

- `OphCoCorrespondence_Esign`
- `Cvi_Esign`
- `Prescription_Esign`
- `Consent_Esign`

Backed by `BaseSignature` and `BaseEsignElement`. PIN-based signing supported via `UserPincode`, `SignatureHelper`, `PinSignaturePermissionValidator`.

## Delivery

- `CorrespondenceEmailCommand` — sends emailed letter copies (cron).
- `DocManDeliveryCommand` / `DocmanRetriever` — external document handoff.
- `InternalReferralDeliveryCommand` — internal referral routing.
- Letter PDFs are written to `protected/files/` (bind-mounted, see `c-oe-components`).
