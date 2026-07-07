# Correspondence, discharge, referrals, document upload

Two distinct directions here:
- **OUT** - OE produces letters / discharge summaries / internal referrals as PDFs for downstream document-management systems.
- **IN** - third parties push documents *into* OE as document events (PASAPI v2).

## Correspondence & electronic discharge summaries (OUT)

- All OE letters can be output to a designated network folder as **PDF + metadata**, consumable directly or via the integration engine. Compatible with most document-management/delivery systems (e.g. Docman).
- Metadata is supplied by one or both of:
  - **Encoded filename**, e.g. `<hospital number>_<letter_type>_<Letter ID>_<date/time>.pdf` (format customisable).
  - **Sidecar XML** with the same base name as the PDF.
- Detail: Appendix C - Document Management Output.

### Recipient output type configuration

`Admin->Correspondence->Recipient Output Types`. Choose a recipient type and an institution scope (or the installation-wide "all institutions" fallback, which is the default on first open). For the chosen recipient type you can enable each available output type and set whether it is **selected/checked by default**.

### Correspondence delivery configuration

`Admin->Correspondence->Delivery Configurations`. Lists delivery configs (for **Docman** and **Electronic** output types) with their settings and test results, scoped to an institution (defaults to current). Add/delete/test configs (individually or all). A config specifies: output type it applies to, content type, a **filename mask** (templated filename), and an optional **path** that acts as a child directory under the export directory set in the relevant environment variable.

## Internal referrals (OUT)

A special correspondence letter type. Behaves like correspondence/discharge output, but the **XML metadata carries referral fields** (referrer source, referee destination, urgency, etc.). Authored in the front end by creating a Correspondence event with letter type **Internal Referral**.

## Document upload into OE (IN) - PASAPI v2

- Requires **PASAPI Version 2**, first available in **OpenEyes 7.0**.
- The event lands in an existing episode if one exists, else a new episode, depending on the **firm** chosen for the document.
- Default context can be set per supplier on request, but always providing context per document is best.
- To attach **two documents to one event**: reuse the same `unique_reference` with **opposing laterality**.
- Variable definitions: Appendix F.

### Transports (file drop)

- **SFTP** to the OE server.
- **SFTP** - BridgeLink picks files up from a designated location on your network.
- **SMB (CIFS)** - BridgeLink picks files up from a designated network location.

### File drop with detailed name

Filename format (note the **double-underscore** separator):
```
<patient_identifier_type>__<patient_id>__<firm_id>__<document_subtype>__<laterality>__<unique_reference>__<document_date>__<filename>.<extension>
```
Example: `LOCAL-1-0__012345__1__General__L__Doc123__20240528__Eyepic.png`

### File drop with associated XML

Drop the document plus a same-name `.xml` sidecar; the file names must be unique to each other (numeric or hash). XML fields (note the source typo `patientIdnetifierType`):
```xml
<?xml version="1.0" encoding="UTF-8" ?>
<patientIdentifierType>LOCAL-1-0</patientIdnetifierType>
<patientId>012345</patientId>
<firmId>1</firmId>
<documentSubtype>General</documentSubtype>
<laterality>L</laterality>
<uniqueReference>Doc123</uniqueReference>
<documentDate>20240528</documentDate>
```

### HL7 MDM message

Requires the **extended PAS channel**. Document goes in the **OBX** segment, **Base64-encoded**; supported message is **MDM^T02**. Key field mapping: `TXA` carries `document_date`, `unique_reference`, `<filename>.<extension>`; `OBX` carries `document_subtype^laterality^firm_id` and `^^^Base64^<document_data>`. Full worked example in `subs/appendices.md`.

Also referenced (TOC only, no body in the source guide): COMPlog integration, Concentric integration, DICOM medical-imaging-device integration (with a supported-devices list), and a Document Upload RESTful API. See `c-oe-iolmaster-import` / `c-oe-payload-processor` for DICOM/device-result importers.
