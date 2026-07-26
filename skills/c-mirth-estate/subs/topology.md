# Topology - ports, transports, who talks to whom

Ports and transports identify which feed is which, so they are here. Addresses do not, so
they are not - every remote is named by its role. The corpus holds the actual endpoints if an
audit ever needs them.

## Listen ports per site

| Site | MLLP / TCP | HTTP | DICOM |
|---|---|---|---|
| Bedford | 6661 | 6663 | 11112 |
| Bolton | 6661 | 6663 | 11112 |
| EK | 6661, 6671 | 6663 | 11112 |
| ENHT | 6661 | 6663 | 11112 |
| Kingston | 6662 | - | 11112, 11118, 11119 |
| MEH | 6661 | 6663, 6664 | 11112 |
| Newmedica | 8558, 8559 | 6663 | 11114 |
| Optegra | 6661, 6662 | - | 11112, 11113 |
| Pennine | 6662 | 6663 | 11118 x2, 11119 x2 |
| Portsmouth | 6661, 6662 | 6663 | 11112 |
| Sussex | 6661, 6662 | 6663 | 11112 |
| Wales | 6661 | 6662-6669 | 11118 |

## The conventions, such as they are

There is no enforced standard - these emerged and then drifted.

| Port | Transport | Role |
|---|---|---|
| 6661 | MLLP | primary inbound HL7 PAS feed |
| 6662 | MLLP | secondary inbound - a migration feed, a second PAS, or document ingestion |
| 6662 | HTTP | PDQ listener (Wales) |
| 6663 | HTTP | PAS-outbound query trigger; also one Welsh board |
| 6664-6669 | HTTP | the remaining Welsh board listeners; MEH AIS on 6664 |
| 6671 | MLLP | a third inbound feed (EK, its second trust) |
| 8558 / 8559 | MLLP | off-convention inbound (Newmedica: PAS / correspondence) |
| 11112 | DICOM | the near-universal DICOM listener |
| 11113 / 11114 | DICOM | alternates (Optegra, Newmedica) |
| 11118 / 11119 | DICOM | Kingston, Pennine, Wales |

`11112` is the only convention that holds almost everywhere. Anything at or below 6669 is
loosely held. **A deployment template must treat every port as a per-site parameter.**

Two consequences worth carrying: 6662 means completely different things depending on the site
(a second MLLP feed at Optegra, Pennine, Portsmouth and Sussex; an HTTP PDQ listener at
Wales; document ingestion at Portsmouth), and Kingston's *primary* PAS feed is on 6662 rather
than 6661.

## Port collision at Pennine

Two channels are configured on `:11118` (`DICOM_11118`, `OpenEyes DICOM IOLMaster Channel`)
and two on `:11119` (`DICOM_11119`, `OpenEyes DICOM Channel`). Two listeners cannot bind the
same port, so one of each pair must be disabled in the running instance. The `DICOM_1111x`
channels are the current AET-aware ones; the `OpenEyes DICOM *` pair is the legacy side.
Enabled state is not recorded in the corpus - check the instance before redeploying anything
at Pennine.

## What each site connects out to

By role. Ten sites open an outbound TCP/MLLP connection; the rest talk only over HTTP to the
OpenEyes API.

| Site | Outbound role |
|---|---|
| Bedford | the trust PAS (query), plus a forward to another site's engine |
| Bolton, ENHT, Portsmouth, Sussex | the trust PAS (query) |
| EK | two endpoints - the trust PAS and a test MPI |
| Kingston | the trust EPR over MLLP, and a document manager over HTTP |
| MEH | its own OpenEyes host, and the AIS endpoint |
| Newmedica | the PAS query endpoint |
| Pennine | the trust PAS (query) |
| Wales | the national MPI, over SOAP, from all 8 board channels |

Document-outbound channels additionally write to a file share or an SFTP target; DICOM
channels write to a local mount and post to the OpenEyes queue API.

## Filesystem mounts

Shapes, not instances: `/mnt/dicom` (DICOM landing), `/mnt/docman/*` (document manager
in/out trees), `/mnt/document-upload` (PayloadProcessor sources), plus a per-site
IOLMaster import folder.

## Security posture, in one place

Facts that shape any question about exposure:

- **18 HTTP listeners, none authenticated.** Every PAS-outbound and PDQ entry point accepts
  an unauthenticated request. Network placement is the only control.
- **77 channels talk to the OpenEyes API in plaintext**; 11 use TLS, 2 use HTTPS outbound.
- A single shared service account is used estate-wide for the OpenEyes API. That is a
  rotation problem, not a per-channel one.
- 26 channels run in DEVELOPMENT storage mode, which does not retain content for replay.

None of the above is per-site behaviour, so it does not appear in the site files.

## Sanitisation note

Real hostnames, internal addresses and remote ports are deliberately absent from this skill.
They live in `~/mirth-channel-corpus/networking/`. If a question
genuinely needs an address - a firewall change, a migration cutover - that is the file to
open, and it is the only reason to open it.
