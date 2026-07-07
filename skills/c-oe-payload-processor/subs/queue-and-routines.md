# PayloadProcessor - queue model & JavaScript routines

## Status model

`utils/Status.java`: `NEW, RETRY, COMPLETE, FAILED, PAUSE, VOID` (stored as
`EnumType.STRING` in `request_routine.status`). `PAUSE` is defined but unused.

## Poll query - strict in-order per request

Named native query `routinesWithRequestQueueRestrictionForProcessing`
(`models/RequestRoutine.java:25-37`):

```sql
SELECT * FROM request_routine rr
WHERE rr.execute_request_queue = :request_queue
  AND rr.status IN (:new_status, :retry_status)
  AND IFNULL(rr.next_try_date_time, SYSDATE()) <= SYSDATE()
  AND NOT EXISTS (
    SELECT * FROM request_routine subrr
    WHERE subrr.request_id = rr.request_id
      AND subrr.execute_sequence < rr.execute_sequence
      AND subrr.status NOT IN (:complete_status, :void_status))
ORDER BY rr.id
```

The `NOT EXISTS` clause is the key invariant: a routine is eligible only when
**every lower-`execute_sequence` routine for the same `request_id` is already
`COMPLETE` or `VOID`** - so routines for one request run strictly in sequence,
while different requests run in parallel. The worker uses a twin query that also
filters `rr.request_id = :request_id` to pull its own request's next routine.

## Retry backoff & locking

- **Backoff** (`utils/RequestRoutineNextTryTimeCalculator.java`, via
  `RequestRoutine.failedExecution`): by `try_count` - try 0-4 -> `now + 120*tryCount`
  s; try 5-12 -> +30 min; try 13-19 -> +360 min; **try >=20 => `null` => status
  `FAILED`** (no further retry).
- **Optimistic locking:** `request_routine` is `@OptimisticLocking(DIRTY)` +
  `@DynamicUpdate`; a concurrent change throws `OptimisticLockException`, caught by
  the worker, which rolls back and re-runs later.
- New runtime-added routines get `execute_sequence += 10` (or +1 if priority).

## Routine library / JavaScript model

- **Routines are plain JS files** (no extension) under
  `src/main/resources/routineLibrary/` (~74 of them), baked into `/routineLibrary`
  in the image. The DB `routine_library` table holds only `(routine_name,
  hash_code)` - it's an **index of which scripts exist, not the bodies**. Bodies
  are read off disk at execution time (`RoutineScriptAccessor`).
- **Sync is insert-only** (`RoutineLibrarySynchronizer`): edited scripts keep a
  stale hash; deleted scripts leave orphan rows. To pick up edits, restart the
  container or lower `SYNCHRONIZE_ROUTINE_DELAY` - the practical effect of a
  restart is simply re-reading bodies from disk. Override `/routineLibrary` with a
  bind volume to use custom scripts.
- **Wrapping:** every routine = `preScript/functions` + the routine +
  `postScript/save`. The bound Java object `RoutineScriptService` is exposed so the
  routine calls its public methods as if they were global functions.

### What a routine can call (`RoutineScriptService` public methods)

- **Attachment I/O (REST):** `bindTextObject`, `getTextIfNullReturnEmptyJson`,
  `getAttributes`, `putText`, `putBlob`, `setAttachmentType`.
- **DICOM / blobs:** `getDicomParser`, `getDicom`, `getBlobData`.
- **Routine chaining:** `addRoutine`, `addRoutineIfExists`,
  `addRoutineWithFallbackRoutine`, `addPriorityRoutine`, `voidAllNewRoutines`.
- **Patient / events:** `getPatientId` (PAS search), `createEvent` (-> DataAPI
  direct SQL), `linkAttachmentDataWithEventNewGroup`,
  `insertEventSubtypeIfDoesNotExist`, `updateEventServiceFirmToEpisodeFirm`,
  `patientHasEpisodes`, `eventIsDeleted`.
- **OCR / PDF:** `readTextFromImage`, `readTextFromPdf`, `readTextFromPdfScraping`.
- **Documents:** `searchDocument`, `createDocument`, `updateDocument`.
- **Misc:** `updateRequestDetails`, `synchronizedJavaSubroutine` (DB-row mutex via
  `request_routine_lock`), dedup/cleanup helpers.
- Pure-JS helpers in `preScript/functions`: XML/XPath `XmlNode` wrappers, `clone`,
  `isEmpty`, `bindBinary`/`getBinary`, `extractHospitalNumber`,
  `getDefaultVariableValue`, `correctOcrNumberDecimalPlace`, etc.

### Save model

`postScript/save` flushes everything pushed onto `bindedObjects`: JSON via
`putText`, blobs via `putBlob`; if `REQUEST_DATA` changed, `updateRequestDetails`
is called.

### Bundled SEED routines

Per-modality entry points: `DICOM_SEED`, `OCT_SEED`, `XML_SEED`,
`GENERIC_PROCESSING_SEED`, `GENERIC_EXTRACT_PDF`. `DICOM_SEED` maps DICOM header
tags -> `REQUEST_DATA` then dispatches to a manufacturer routine by
`requestData.manufacturer` (`Carl_Zeiss_Meditec_*`, `Heidelberg_Engineering*`,
`TOPCON*`, `OPTOS*`, `Triton*`, `Haag-Streit_AG*`, `Konan_Medical*`, `Kowa`,
`OCULUS_*`, fallback `GENERIC_PROCESSING_SEED`). Event-creation: `create_event`,
`create_image_event`, `create_hfa_event`, `create_assessment_event`,
`INSERT_EVENT_SUBTYPE`. Linking/cleanup: `link_attachment_with_event(_new_group)`,
`link_oct_image_with_event`, `delink_attachment`, `*_CLEAN_UP`. OCR:
`Clinical_Photograph_OCR`, `3D_Macula_Report_OCR`, `Radial_Report_OCR`, etc.
