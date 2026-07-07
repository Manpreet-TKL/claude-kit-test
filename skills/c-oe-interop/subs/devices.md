# Medical / imaging device integrations

Two patterns: **desktop launcher** integrations (FORUM, ImageNET) that open a local viewer in the current patient context, and **contextual web-link** integrations (HIE, CITO) that open an external system's record for the current patient.

## Zeiss FORUM (PACS viewer, Windows)

- Opens the current OE patient in FORUM to view its images/documents; for DICOM-based OE events (e.g. biometry) received from FORUM, can re-open the original document in FORUM.
- Requires the **OpenEyes Desktop App Launcher** (Appendix D) - it sends the command-line parameters that launch FORUM and switch patient. The **FORUM client must be installed locally** on each desktop.
- Enable: `Admin->System->Settings` -> setting **"FORUM: enable integration"** -> set **on** -> save.
- Usage: patient menu -> **FORUM** loads/switches to the current patient; on a DICOM event header, **"Open in FORUM"** opens that DICOM file. Already-running FORUM refreshes to the right patient/file.

## Topcon ImageNET 6 (web PACS, needs local viewer)

- Opens the current patient record in ImageNET 6. Web-based but still needs a local desktop viewer to integrate.
- Install/update the **OpenEyes Desktop App Launcher** (Appendix D) - keep it on the latest version (ImageNET support changed for new ImageNET limitations).
- The ImageNET desktop app must be installed to `C:\Topcon\`, which contains **`imagenet6view.bat`** (the launcher to the supplied patient/record).
- Settings (`Admin->System->Settings`):
  - **ImageNET: Enable integration** -> On.
  - **ImageNET Patient identifier type** -> the ID of the relevant type from `Admin->Core->Patient Identifier Types`; picks which hospital number is sent when a patient has several. In multi-tenant setups set this at **Institution** level, not "All Institutions".
- **Must log out and back in** for new settings to take effect.
- Usage: main menu gains **"Track patients in ImageNET"** - each new patient visited in OE launches/switches ImageNET to that patient; **"Stop tracking in ImageNET"** turns it off.

## Cerner HIE (Health Information Exchange)

- Role-based access via `Admin->Core->Users` (add an HIE user role per user). Four levels:
  - **HIE - View** (HIE Level 1, default) - basic, very limited rights to HIE data.
  - **HIE - Admin** (Level 2) - clerks/receptionists/HCA; clinical data **not** visible (not a system admin).
  - **HIE - Summary** (Level 3) - nurses/pharmacists/AHP; some limited clinical data.
  - **HIE - Extended** (Level 4) - full access to all HIE data.
- System config via env vars or `Admin->System->Settings`; **env vars override** Admin values. Setting `HIE_REMOTE_URL` **enables** the integration; clearing it disables.
  - `HIE_REMOTE_URL` - HIE instance URL, e.g. `https://uktestcert.cernerhie.org/hiempages`
  - `HIE_USR_ORG`, `HIE_USR_FAC`, `HIE_EXTERNAL`, `HIE_ORG_USER` - all provided by HIE.
- Secrets-only (Docker secrets in production; env vars test/debug only): `HIE_ORG_PASS`, `HIE_AES_ENCRYPTION_PASSWORD`.
- Usage: a contextual main-menu link on a patient opens that patient's HIE record.

## CIVICA CITO (electronic document records management)

- Needs the CITO service URL, username and password for the backend API in OE config; all access control is managed in the CITO admin interface.
- Settings (env vars override and **disable** the Admin Screen settings). Setting `CITO_BASE_URL` **enables** the integration; clearing it disables.
  - `CITO_BASE_URL` = `https://<CITO server url>`
  - `CITO_APPLICATION_ID` - must match the application ID in CITO, e.g. `OPENEYES`
  - `CITO_CLIENT_ID` = `Civica.Cito.ExternalIntegration.WebApi`
  - `CITO_CLIENT_SECRET` - shared secret from CITO
- Usage: contextual main-menu link opens the current patient's CITO record, **single-sign-on as the logged-in OE user** (done in the backend). Users must have the **same Windows credentials** for OE and CITO.
