# Reference channels

Two deployable, sanitised, parameterised channel exports - one per archetype that has no
maintained template anywhere else. Read them when you need the **literal XML shape** of the
archetype; for behaviour, `subs/flows.md` and `subs/rules.md` answer far more cheaply.

Both are derived from a real estate channel with every site literal lifted into a `${VAR}`
in oe-deploy's config-catalogue style, so they are also the starting point for the
`connect-files/templates/` additions. Import them straight into BridgeLink - the declared
`version=` is the exemplar's, and Mirth upgrades an older export on import.

## Where each archetype's template lives

| Archetype | Template |
|---|---|
| PAS Inbound | oe-deploy `connect-files/templates/PAS_IN.xml` |
| PAS Outbound / Query | oe-deploy `connect-files/templates/PAS_OUT.xml` |
| DICOM Ingestion | oe-deploy `connect-files/templates/DICOM.xml` |
| Document Outbound | oe-deploy `connect-files/templates/DOCUMENT_OUT.xml`; `document-mover.channel.xml` (here) is the estate-lineage exemplar it came from |
| Document Ingestion, PayloadProcessor | oe-deploy `connect-files/templates/DOCUMENT_IN.xml` |
| PDQ / MPI SOAP | oe-deploy `connect-files/templates/PDQ_QUERY.xml`; `pdq-query.channel.xml` (here) is the estate-lineage exemplar, and carries the full `RSP^K21` response mapping the oe-deploy template does not |

All six now have a maintained secret-free template in oe-deploy, so **start there**. The two
XMLs here stay because they are the *estate's* shape rather than the deployable one - key
auth, per-board channel ids, the response-side XSLT - which is what you want when the
question is "what does the estate actually run", not "what do we ship".

## `document-mover.channel.xml`

File Reader polling a local drop directory every 5s, `DELETE` after processing, errors moved
aside; one File Writer destination pushing the bytes unchanged over **SFTP with key auth**.
No transformer, no filter - the document is never parsed. Exemplar: the four-member `Docman`
/ `DOCUMENT-OUT-*` clone family, lineage id kept.

| Variable | Meaning |
|---|---|
| `DOC_OUT_SOURCE_DIR` | local drop directory; `<dir>/error` takes failed reads |
| `DOC_OUT_HOST`, `DOC_OUT_PORT`, `DOC_OUT_REMOTE_DIR` | the remote target, concatenated into the connector's single `<host>` field |
| `DOC_OUT_USERNAME` | SFTP account |
| `DOC_OUT_KEY_FILE` | path to the private key, mounted as a secret |

Three deliberate deltas from the exemplar, all reliability, none behavioural:
`messageStorageMode` DEVELOPMENT -> PRODUCTION; destination queue off -> on;
`retryCount` 0 -> 3. The estate ships all three at their unsafe settings (`subs/flows.md`
reliability footer) and a template should not inherit that.

The exemplar authenticates by key, so the credential slot is empty rather than tokenised.
If a site needs credential auth instead, set `passwordAuth`/`keyAuth` accordingly and
tokenise `<username>`/`<password>` directly: unlike the HTTP Sender, the file dispatcher
**does** substitute its credential fields. Settled empirically on a live BridgeLink 4.6.1
by delivering a file to a real SFTP server with `${DOC_OUT_USERNAME}`/`${DOC_OUT_PASSWORD}`
in place, so no JavaScript Writer fallback is needed. oe-deploy's `DOCUMENT_OUT.xml` is the
worked version of exactly this.

## `pdq-query.channel.xml`

HTTP listener in; builds a `QBP^Q21` from the query parameters, wraps it in a SOAP envelope
by XSLT, calls a Web Service Sender, then transforms the `RSP^K21` back to OpenEyes patient
XML. Eight destinations' worth of XSLT, so it is 59 KB - read it in spans, never whole.
Exemplar: the eight-member per-health-board query family, which the corpus had already
parameterised and render-verified.

| Variable | Meaning |
|---|---|
| `CHANNEL_ID` | per-instance channel uuid - one deployment per queried authority |
| `PDQ_INSTANCE_NAME` | suffix in the channel name |
| `PDQ_LISTEN_PORT` | HTTP listener port |
| `PDQ_MPI_URL` | the MPI service endpoint (WSDL, location URI, and both cached port bindings) |
| `PDQ_SOAP_NS` | the service's SOAP namespace - a contract identifier, not an address, but it varies per service so it is tokenised too |
| `PDQ_ASSIGNING_AUTHORITY` | the querying authority's code |
| `PDQ_ARCHIVE_ENABLED` | per-instance message-archive toggle |

`PDQ_ASSIGNING_AUTHORITY` is the one that matters. It appears **twice** - once in the
`QPD-3.2` assignment in the source transformer, once as the XSLT `vSender` - and in the live
estate both are hardcoded literals. If they ever disagree the MPI answers for the wrong
authority, which is why lifting it into config is the point of this template rather than a
tidy-up. The Web Service Sender has `useAuthentication=false`, so the credential slot is
empty by design.
