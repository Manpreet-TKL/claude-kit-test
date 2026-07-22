#!/usr/bin/env python3
"""Phase 14 - deterministic AI knowledge corpus.

Joins the wave artifacts (inventory, taxonomy, deep-dive, security scan, templates,
plus storage-mode/threads re-read from canonical/) into one consolidated per-channel
record set for AI-agent consumption. Emits:

  ai-corpus/channels.jsonl   one JSON object per channel (102), sorted, with provenance
  ai-corpus/schema.json      the record schema (field -> meaning + source artifact)
  ai-corpus/summary.json     estate aggregates for fast agent grounding

Join key is canonical_path (unique per channel; present in inventory/taxonomy/deepdive).
The security scan is keyed by (instance, channel_name, id8). Deterministic: sorted
iteration, no timestamps. Re-run is byte-identical. Reads only generated artifacts +
the redacted canonical/ copies; the raw corpus is never touched.
"""
import csv, glob, json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_json(p):
    with open(os.path.join(ROOT, p)) as f:
        return json.load(f)


def canonical_field(path, tag, default=None):
    """Read a single scalar tag from a canonical channel file (first occurrence)."""
    with open(os.path.join(ROOT, path)) as f:
        m = re.search(r"<%s>([^<]*)</%s>" % (tag, tag), f.read())
    return m.group(1) if m else default


