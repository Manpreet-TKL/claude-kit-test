#!/usr/bin/env python3
"""
Phase 1 - deterministic inventory over the canonical (redacted) channel files.

Reads canonical/*/*.xml + canonical/_manifest.csv + secrets/redaction-log.csv.
Writes inventory/{corpus-inventory.json, channels.csv, dependencies.csv, versions.md}.
All facts are structural XML extraction - no judgement, no secrets.
"""
import csv
import json
import os
import re
import xml.etree.ElementTree as ET

OUT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CANON = os.path.join(OUT, "canonical")

PASAPI_RE = re.compile(r"PASAPI/(V\d+)")
APIV_RE = re.compile(r"/api/(v\d+)/([A-Za-z0-9/_?=.-]+)")
IP_RE = re.compile(r"\b\d{1,3}(?:\.\d{1,3}){3}\b")
HOSTNAME_RE = re.compile(r"[a-zA-Z0-9.-]+\.nhs\.uk")
# scripts store quotes as &apos; / &quot; entities (or literal); channelMap is
# message-scoped runtime state, NOT a dependency - excluded here.
_Q = r"(?:['\"]|&apos;|&quot;)"
MAP_RE = re.compile(r"(globalMap|globalChannelMap|configurationMap)\.(get|put)\(\s*%s([^'\"&]+)" % _Q)


def load_csv(path):
    with open(path, newline="") as fh:
        return list(csv.DictReader(fh))


def deep_text(props, tag):
    if props is None:
        return None
    for e in props.iter(tag):
        if e.text and e.text.strip():
            return e.text.strip()
    return None


def steps_count(conn):
    t = conn.find("transformer")
    n_t = len(t.find("elements")) if (t is not None and t.find("elements") is not None) else 0
    f = conn.find("filter")
    n_f = len(f.find("rules")) if (f is not None and f.find("rules") is not None) else 0
    return n_t, n_f


def connector_info(conn, direction):
    tn = conn.findtext("transportName")
    props = conn.find("properties")
    port = deep_text(props, "port")
    remote_port = deep_text(props, "remotePort")
    host = deep_text(props, "host")
    remote_addr = deep_text(props, "remoteAddress")
    n_t, n_f = steps_count(conn)
    endpoint = None
    if tn == "TCP Sender":
        endpoint = "%s:%s" % (remote_addr or "?", remote_port or "?")
        port = remote_port
    elif tn in ("HTTP Sender", "File Writer", "File Reader"):
        endpoint = host
    elif tn == "Web Service Sender":
        endpoint = deep_text(props, "wsdlUrl") or deep_text(props, "locationURI") or port
    elif tn == "Channel Writer":
        endpoint = deep_text(props, "channelId")
    elif tn in ("TCP Listener", "HTTP Listener", "DICOM Listener"):
        endpoint = "listen %s:%s" % (host or "0.0.0.0", port or "?")
    return {
        "metaDataId": conn.findtext("metaDataId"),
        "name": conn.findtext("name"),
        "transportName": tn,
        "direction": direction,
        "port": port,
        "endpoint": endpoint,
        "transformer_steps": n_t,
        "filter_rules": n_f,
        "enabled": conn.findtext("enabled"),
    }


