# OpenEyes DocMan delivery

Read this before changing correspondence delivery configuration, the DocMan cron,
`DocManDeliveryCommand`, or the meaning of a letter's delivery status. This note was
traced against OpenEyes `develop` at `9d6f524ac23b826db3c58c00596471127828989d`
on 2026-08-25 by reading the command, models, templates, configuration, cron wrapper,
and unit tests. It describes the current implementation, including behaviours that
are not apparent in the frontend.

## 1. What "DocMan delivery" means here

OpenEyes does not call a DocMan API. It renders a final correspondence event as files
and copies those files into configured folders. Another service can then collect them.
The same delivery command also handles the `Electronic` and `Internalreferral` output
types when the institution has matching delivery rules.

There are two distinct halves:

1. OpenEyes selects eligible document outputs, renders their content, and creates one
   file plus one copy script for every matching delivery rule.
2. The wrapper runs the generated copy scripts, which copy the files to their final
   folders and move the successful source files and scripts to `complete/`.

The distinction matters because the document output is marked `COMPLETE` at the end of
the first half. That happens before the destination copy runs. A `COMPLETE` output, shown
as sent in the clinical interface, therefore proves that OpenEyes generated the delivery
artifacts. It does not prove that the destination received them.

## 2. The end-to-end flow

    clinician finalises correspondence
      -> one document target per recipient
      -> one or more document outputs per target
      -> eligible outputs enter PENDING, or PRINTED for an Electronic print path

    scheduled docmandelivery.sh
      -> yiic docmandelivery
      -> visit every active institution with delivery configurations
      -> select eligible document outputs for that institution
      -> sign in to the local OpenEyes web application as the DocMan service user
      -> request the correspondence PDF for the exact recipient target
      -> reject content whose first four bytes are not %PDF
      -> make PDF, optional XML, and optional RTF delivery artifacts in pending/
      -> duplicate each artifact once per matching delivery rule
      -> make one _copy.sh file per duplicate
      -> mark the document output COMPLETE
      -> run pending/do_copy.sh
      -> each _copy.sh uses sudo cp to copy its file to the configured destination
      -> on success, move the source file and _copy.sh to complete/
      -> on failure, leave both in pending/ for investigation
      -> delete complete/ artifacts older than seven days

The database, the staging directory, and the destination folder are therefore three
separate sources of evidence. Check all three when investigating delivery.

## 3. The document records involved

| Record | Meaning |
|---|---|
| `document_instance` | The rendered-document container associated with the correspondence event. |
| `document_target` | One intended recipient, including To or Cc, contact type, address, and email. |
| `document_output` | One delivery method and status for that recipient, such as Docman, Electronic, or Internalreferral. |
| correspondence delivery configuration | An institution-specific rule that maps an output type and content type to a relative path and filename mask. |

A letter can have several recipients, each recipient can have several outputs, and an
output can match several delivery rules. Do not assume one correspondence event produces
one file.

The implemented output types are:

| Stored output type | Intended route |
|---|---|
| `Print` | User printing workflow. |
| `Email` | Immediate email workflow. |
| `Email (Delayed)` | Retry or delayed email workflow. |
| `Internalreferral` | File delivery for an internal referral recipient. |
| `Docman` | File delivery, normally for the GP recipient. |
| `Electronic` | File delivery for electronically printed correspondence. |

The implemented output statuses are `DRAFT`, `SENDING`, `PENDING`, `PENDING_RETRY`,
`FAILED`, `COMPLETE`, and `PRINTED`. These are processing states, not an end-to-end
receipt from the receiving system.

## 4. What the normal command selects

`DocManDeliveryCommand::actionIndex()` loops through every active institution. It only
does work for an institution that has correspondence delivery configurations.

For each such institution it enables the output types for which that institution has
rules, then selects:

- `Docman`, `Internalreferral`, and/or `Electronic` outputs according to the enabled
  delivery rules;
- outputs in `PENDING` status;
- `Electronic` outputs in `PRINTED` status as well, when Electronic delivery is enabled;
- correspondence whose event is neither deleted nor awaiting deletion; and
- correspondence whose Letter element is not a draft.

Consequences that are easy to miss:

- A rule for one institution does not enable that output type for another institution.
- Draft letters and deleted events are deliberately skipped.
- `FAILED` and `PENDING_RETRY` outputs are not selected by the normal command.
- A DocMan output without a DocMan rule for its institution is not delivered.
- Electronic delivery is the exception that accepts a `PRINTED` output as input.

## 5. Rendering the recipient's version of a letter

`DocmanRetriever` signs in to the local OpenEyes web application with the configured
DocMan service user. It sets the event's institution and site cookies, then requests the
Correspondence PDF-print route with the exact `document_target_id`.

That target is important. The PDF can vary by recipient, and the delivery configuration
can use recipient details in its filename or XML. Rendering the event without respecting
the target can send the wrong recipient version.

