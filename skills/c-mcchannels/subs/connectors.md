# Per-channel connector configuration

Generic connector mechanics and the Velocity/auth gotcha: the `c-mirth` skill. This
sub records the concrete config of each `~/mc_channels/` channel.

## PAS IN - `7a7288a3-...`

- **Source:** TCP MLLP **Listener**, `0.0.0.0:6661`, `serverMode=true`,
  `keepConnectionOpen=true`, `maxConnections=10`. MLLP framing: SOM `0B`,
  EOM `1C0D`, ACK `06`, NACK `15`, `maxRetries=2`. Inbound HL7 v2 (non-strict).
- **Destinations:** 6 x HTTP Sender, all `PUT`/`DELETE` to `http://web/PASAPI/...`
  with `useAuthentication=true`, Basic `api` / `Password123` (the inline secret -
  templating target). Detail: `subs/pasin-processing.md`.

## PAS OUT - `06f0b8b8-...`

- **Source:** HTTP **Listener**, `0.0.0.0:6663`, auth `NONE`, `xmlBody=true`,
  `respondAfterProcessing=true` (synchronous request/response). The source
  transformer builds an HL7 **Q21** patient-query (sets `MSH.7`/`QRD.1` to now,
  `MSH.10`/`QRD.4` to the message id, and `QRD.8.1` from the `hosnum`/`nhsnum`
  query parameter). Inbound XML -> outbound HL7 v2.
- **Destination `1` Send Q21:** TCP MLLP **Sender** (`serverMode=false`) to a
  **hardcoded remote** `remoteAddress 10.157.96.169`, `remotePort 3017`. These
  should be templated `${PAS_OUT_REMOTE_HOST}` / `${PAS_OUT_REMOTE_PORT}`.
  TCP Sender `remoteAddress`/`remotePort` **ARE** Velocity-substituted (unlike
  HTTP Sender `username`/`password`, which are not), so `${VAR}` works here.
- **Destinations `4`/`5`/`6`** (Convert K21 to XML, Create response, Respond):
  JavaScript Writers that take the K21 response back from `Send Q21`, XSLT it into
  an OE `<PatientList>` (PID -> identifiers/name/DOB/address), and return it as the
  HTTP response. No outbound auth or hosts. This channel sends no OE-API call and
  contains **no `Password123`**.

## DICOM - `c14efd23-...`

- **Source:** DICOM **Listener**, `0.0.0.0:11112`, `tls=notls`. Source
  transformer maps DICOM tags (patient/study/device) to channelMap, derives
  `identifier_type` + `institution_id` by regex `(local|global)-(\d+)-(\d+)` on
  the local AET (default `LOCAL-1-0` / `configurationMap.defaultPatientIdentifierType`),
  and a `source_platform` hint (`imagenet`/`forum`/`generic`) from the AETs.
- **Destination `7` getDicomHeaders:** JS Writer, `DICOMUtil.getDICOMRawData`.
- **Destination `1` File Writer** -> `/mnt/dicom`, `outputPattern=${originalFilename}`,
  binary `${message.rawData}`. Filter: only Zeiss IOLMaster devices with the two
  supported SOP class UIDs (`1.2.840.10008.5.1.4.1.1.104.1`, `...7.4`). This is
  the IOLMasterImport feed.
- **Destination `6` PayloadProcessor API Send:** HTTP Sender,
  `POST http://web/api/v1/request/queue/add`, `contentType=application/dicom`,
  `dataTypeBinary=true`, body `${message.rawData}`. Query parameters:
  `request_type=dicom_request`, `identifier_type=LOCAL-1-0` (hardcode - template
  to `${OE_IDENTIFIER_TYPE}`), `institution_id=1`, `file_name=${originalFilename}`,
  `content_type=application/dicom`, `system_message=${local_AET}`,
  `source_platform=${source_platform}`. Basic `api` / `Password123` - the single
  inline secret in this channel.

## Auth header workaround (HTTP Senders)

HTTP Sender `username`/`password` are **not** Velocity-substituted (a `${VAR}`
there goes out literally and 401s - see `c-mirth`). So for the PAS IN and DICOM HTTP
Senders, set `useAuthentication=false`, blank the user/pass, and add a header
`Authorization: ${OE_API_AUTH}` (the Deploy script pre-builds `OE_API_AUTH` =
`Basic <base64(user:pass)>` in `globalMap` - `subs/secrets-config.md`). The TCP
Sender in PAS OUT needs no such workaround since its host/port fields do
substitute.
