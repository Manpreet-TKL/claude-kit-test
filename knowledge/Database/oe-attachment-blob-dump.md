# Will migrated attachment blobs still be readable?

Evidence for two questions about `attachmentDataBlobDump`:

1. after the dump moves `blob_data` onto disk as a `ProtectedFile` and `verifyAndClean` nulls the in-row copy, will every attachment still be served?
2. `attachment_type = 'NONE'` rows are the ones carrying blobs. Are they from a different source, such that they may not work as ProtectedFiles?

Verdict: **yes, they will still be read, and `attachment_type` has nothing to do with it.** `NONE`-typed attachments already exist as ProtectedFiles today, served by the same code, and the application itself already runs this very command on render to convert blob rows one at a time. The migration does in bulk what the UI does lazily.

All references are to the running application source read out of the web container, not the host checkout.

---

## 1. `attachment_type` is a clinical document-type label, not a source or a storage discriminator

`attachment_data.attachment_type` is a `varchar` FK into the `attachment_type` lookup. That lookup is a list of document kinds a user picks from a dropdown:

```
3D Macula Report, Biometry Report, B SCAN Images, Consent Form, Fundus Images,
Generic Document, Lids Photo, OCT Images, Visual Field Images, ... , NONE
```

`NONE` is a literal member of that lookup with `title_short = 'None'`. It means "no document type was recorded against this attachment", nothing more. The column is `NOT NULL` with no default, so every writer must put *something* in it, and every writer that has no document type to record puts `NONE`.

Writers, all with the type they set:

| Writer | `attachment_mnemonic` | `attachment_type` set to |
|---|---|---|
| `EventAttachmentHandler::saveFileAttachment()` | file attachment | the value the user chose in the dropdown |
| `EventAttachmentHandler::saveLinkAttachment()` (`:225`) | link | `AttachmentType::ATTACHMENT_TYPE_NONE` |
| `BaseRequestHandler::addQueryString()` | `REQUEST_DATA` | `"NONE"` |
| `BaseRequestHandler::addFormData()` | `FORM_DATA` | `"NONE"` |
| `BaseRequestHandler::addHeaderData()` | `HEADER_DATA` | `"NONE"` |
| `SingleRequestHandler` (`:26`) | `REQUEST_BLOB` | inherited `"NONE"` |
| `FormDataHandler` (`:32`) | `REQUEST_BLOB` and siblings | inherited `"NONE"` |

So `NONE` is not a source. It is the absence of a label, and it is what the API ingest path always writes because that path has no dropdown to read a document type from. The actual source discriminator is **`attachment_mnemonic`**.

## 2. There is exactly one payload read path, and it is storage-agnostic

`protected/modules/Api/modules/Request/models/AttachmentData.php:276`

```php
public function getFileContents()
{
    if ($this->blob_data) {
        return $this->blob_data;
    }

    if ($this->protected_file_id) {
        return $this->protected_file->get();
    }

    return null;
}
```

In-row blob first, ProtectedFile second. Nulling `blob_data` on a row that has `protected_file_id` moves it from the first branch to the second and changes nothing else. `attachment_type` is not consulted, here or anywhere in the read path.

## 3. Every consumer of attachment content goes through that method

Complete inventory of `getFileContents()` callers:

| Caller | What it does |
|---|---|
| `Api/controllers/v1/AttachmentDisplayController.php:84` | the endpoint the frontend uses to display an attachment |
| `Api/controllers/v2/AttachmentDataController.php:350` (`echoBlobContent`) | the v2 API download |
| `Api/.../RequestAdmin/controllers/AttachmentDataController.php:74` | the admin download |
| `BaseEventTypeController.php:3366` | `readImageBlob()` for PDF rendering |
| `Api/.../models/Request.php:202` and two RequestAdmin views | size display only |

Every other reference to `blob_data` outside the dump command is one of three harmless kinds, verified by sweeping the whole tree:

- **existence tests** - `if ($attachment->blob_data || $attachment->protected_file_id)` (`Request.php:201`, `AttachmentDataController.php:331`, `manual_upload.php:120`, `request/index.php:84`). All already treat a ProtectedFile as equivalent to a blob.
- **length arithmetic** - `AttachmentDataController.php:340-344`, which falls back to `filesize()` on the ProtectedFile when `blob_data` is null.
- **writes of `null`** - the ingest handlers.

**No consumer reads `blob_data` for content.** There is no code path that would go dark when the column is emptied.

## 4. `NONE`-typed attachments are already served as ProtectedFiles today

From the stock sample database, grouped by mnemonic, type and mime:

| mnemonic | attachment_type | mime_type | rows | with blob | with protected_file |
|---|---|---|---|---|---|
| `REQUEST_BLOB` | **NONE** | application/dicom | 134 | 0 | 4 |
| `event_pdf` | **NONE** | application/pdf | 4 | 0 | 4 |
| `event_pdf` | Visual Field Images | application/pdf | 112 | 0 | 112 |
| `event_pdf` | Biometry Report | application/pdf | 7 | 0 | 7 |
| `event_pdf` | Radial Report | image/png | 7 | 0 | 7 |
| `DICOM_HEADER` / `HEADER_DATA` / `REQUEST_DATA` / `event_data` | NONE | application/json | 134 each | 0 | 0 (text_data) |

Two rows of this table answer the question on their own:

- `REQUEST_BLOB` / `NONE` / `application/dicom` - the exact class of row that historically held the blobs - **already carries `protected_file_id` and no blob**.
- `event_pdf` / `NONE` / `application/pdf` - a `NONE`-typed attachment served entirely from a ProtectedFile.

A `NONE`-typed row that "may not work as a ProtectedFile" is falsified by `NONE`-typed rows that already *are* ProtectedFiles and display correctly.

Reproduce with one query:

```
docker exec -i <db-ctr> mariadb -A openeyes -t -e "SELECT attachment_mnemonic, attachment_type, mime_type, COUNT(*) rows_total, SUM(blob_data IS NOT NULL) with_blob, SUM(protected_file_id IS NOT NULL) with_pf FROM attachment_data GROUP BY 1,2,3 ORDER BY rows_total DESC"
```

## 5. Today's ingest already writes ProtectedFiles, so the dump produces the current row shape

`Api/controllers/v2/AttachmentDataController::populateAttachmentDataFromData()` (`:280`):

```php
$is_blob_data = self::isMimeTypeBlob($attachment_data->mime_type);

if ($is_blob_data) {
    $attachment_data->text_data = null;
    $attachment_data->blob_data = null;
    $protected_file = $this->createProtectedFile($form->raw_data, $attachment_data->mime_type);
    $attachment_data->protected_file_id = $protected_file->id;
```

A binary payload arriving through the API today is written straight to a ProtectedFile with `blob_data` explicitly nulled, and `attachment_type` comes from the form, which for this path is `NONE`. That is *precisely* the row the dump command produces from a legacy blob row. Migrated rows are therefore not a new shape being introduced into the system; they are the shape the system has been producing for new data all along.

## 6. The application already runs this command itself, on render

The strongest evidence. Both attachment-display widgets convert blob rows to ProtectedFiles at display time:

`EventSupport/widgets/EventAttachmentSection.php:56`

```php
$this->attachments->each(function ($attachment) {
    if (!$attachment->protected_file_id && $attachment->isBlob()) {
        AttachmentData::generateProtectedFileFromBlobData($attachment);
        $attachment->refresh();
    }
});
```

`OphGeneric/widgets/Attachment.php:44` does the same, then builds its display resource from the result.

And `AttachmentData::generateProtectedFileFromBlobData()` (`AttachmentData.php:289`) is a wrapper that shells into **this very command**:

```php
$args = array('AttachmentDataBlobDumpCommand.php', 'attachmentDataBlobDump', 'byAttachmentId', '--attachment_id=' . $attachment_data->id);
$runner->run($args);
```

Two consequences:

1. the conversion the bulk dump performs is the same conversion the UI has been performing per-attachment, in production, on every page view of an unmigrated blob attachment. Its output is known-good by construction.
2. for the modern event-attachment display path a ProtectedFile is not merely acceptable, it is **required**. `AttachmentResource::setAttributesForFile()` (`AttachmentResource.php:128`) reads `$attachment_data->protected_file->getPath() / description / id / viewURL / title / name` with **no blob fallback at all**. That is why the widgets convert eagerly in `init()` before building resources.

Migrating is therefore not a risk to the read path. It is a precondition of it, paid up front in bulk instead of one row at a time on a user's page load.

## 7. Mime type and file naming survive the move

`AttachmentDataBlobDumpCommand.php:496`

```php
$extension = $this->getExtension($attachment['mime_type']);
$file_name = $attachment['upload_file_name'] ?: $attachment['id'] . '_blob.' . $extension;
...
$file = ProtectedFile::createForWriting($file_name);
$file->mimetype = $mime_type;      // copied verbatim from attachment_data.mime_type
$file->put($blob_data);
```

`ProtectedFile::createForWriting()` (`ProtectedFile.php:83`) only generates the uid and creates the shard directory - it never infers a mime type from the name, so a synthetic `<id>_blob.pdf` filename on a DICOM cannot mislabel it. The mime type is then taken from the ProtectedFile in preference to the row by both serving endpoints:

```php
$mime_type = $attachment_data->protected_file->mimetype ?? $attachment_data->mime_type;
```

(`AttachmentDisplayController.php:85` and `AttachmentDataController.php:337`.) This is the same assignment the live v2 ingest makes, so `Content-Type` is identical before and after.

## 8. The frontend already asks for the ProtectedFile, and the parameter is ignored anyway

`OphGeneric/widgets/js/Attachment.js:8`

```js
function createSingleView(id, mime_type) {
    let src = `/Api/v1/attachmentDisplay/view/id/${id}?attachment=protected_file_id&mime=${mime_type}`;
```

The URL hardcodes `attachment=protected_file_id`. Several call sites still pass a third `"blob_data"` argument (`Attachment.js:168,272,288`, `request/index.php:396`) but `createSingleView` takes only two parameters, so it is discarded before the URL is built. And the receiving action is `public function actionView($id)` - it never reads an `attachment` parameter in the first place. The parameter has been inert since `49ffa052ff` (`OE-15491 - API endpoints for PayloadProcessor`).

There is no way for the frontend to demand the in-row blob.

---

## What would actually break a read, and how the command guards it

The risks are real but none of them are about `attachment_type`.

| Risk | Guard |
|---|---|
| The file is not written correctly | `--verify_file_content=1` re-reads the file and compares byte-for-byte against the blob before commit; a mismatch rolls the transaction back (`AttachmentDataBlobDumpCommand.php:624`). **Default is off** - turn it on for the migration run. |
| The blob is nulled before the file exists | Two separate phases. `index` only writes files and sets `protected_file_id`; nothing is nulled until `verifyAndClean`, which re-verifies each row (`fileExists()` plus a content compare) and skips and records any row that fails. |
| **The file store is not backed up or restored with the database** | Not guarded, and this is the one that matters. `ProtectedFile::get()` reads from disk. After migration the bytes live under `protected/files/`, sharded by uid. Any restore, clone or DR plan that copies the database but not the file store will serve nothing - and unlike today, there is no in-row copy to fall back on. This needs confirming with whoever owns the backup job before the blobs are cleaned. |
| Disk headroom during the run | `index` leaves two copies of every attachment (on disk and in-row) until `verifyAndClean` runs. Peak usage is roughly double. |

## Scope of this proof

Established by reading the running source and querying the sample schema. Not established here:

- that the file store is included in the client's backup and DR process (item 3 above - a question for the DBA, not the code);
- behaviour of any client-specific module not present in this checkout;
- that a given install's existing `protected_file` rows all still resolve on disk. Worth a spot check before migrating: a database restored without its file store will already have dangling ProtectedFiles, and the migration would add more.