For the `Docman` output type the command also asks for the GP-only print form. Other
delivery output types do not set that GP-only flag.

The retrieved body must begin with `%PDF`. If it does not, the command marks that
document output `FAILED` and creates no normal PDF delivery artifacts for it. An HTML
login page, an application error page, or an empty response can therefore appear to the
command as "not a PDF" even when the root problem is authentication or the local web
route.

The service user is machine-local configuration. Never put its password in this kit or
in a documentation repository.

## 6. Files, rules, and filenames

The export root comes from `OE_DOCMAN_EXPORT_DIRECTORY`, exposed to the application as
`docman_export_dir`. The default is `/docman`.

The command creates and uses:

| Location | Purpose |
|---|---|
| `<export-root>/pending/` | Generated delivery files and their per-file copy scripts. |
| `<export-root>/pending/do_copy.sh` | Finds and runs the generated copy scripts. |
| `<export-root>/complete/` | Successful source files and copy scripts retained for seven days. |
| a rule's configured relative path | Final handoff location under the export root. |

Each internal working name includes the institution id, event id, document output id,
and delivery rule id. That prevents two outputs for the same event, or two rules for the
same output, from overwriting each other while pending.

The final destination filename is built from the rule's filename mask. Supported tokens
include:

| Token | Value |
|---|---|
| `{prefix}` | `Internal` for an Internalreferral output, otherwise empty. |
| `{patient.hos_num}` | The patient identifier selected for the event's institution and site. |
| `{event.id}` | Correspondence event id. |
| `{random}` | Random value used by the base delivery filename builder. |
| `{gp.nat_id}` | GP national identifier, when present. |
| `{event.last_modified_date}` | Event last-modified date. |
| `{document_output.id}` | Document output id. |
| `{date}` | Current date. |
| `{recipient.output_type}` | The selected output type. |
| `{recipient.to_or_cc}` | Whether the target is To or Cc. |

The base command also accepts its supported custom date-format form. Treat the mask as
operational configuration: a change can affect downstream matching and duplicate-file
handling even though the letter itself is unchanged.

Configured rule paths are forced to be relative to the export root by stripping leading
`/`, `./`, and `../` fragments. The script comment also requires destination folders to
live under the export root and be available through the deployment's mounted DocMan
folder.

## 7. PDF, XML, RTF, and CSV

PDF is the rendered correspondence. Each matching PDF delivery rule gets its own copy.

XML is generated only when the institution has a matching XML delivery rule for that
output type. The template is chosen per institution by the
`correspondence_xml_template` setting, with `default.php` as the fallback. Alongside the
general patient, identifier, GP, practice, event, and subspecialty data, correspondence
XML can include:

- letter type and site;
- target service, consultant, and location;
- urgency and same-condition flags;
- the linked PAS visit id, when a worklist assignment exists;
- output type;
- whether the recipient is the primary To recipient; and
- the recipient contact type.

The selected XML template decides which available values are emitted. Tests explicitly
cover template variants that include recipient type and To/Cc information.

RTF generation is enabled by `RTF_HOSTNAME`. It calls a separate conversion service
after the PDF-render login has established `/tmp/cookie.txt`. A non-200 response stops
processing that output. RTF generation does not replace the PDF route.

An institution can also enable `correspondence_create_csv`. The command then opens a
dated institution CSV and records a row after each output is marked complete. Fields
include the local patient identifier, clinician, letter type, created/finalised/sent
dates, and last significant event date. This is an audit extract, not proof of the final
copy or downstream import.

## 8. The copy boundary and the misleading COMPLETE state

For every rule, the command makes a duplicate artifact and a small `_copy.sh`. That
script runs `sudo cp` from `pending/` to the final path.

On a successful copy it moves the source duplicate and its script to `complete/`. On a
failed copy it logs an error and leaves both files in `pending/`.

Only after creating the artifacts and scripts, but before `do_copy.sh` is invoked by the
wrapper, `DocManDeliveryCommand` changes the `document_output` to `COMPLETE`. The frontend
can label this as sent. Therefore:

| Evidence | What it proves |
|---|---|
| output is `COMPLETE` | OpenEyes reached its completion update after generating artifacts. |
| artifact and `_copy.sh` remain in `pending/` | The destination copy has not completed successfully, or the copy runner has not run. |
| artifact and script are in `complete/` | The generated `sudo cp` returned success. |
| file exists in the destination | The handoff folder received a file. |
| receiving system has imported it | Only that receiving system can prove this final step. |

Do not reset a `COMPLETE` record merely because a destination is empty. First inspect
`pending/`, `complete/`, the cron log, rule path, mount, permissions, and receiving
system. Re-running generation without understanding the existing artifacts can create a
duplicate handoff.

## 9. Scheduling and manual commands

