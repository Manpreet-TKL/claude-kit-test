# Scheduled `yiic` commands in the master container (volatile)

The `master` container's crontab runs these. Schedule cadences drift; confirm against the deployed crontab if exact timing matters.

## Worklist generation / maintenance

- `GenerateWorklistsCommand` — builds daily worklists from definitions + attendance.
- `UpdateWorklistInstancesCommand` — keeps instances in sync as upstream data changes.
- `IVTBookingScreenCommand` — pre-builds the intravitreal injection booking screen.

## Correspondence / delivery

- `CorrespondenceEmailCommand` — sends queued email letter copies.
- `DocManDeliveryCommand` — pushes outgoing documents to the external DocMan retriever.
- `InternalReferralDeliveryCommand` — routes internal referrals.
- `PrescriptionVerificationCommand` — flags prescriptions needing pharmacy verification.

## Cleanup / housekeeping

- `ClearExpiredDraftSavesCommand` — removes old `EventDraft` autosaves.
- `ClearExpiredUserSessionsCommand` — purges expired Yii sessions.
- `CloseHotlistItemsCommand` — auto-closes stale hotlist items.
- `OldMedicationAndDrugDeletionCommand` — sweeps the legacy `Drug` → `Medication` migration.
- `ResetUserLockCommand` — clears stuck user lockouts.

## Optional integrations (enable as needed)

- `ClamScanCommand` — periodic ClamAV sweep when `OE_ENABLE_VIRUS_SCANNING=true`.
- `ProcessHscicDataCommand` — HSCIC data ingest (UK-specific).
- `CreatePatientTicketForExamsCommand` — auto-creates `PatientTicketing` queue items.

## Where the crontab lives

The `master` image installs its crontab as part of the OEImageBuilder pipeline (see `c-oeimagebuilder`). To inspect on a running host:

```sh
docker compose exec master crontab -l -u www-data
```

`master` runs the **same image stack** as `web` — the difference is the entrypoint (cron vs Apache).
