# Networking and port map (Phase 3)

Every listening port and outbound network endpoint across the 13 instances, extracted
deterministically from the canonical channels (`bin/build_inventory.py` output). The
raw rows are in `networking/port-map.csv` (67 endpoints). Ports, hosts and IPs are
environment-specific but operationally meaningful; they are recorded here, not treated
as secrets, and are the parameters that Phase 9 templating will externalise. Role
labels come from the Phase 2 category of the channel bound to each port.

**Caveat - enabled state not yet resolved.** A listed port is where a channel is
*configured* to listen; whether that channel is deployed/enabled in production is an
open item (`unresolved/questions.md`). This matters for the Pennine collision below.

## De-facto port conventions (observed, not enforced)

There is no central port standard - these are conventions that emerged and then drifted.

| Port | Transport | Typical role | Evidence (categories bound) |
|---|---|---|---|
| 6661 | TCP/MLLP | Primary inbound HL7 PAS feed (ADT) | PAS Inbound |
| 6662 | TCP/MLLP | Secondary inbound (migration / 2nd PAS / correspondence / PP) | PAS Inbound, Doc Ingestion, PayloadProcessor |
| 6662 | HTTP | PDQ query listener (Wales only) | PAS Query / PDQ |
| 6663 | HTTP | HTTP entry point (PAS-outbound trigger; also a PDQ board) | PAS Outbound, PAS Query / PDQ |
| 6664-6669 | HTTP | Per-health-board PDQ listeners (Wales); AIS (MEH 6664) | PAS Query / PDQ, AIS |
| 6671 | TCP/MLLP | Extra inbound PAS feed (EK - Maidstone) | PAS Inbound |
| 8558 / 8559 | TCP/MLLP | Off-convention inbound (Newmedica: PAS In / correspondence) | PAS Inbound, Doc Ingestion |
| 11112 | DICOM | Standard DICOM listener (+ IOLMaster on same port at some sites) | DICOM, IOLMaster |
| 11113 / 11114 | DICOM | Alternate DICOM listener (Optegra / Newmedica) | DICOM |
| 11118 / 11119 | DICOM | DICOM + IOLMaster / legacy DICOM (Kingston, Pennine) | DICOM, IOLMaster, PayloadProcessor |

The DICOM port `11112` is the only near-universal convention; everything below `~6669`
is loosely held and diverges per site (most visibly Newmedica on `8558/8559`).

## Listen-port allocation per instance

| Instance | TCP/MLLP | HTTP | DICOM |
|---|---|---|---|
| Bedford | 6661 | 6663 | 11112 |
| Bolton | 6661 | 6663 | 11112 |
| EK | 6661, 6671 | 6663 | 11112 |
| ENHT | 6661 | 6663 | 11112 |
| Kingston | 6662 | - | 11112, 11118, 11119 |
| MEH | 6661 | 6663, 6664 | 11112 |
| Newmedica | 8558, 8559 | 6663 | 11114 |
| Optegra | 6661, 6662 | - | 11112, 11113 |
| Pennine | 6662 | 6663 | 11118 (x2), 11119 (x2) |
| Portsmouth | 6661, 6662 | 6663 | 11112 |
| Sussex | 6661, 6662 | 6663 | 11112 |
| Wales | 6661 | 6662-6669 (8 ports) | 11118 |

## Anomalies and findings

1. **Pennine DICOM port collision (needs enabled-state check).** Two channels are
   configured on `:11118` (`DICOM_11118` and `OpenEyes DICOM IOLMaster Channel`) and two
   on `:11119` (`DICOM_11119` and `OpenEyes DICOM Channel`). Two listeners cannot bind
   the same port simultaneously, so this is either a legacy/replacement pair (the
   `DICOM_1111x` channels superseded by the `OpenEyes DICOM *` channels, which are the
   ones shared by id with Kingston) with one side disabled, or a genuine mis-config.
   Resolve via the deployed/enabled flag before any redeploy.
   *Update (Phase 4-6 deep-read):* the direction is the reverse of the guess above - the
   `DICOM_1111x` channels are the current, AET-aware ones and the `OpenEyes DICOM *`
   channels (the Kingston-shared ids) are the static/legacy side. See
   `dataflows/dataflows.md`. Enabled-state confirmation still required.
2. **No port standard across sites.** The same logical role uses different ports per
   site (inbound HL7 on 6661 at most sites but 8558 at Newmedica; DICOM on 11112 vs
   11113/11114/11118). A deployment template must treat every port as a per-site
   parameter, not a constant.
3. **Wales fans PDQ across 8 HTTP ports (6662-6669),** one per health board - the
   networking face of the 8 cloned PDQ channels.
4. **Newmedica is the networking outlier** (8558/8559 MLLP, 11114 DICOM) - consistent
   with it also being the PASAPI-version outlier (mid V1->V3 migration).

## Outbound network dependencies

Channels that actively connect *out* to a remote host (TCP/MLLP senders; the full set
of HTTP-sender OE targets is resolved in Phase 5). Remote IPs are internal
(RFC1918) trust-network addresses.

| Instance | Channel | Outbound target |
|---|---|---|
| Bedford | PAS IN | 192.168.21.142:7072 |
| Bedford | PAS OUT | 192.168.192.3:8027 |
| Bolton | PAS OUT | 10.157.96.169:3017 |
| EK | PAS OUT | 10.240.8.126:19002, 10.240.11.20:19000 |
| ENHT | PAS Out | 192.168.113.89:20002 |
| Kingston | OpenEyes Correspondence | 10.51.84.239:5623 |
| MEH | AIS Sender | 192.168.192.3:8021 |
| MEH | OpenEyes PAS Query v2 | 192.168.192.3:8021 |
| Newmedica | OpenEyes PAS Out | 172.20.128.37:6667 |
| Pennine | OpenEyes PAS Query | 192.168.96.60:8400 |
| Portsmouth | PAS OUT | 192.168.27.203:30029 |
| Sussex | PAS OUT | 10.179.63.224:43442 |

## External (non-RFC1918) host dependencies

| Host | Refs | Used by / role |
|---|--:|---|
| apps.wales.nhs.uk | 8 | Wales PDQ/MPI SOAP endpoint |
| mpilivequeries.cymru.nhs.uk | 8 | Wales MPI live-query endpoint |
| openeyes.moorfields.nhs.uk | 3 | MEH OpenEyes host |
| sys479.xrbh.nhs.uk | 1 | site-specific upstream |
| bridgenas.ad.ekhuft.nhs.uk | 1 | EK file share (correspondence) |
| ekprismprd01.ad.ekhuft.nhs.uk | 1 | EK PRISM (PAS) host |

## Files

- `networking/port-map.csv` - every listen/outbound endpoint (instance, channel, id,
  direction, transport, port, endpoint, enabled).