The deployment schedules `protected/scripts/docmandelivery.sh` only when
`OE_DOCMAN_EXPORT_DIRECTORY` is non-empty. The default schedule is controlled by
`CRON_DOCMANDELIVERY_SCH`, whose default is `00 21 * * *`. The cron runs in the
deployment's scheduled-job or manager container, not necessarily in the web container.

The wrapper first runs the Yii command, then changes to `pending/` and runs
`do_copy.sh`:

    php protected/yiic docmandelivery

The Yii help also exposes a targeted generation action:

    php protected/yiic docmandelivery generateone --event_id=<event_id>

It accepts an optional `--path=<path>` override in the command implementation.

`generateone` is a diagnostic and repair tool, not an exact simulation of the scheduled
selection. It loads all matching DocMan, Electronic, and Internalreferral outputs for the
event after the institution's delivery types are enabled, without applying the normal
status filter. It still excludes deleted or delete-pending events and draft letters. It
can therefore regenerate an already complete or failed output and can create duplicate
handoffs if used carelessly.

Run Yii commands inside the appropriate application container. For example:

    docker exec <web-container> php /var/www/openeyes/protected/yiic help docmandelivery

    docker exec <web-container> php /var/www/openeyes/protected/yiic docmandelivery generateone --event_id=<event_id> --path=/safe/diagnostic/path

The targeted command generates artifacts. It does not by itself invoke
`pending/do_copy.sh`. Use a non-production diagnostic path when the aim is to inspect
rendering without handing a file to another system.

## 10. Configuration dependencies

The feature crosses deployment configuration, institution settings, admin configuration,
the database, and local HTTP authentication.

| Dependency | Why it matters |
|---|---|
| `OE_DOCMAN_EXPORT_DIRECTORY` | Enables scheduling and defines the shared export root. |
| `OE_DOCMAN_USER` and its password | Let the retriever render through the application as a service user. |
| correspondence delivery configurations | Enable output types per institution and define content type, path, and filename mask. |
| institution XML template setting | Selects the XML shape for that institution. |
| mounted destination directories | Make final paths visible to the cron container and the receiving integration. |
| filesystem and `sudo` permissions | Allow staging, copying, and moving artifacts. |
| local login and PDF-print URLs | Let the command authenticate and retrieve recipient-specific output. |
| certificate-check setting | Controls TLS verification for the local request. Disable only when the deployment genuinely requires it. |
| scheduled-job container | Actually invokes the wrapper on the configured schedule. |

Other relevant application settings include the filename format, XML-generation defaults,
XML template, sending-method label, and optional CSV setting. The current delivery command
ultimately decides whether to make XML from the institution's delivery configurations,
so do not infer runtime behaviour from an environment variable name alone.

## 11. A practical investigation order

When a letter appears not to have arrived:

1. Confirm the correspondence is final, the event is not deleted or delete-pending, and
   the recipient has the expected output type.
2. Confirm the event's institution is active and has a matching delivery configuration
   for that output type and content type.
3. Check the document output status. `PENDING` means it may still be selectable;
   `FAILED` commonly means the retriever did not return a PDF; `COMPLETE` is only the
   OpenEyes generation boundary described above.
4. Inspect `pending/` for the artifact and its `_copy.sh`. A retained pair points to the
   copy boundary, destination path, mount, or permissions.
5. Inspect `complete/` and the cron log. Remember that completed staging evidence is
   retained for only seven days.
6. Check the final configured folder and filename mask.
7. Ask the receiving system whether it imported or rejected the file. That state is not
   represented by `document_output`.
8. Use `generateone` only after deciding whether regeneration is safe. Prefer an isolated
   path when testing the render itself.

For an invalid-PDF failure, check local login, service-user access, institution/site
context, the PDF-print route, TLS behaviour, and whether the response is an HTML error.
For files stuck in `pending/`, inspect the generated script before running anything: it
contains the exact source and destination paths that the command chose.

## 12. Source map

| Concern | Source |
|---|---|
| selection, rendering, XML/RTF/CSV, status updates, copy scripts | `protected/commands/DocManDeliveryCommand.php` |
| filename tokens and general XML data | `protected/commands/BaseDeliveryCommand.php` |
| local sign-in and recipient-specific PDF retrieval | `protected/components/DocmanRetriever.php` |
| scheduled wrapper and invocation order | `protected/scripts/docmandelivery.sh` |
| output types and status transitions | `protected/models/DocumentOutput.php` |
| recipient fields and types | `protected/models/DocumentTarget.php` |
| default environment and cron configuration | `protected/config/common.php` and deployment cron configuration |
| institution delivery rules | Correspondence delivery configuration models and admin forms |
| executable behaviour examples | `protected/tests/unit/commands/DocManDeliveryCommandTest.php` |

The unit tests confirm pending DocMan delivery, targeted generation, invalid-PDF failure,
Internalreferral delivery, Electronic delivery from `PRINTED`, multiple outputs for one
event, recipient XML fields, and the exclusion of deleted and draft events. They stop at
artifact and script creation; they do not prove an external DocMan import.