def main():
    manifest = {r["canonical_path"]: r for r in load_csv(os.path.join(CANON, "_manifest.csv"))}
    redactions = load_csv(os.path.join(OUT, "secrets", "redaction-log.csv"))
    secret_channels = {r["channel_id"] for r in redactions}

    inventory = []
    dep_edges = []

    for canon_path in sorted(manifest.keys()):
        m = manifest[canon_path]
        full = os.path.join(OUT, canon_path)
        text = open(full, encoding="utf-8").read()
        root = ET.fromstring(text)

        src = connector_info(root.find("sourceConnector"), "source")
        dests = []
        dc = root.find("destinationConnectors")
        if dc is not None:
            for c in dc.findall("connector"):
                dests.append(connector_info(c, "destination"))

        # OE endpoints + PASAPI versions from all HTTP sender endpoints
        pasapi_versions = sorted(set(PASAPI_RE.findall(text)))
        api_endpoints = sorted(set("%s /%s" % (v, p.split("?")[0].rstrip("/"))
                                   for v, p in APIV_RE.findall(text)))
        oe_endpoints = sorted(set(re.findall(r"(?:PASAPI/V\d+/[A-Za-z]+|/api/v\d+/[A-Za-z0-9/_-]+)", text)))
        uses_payload_processor = "request/queue/add" in text

        # environment-specific identifiers (not secrets, but client/site specific)
        ips = sorted(set(IP_RE.findall(text)))
        nhs_hosts = sorted(set(HOSTNAME_RE.findall(text)))

        # dependencies: config/global map reads (consumed), writes (provided), routing
        cfg_reads = sorted(set(k for m_, op, k in MAP_RE.findall(text)
                               if m_ == "configurationMap" and op == "get"))
        global_reads = sorted(set("%s:%s" % (m_, k) for m_, op, k in MAP_RE.findall(text)
                                  if m_ in ("globalMap", "globalChannelMap") and op == "get"))
        global_writes = sorted(set("%s:%s" % (m_, k) for m_, op, k in MAP_RE.findall(text)
                                   if m_ in ("globalMap", "globalChannelMap") and op == "put"))
        chan_writer_targets = [d["endpoint"] for d in dests if d["transportName"] == "Channel Writer"]

        for k in cfg_reads:
            dep_edges.append({"channel_id": m["channel_id"], "channel_name": m["channel_name"],
                              "instance": m["instance"], "depends_on_type": "configurationMap.get", "depends_on": k})
        for k in global_reads:
            dep_edges.append({"channel_id": m["channel_id"], "channel_name": m["channel_name"],
                              "instance": m["instance"], "depends_on_type": "global.get", "depends_on": k})
        for k in global_writes:
            dep_edges.append({"channel_id": m["channel_id"], "channel_name": m["channel_name"],
                              "instance": m["instance"], "depends_on_type": "global.put", "depends_on": k})
        for t in chan_writer_targets:
            dep_edges.append({"channel_id": m["channel_id"], "channel_name": m["channel_name"],
                              "instance": m["instance"], "depends_on_type": "channel_writer", "depends_on": t})

        rec = {
            "instance": m["instance"],
            "source_file": m["source_file"],
            "artifact_type": m["root_type"],
            "channel_name": m["channel_name"],
            "channel_id": m["channel_id"],
            "group": m["group_name"],
            "bridgelink_version": m["bridgelink_version"],
            "canonical_path": canon_path,
            "raw_sha256": m["raw_sha256"],
            "source_connector": src,
            "destination_connectors": dests,
            "n_destinations": len(dests),
            "pasapi_versions": pasapi_versions,
            "api_endpoints": api_endpoints,
            "oe_endpoints": oe_endpoints,
            "uses_payload_processor": uses_payload_processor,
            "config_map_keys": cfg_reads,
            "global_map_reads": global_reads,
            "global_map_writes": global_writes,
            "env_ips": ips,
            "env_nhs_hosts": nhs_hosts,
            "secret_present": m["channel_id"] in secret_channels,
            "sensitive_env_present": bool(ips or nhs_hosts),
            "analysis_status": "inventoried",
        }
        inventory.append(rec)

    inventory.sort(key=lambda r: (r["instance"], r["channel_name"]))

    with open(os.path.join(OUT, "inventory", "corpus-inventory.json"), "w") as fh:
        json.dump(inventory, fh, indent=2, sort_keys=False)

    # channels.csv - flat
    with open(os.path.join(OUT, "inventory", "channels.csv"), "w", newline="") as fh:
        cols = ["instance", "channel_name", "channel_id", "group", "artifact_type",
                "bridgelink_version", "source_file", "source_transport", "source_port",
                "n_destinations", "dest_transports", "pasapi_versions", "uses_payload_processor",
                "secret_present", "sensitive_env_present", "raw_sha256"]
        w = csv.writer(fh)
        w.writerow(cols)
        for r in inventory:
            w.writerow([
                r["instance"], r["channel_name"], r["channel_id"], r["group"], r["artifact_type"],
                r["bridgelink_version"], r["source_file"],
                r["source_connector"]["transportName"], r["source_connector"]["port"] or "",
                r["n_destinations"],
                "|".join(sorted(set(d["transportName"] for d in r["destination_connectors"]))),
                "|".join(r["pasapi_versions"]), r["uses_payload_processor"],
                r["secret_present"], r["sensitive_env_present"], r["raw_sha256"][:12],
            ])

    dep_edges.sort(key=lambda e: (e["instance"], e["channel_name"], e["depends_on_type"], e["depends_on"]))
    with open(os.path.join(OUT, "inventory", "dependencies.csv"), "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["instance", "channel_name", "channel_id",
                                           "depends_on_type", "depends_on"])
        w.writeheader()
        w.writerows(dep_edges)

    # versions.md + shared-lineage analysis
    ver_by_inst = {}
    pasapi_by_inst = {}
    id_to_instances = {}
    for r in inventory:
        ver_by_inst.setdefault(r["bridgelink_version"], set()).add(r["instance"])
        for v in r["pasapi_versions"]:
            pasapi_by_inst.setdefault(r["instance"], set()).add(v)
        id_to_instances.setdefault(r["channel_id"], set()).add(r["instance"])
    shared = {cid: sorted(insts) for cid, insts in id_to_instances.items() if len(insts) > 1}

    lines = ["# Versions & shared lineage", "",
             "## BridgeLink version by instance", ""]
    for v in sorted(ver_by_inst):
        lines.append("- **%s**: %s" % (v, ", ".join(sorted(ver_by_inst[v]))))
    lines += ["", "## PASAPI version usage by instance",
              "(V1 = OE <=8, V2 = OE 9-10, V3 = OE 11+)", ""]
    for inst in sorted(pasapi_by_inst):
        lines.append("- **%s**: %s" % (inst, ", ".join(sorted(pasapi_by_inst[inst])) or "(none)"))
    lines += ["", "## Channel IDs shared across instances (cloned lineage)",
              "Same channel `id` in >1 instance = the channel was copied between sites.", ""]
    for cid in sorted(shared, key=lambda c: (-len(shared[c]), c)):
        names = sorted(set(r["channel_name"] for r in inventory if r["channel_id"] == cid))
        lines.append("- `%s` -> %s  (names: %s)" % (cid, ", ".join(shared[cid]), " / ".join(names)))
    with open(os.path.join(OUT, "inventory", "versions.md"), "w") as fh:
        fh.write("\n".join(lines) + "\n")

    print("channels inventoried: %d" % len(inventory))
    print("dependency edges: %d" % len(dep_edges))
    print("shared-across-instance channel ids: %d" % len(shared))


if __name__ == "__main__":
    main()