def main():
    inv = {r["canonical_path"]: r for r in load_json("inventory/corpus-inventory.json")}
    tax = {r["canonical_path"]: r for r in load_json("taxonomy/channel-types.json")["channels"]}

    deep = {}
    for sl in sorted(glob.glob(os.path.join(ROOT, "deepdive/_slices/*.json"))):
        for r in json.load(open(sl)):
            deep[r["canonical_path"]] = r

    scan = {}
    with open(os.path.join(ROOT, "security/security-scan.csv")) as f:
        for r in csv.DictReader(f):
            scan[(r["instance"], r["channel_name"], r["channel_id"])] = r

    # template family membership: channel_name -> family (per instance where known)
    family = {}
    for fam_dir in sorted(glob.glob(os.path.join(ROOT, "templates/*/sites.csv"))):
        fam = os.path.basename(os.path.dirname(fam_dir))
        for r in csv.DictReader(open(fam_dir)):
            family[r["channel_name"]] = fam

    records = []
    for path in sorted(inv):
        iv = inv[path]
        tx = tax.get(path, {})
        dp = deep.get(path, {})
        cid, name, instance = iv["channel_id"], iv["channel_name"], iv["instance"]
        sc = scan.get((instance, name, cid[:8]), {})

        src = iv.get("source_connector") or {}
        dests = [{"name": d.get("name"), "transport": d.get("transportName"),
                  "endpoint": d.get("endpoint")}
                 for d in iv.get("destination_connectors", [])]

        https = int(sc.get("outbound_https", 0) or 0)
        http = int(sc.get("outbound_http", 0) or 0)
        scheme = ("https" if https and not http else "http" if http and not https
                  else "mixed" if http and https else "none")

        rec = {
            "channel_id": cid,
            "channel_name": name,
            "instance": instance,
            "source_file": iv["source_file"],
            "canonical_path": path,
            "bridgelink_version": iv.get("bridgelink_version"),
            "raw_sha256": iv.get("raw_sha256"),
            "category": tx.get("category"),
            "functional_purpose": tx.get("functional_purpose"),
            "business_process": tx.get("business_process"),
            "reuse_class": tx.get("reusable_vs_client_specific"),
            "template_family": family.get(name),
            "source": {
                "transport": src.get("transportName"),
                "port": src.get("port"),
                "endpoint": src.get("endpoint"),
                "binds_all_interfaces": sc.get("listener_binds_all_ifaces") == "yes",
                "inbound_auth": sc.get("inbound_auth"),
            },
            "destinations": dests,
            "protocol": tx.get("protocol"),
            "message_format": tx.get("message_format"),
            "hl7": {
                "version": tx.get("hl7_version"),
                "message_types": tx.get("hl7_message_types"),
                "trigger_events": tx.get("hl7_trigger_events"),
                "ack_behaviour": tx.get("ack_behaviour"),
                "detail": dp.get("hl7"),
            },
            "openeyes": {
                "endpoints": iv.get("oe_endpoints", []),
                "api_versions": tx.get("oe_api_versions") or iv.get("pasapi_versions", []),
                "uses_payload_processor": iv.get("uses_payload_processor", False),
                "detail": dp.get("oe_api"),
            },
            "auth": {
                "method": tx.get("auth_method"),
                "credential": "shared api Basic (redacted, ${REDACTED_PASSWORD})"
                if iv.get("secret_present") else None,
                "detail": dp.get("auth"),
            },
            "security": {
                "outbound_scheme": scheme,
                "outbound_http_endpoints": http,
                "outbound_https_endpoints": https,
                "outbound_basic_auth": sc.get("outbound_basic_auth") == "yes",
                "message_storage_mode": canonical_field(path, "messageStorageMode"),
            },
            "reliability": {
                "queue_enabled_destinations": int(sc.get("dest_queue_enabled", 0) or 0),
                "retry_max": int(sc.get("dest_retry_max", 0) or 0),
                "processing_threads": int(canonical_field(path, "processingThreads", 1) or 1),
                "stateful": tx.get("stateful"),
                "safe_to_replay": tx.get("safe_to_replay"),
                "error_handling": tx.get("error_handling"),
                "retry_behaviour": tx.get("retry_behaviour"),
                "queue_behaviour": tx.get("queue_behaviour"),
            },
            "dependencies": tx.get("depends_on") or iv.get("global_map_reads", []),
            "routing": dp.get("routing"),
            "evidence": dp.get("evidence"),
            "confidence": tx.get("confidence") or dp.get("confidence") or "inferred",
            "provenance": {
                "inventory": path in inv,
                "taxonomy": path in tax,
                "deepdive": path in deep,
                "security_scan": bool(sc),
            },
        }
        records.append(rec)

    out = os.path.join(ROOT, "ai-corpus")
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "channels.jsonl"), "w") as f:
        for r in sorted(records, key=lambda r: (r["instance"], r["channel_name"], r["channel_id"])):
            f.write(json.dumps(r, sort_keys=True, ensure_ascii=False) + "\n")

    # summary aggregates
    def tally(key):
        d = {}
        for r in records:
            k = key(r)
            k = "(none)" if k is None else str(k)
            d[k] = d.get(k, 0) + 1
        return dict(sorted(d.items(), key=lambda kv: (-kv[1], kv[0])))

    summary = {
        "description": "Estate aggregates over the 102-channel corpus; load first for grounding.",
        "channel_count": len(records),
        "instances": sorted({r["instance"] for r in records}),
        "by_instance": tally(lambda r: r["instance"]),
        "by_category": tally(lambda r: r["category"]),
        "by_reuse_class": tally(lambda r: r["reuse_class"]),
        "by_confidence": tally(lambda r: r["confidence"]),
        "by_bridgelink_version": tally(lambda r: r["bridgelink_version"]),
        "by_source_transport": tally(lambda r: r["source"]["transport"]),
        "by_outbound_scheme": tally(lambda r: r["security"]["outbound_scheme"]),
        "by_storage_mode": tally(lambda r: r["security"]["message_storage_mode"]),
        "security_reliability": {
            "channels_plaintext_only_to_web": sum(
                1 for r in records if r["security"]["outbound_scheme"] == "http"),
            "channels_tls": sum(1 for r in records if r["security"]["outbound_https_endpoints"]),
            "http_listeners_no_auth": sum(
                1 for r in records if r["source"]["inbound_auth"] == "NONE"),
            "channels_no_retry": sum(1 for r in records if r["reliability"]["retry_max"] == 0),
            "channels_no_queue": sum(
                1 for r in records if r["reliability"]["queue_enabled_destinations"] == 0),
            "channels_development_storage": sum(
                1 for r in records if r["security"]["message_storage_mode"] == "DEVELOPMENT"),
        },
        "template_families": tally(lambda r: r["template_family"]),
        "shared_channel_ids": load_json("taxonomy/channel-types.json").get("shared_channel_ids"),
        "provenance": {
            "records_with_deepdive": sum(1 for r in records if r["provenance"]["deepdive"]),
            "records_confirmed": sum(1 for r in records if r["confidence"] == "confirmed"),
        },
    }
    with open(os.path.join(out, "summary.json"), "w") as f:
        json.dump(summary, f, indent=2, sort_keys=True, ensure_ascii=False)

    schema = {
        "description": "Schema for ai-corpus/channels.jsonl - one object per Mirth channel. "
        "Consolidated deterministically by bin/build_ai_corpus.py from the wave artifacts; "
        "every field traces to a source artifact. Names/IDs do not imply function - trust "
        "'category' (evidence-classified), not the channel name.",
        "join_key": "canonical_path (unique per channel)",
        "record": {
            "channel_id": "Mirth channel UUID (may recur across instances - see shared_channel_ids)",
            "channel_name": "export name - NOT authoritative for function",
            "instance": "client instance directory",
            "source_file": "original export path (provenance; read-only corpus)",
            "canonical_path": "redacted+normalised copy under canonical/",
            "bridgelink_version": "export schema version (4.4.2 / 4.5.2 / 4.6.1)",
            "raw_sha256": "hash of the raw channel block (identity/dedup)",
            "category": "taxonomy category (evidence-classified) [taxonomy]",
            "functional_purpose": "one-line purpose [taxonomy]",
            "business_process": "business context [taxonomy]",
            "reuse_class": "reusable-with-config | client-specific [taxonomy]",
            "template_family": "parameterised-template family if a member, else null [templates]",
            "source": "source connector: transport/port/endpoint/binds_all_interfaces/inbound_auth "
            "[inventory + security-scan]",
            "destinations": "destination connectors: name/transport/endpoint [inventory]",
            "protocol": "wire protocol [taxonomy]",
            "message_format": "message format [taxonomy]",
            "hl7": "version/message_types/trigger_events/ack_behaviour [taxonomy] + detail [deepdive]",
            "openeyes": "endpoints/api_versions/uses_payload_processor [inventory+taxonomy] + detail [deepdive]",
            "auth": "method + credential placeholder (never a value) + detail [taxonomy+deepdive]",
            "security": "outbound_scheme/http+https endpoint counts/outbound_basic_auth/"
            "message_storage_mode [security-scan + canonical]",
            "reliability": "queue_enabled_destinations/retry_max/processing_threads/stateful/"
            "safe_to_replay/error+retry+queue behaviour [security-scan + taxonomy + canonical]",
            "dependencies": "channel/global-map dependencies [taxonomy/inventory]",
            "routing": "routing logic detail [deepdive, where present]",
            "evidence": "per-claim evidence pointers [deepdive, where present]",
            "confidence": "confirmed | inferred",
            "provenance": "which artifacts contributed to this record",
        },
        "companion_files": {
            "summary.json": "estate aggregates - load first",
            "glossary.md": "domain glossary (PASAPI, PDQ, MPI, PayloadProcessor, MLLP, ...)",
            "../security/findings.md": "SEC/REL findings the security/reliability fields feed",
            "../testing/strategy.md": "how safe_to_replay and the findings become test gates",
        },
    }
    with open(os.path.join(out, "schema.json"), "w") as f:
        json.dump(schema, f, indent=2, sort_keys=True, ensure_ascii=False)

    print("channels.jsonl: %d records" % len(records))
    print("with deepdive detail: %d / 102" % summary["provenance"]["records_with_deepdive"])
    print("categories: %s" % summary["by_category"])
    print("outbound scheme: %s" % summary["by_outbound_scheme"])
    print("storage mode: %s" % summary["by_storage_mode"])
    miss_tax = [p for p in inv if p not in tax]
    if miss_tax:
        print("WARN unmatched taxonomy: %s" % miss_tax)


if __name__ == "__main__":
    main()
