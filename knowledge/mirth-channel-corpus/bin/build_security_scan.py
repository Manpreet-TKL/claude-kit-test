#!/usr/bin/env python3
"""Phase 13 - deterministic security/reliability scan over canonical/.

Extracts, per channel, the objectively-parseable security and reliability signals
(transport, inbound auth, listener bind, outbound TLS vs plaintext, outbound auth,
destination queueing and retry) into security/security-scan.csv, and prints the
estate aggregates the findings doc cites. Read-only over canonical/; deterministic.
"""
import csv, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAN = os.path.join(ROOT, "canonical", "_manifest.csv")

SRC_RE = re.compile(r"<sourceConnector(?:\s+[^>]*)?>(.*?)</sourceConnector>", re.S)

def transport(block):
    m = re.search(r"<transportName>([^<]*)</transportName>", block)
    return m.group(1) if m else ""

def rows():
    for r in csv.DictReader(open(MAN)):
        text = open(os.path.join(ROOT, r["canonical_path"])).read()
        src = SRC_RE.search(text)
        src_block = src.group(1) if src else ""
        src_transport = transport(src_block)
        # inbound auth: HTTP Listener authType, else listener anonymous flag
        auth_m = re.search(r"<authType>([^<]*)</authType>", src_block)
        inbound_auth = auth_m.group(1) if auth_m else "-"
        bind_all = "yes" if "<host>0.0.0.0</host>" in src_block else "no"
        # outbound (whole channel): scheme mix + basic-auth presence
        out_https = len(re.findall(r"https://", text))
        out_http = len(re.findall(r"(?<!s)http://", text))
        out_basic = "yes" if "authenticationType>Basic" in text else "no"
        # reliability: destination queue + retry
        queue_on = len(re.findall(r"<queueEnabled>true</queueEnabled>", text))
        retries = [int(x) for x in re.findall(r"<retryCount>(\d+)</retryCount>", text)]
        yield {
            "instance": r["instance"],
            "channel_name": r["channel_name"],
            "channel_id": r["channel_id"][:8],
            "source_transport": src_transport,
            "inbound_auth": inbound_auth,
            "listener_binds_all_ifaces": bind_all,
            "outbound_http": out_http,
            "outbound_https": out_https,
            "outbound_basic_auth": out_basic,
            "dest_queue_enabled": queue_on,
            "dest_retry_max": max(retries) if retries else 0,
        }

def main():
    data = list(rows())
    outdir = os.path.join(ROOT, "security")
    os.makedirs(outdir, exist_ok=True)
    cols = list(data[0].keys())
    with open(os.path.join(outdir, "security-scan.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(data)

    n = len(data)
    plaintext = [d for d in data if d["outbound_http"] and not d["outbound_https"]]
    tls = [d for d in data if d["outbound_https"]]
    listeners = [d for d in data if d["source_transport"].endswith("Listener")]
    none_auth = [d for d in listeners if d["inbound_auth"] == "NONE"]
    no_retry = [d for d in data if d["dest_retry_max"] == 0]
    no_queue = [d for d in data if d["dest_queue_enabled"] == 0]
    print("channels: %d" % n)
    print("outbound plaintext-only (http, no https): %d" % len(plaintext))
    print("outbound uses TLS (any https): %d  -> %s" %
          (len(tls), sorted({d["instance"] for d in tls})))
    print("source listeners: %d ; of those inbound_auth=NONE: %d" %
          (len(listeners), len(none_auth)))
    print("channels with NO destination retry (max=0): %d" % len(no_retry))
    print("channels with NO destination queueing: %d" % len(no_queue))

if __name__ == "__main__":
    main()
