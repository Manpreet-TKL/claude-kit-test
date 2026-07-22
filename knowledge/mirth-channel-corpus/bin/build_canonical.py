#!/usr/bin/env python3
"""
Wave 0 - deterministic split + redact + normalise for the Mirth channel corpus.

Reads /home/toukan/client-mirth-channels READ-ONLY. Writes only under this repo
root (the parent of bin/). No secret value is ever written to any output file;
every redaction is logged (location + type + placeholder, NOT value).

Outputs:
  canonical/<instance>/<channel>.xml   one redacted+normalised channel per file
  canonical/_manifest.csv              one row per channel (identity + hashes)
  secrets/redaction-log.csv            one row per redacted secret (no values)

Deterministic: sorted iteration, document order, no timestamps/randomness.
A second run produces byte-identical output.
"""
import csv
import hashlib
import os
import re
import sys

CORPUS = "/home/toukan/client-mirth-channels"
OUT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Usernames that are generic protocol/role values, not client credentials: keep them
# visible in canonical copies (useful classification signal). Everything else is a
# service-account identifier and gets redacted.
GENERIC_USERNAMES = {"api", "anonymous", ""}

PLACEHOLDER_PW = "${REDACTED_PASSWORD}"
PLACEHOLDER_PP = "${REDACTED_PASSPHRASE}"
PLACEHOLDER_UN = "${REDACTED_USERNAME}"

TAG_RE = re.compile(r"<(password|passPhrase|username)>([^<]*)</\1>")
NAME_RE = re.compile(r"<name>([^<]*)</name>")

# Mirth transformer sample-message fields. These hold a developer sample message for
# the mapping UI only - they are NOT read at runtime - but in this corpus some carry
# patient-shaped payloads (names, DOBs, hospital/NHS numbers). We blank their content
# in every canonical copy; the channel's logic is unaffected. Each non-empty field is
# logged (length only, never the value), exactly like a secret redaction.
SAMPLE_RES = [(t, re.compile(r"(<%sTemplate(?:\s+[^>]*)?>)(.*?)(</%sTemplate>)" % (t, t), re.S))
              for t in ("inbound", "outbound")]


def sha256(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def split_channels(text: str):
    """Yield (channel_block_text, channel_version) in document order.
    Balanced scan on <channel version=...> ... </channel>; channels never nest."""
    open_re = re.compile(r"<channel version=\"([^\"]*)\">")
    blocks = []
    pos = 0
    while True:
        m = open_re.search(text, pos)
        if not m:
            break
        end = text.find("</channel>", m.end())
        if end == -1:
            raise ValueError("unbalanced <channel> at %d" % m.start())
        end += len("</channel>")
        blocks.append((text[m.start():end], m.group(1)))
        pos = end
    return blocks


def first_after(block: str, start_idx: int, tag: str):
    m = re.search(r"<%s>([^<]*)</%s>" % (tag, tag), block[start_idx:])
    return m.group(1) if m else ""


def nearest_preceding_name(block: str, idx: int) -> str:
    last = ""
    for m in NAME_RE.finditer(block, 0, idx):
        last = m.group(1)
    return last


def sanitize(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9 ._-]", "_", name).strip() or "unnamed"


def redact(block: str, ctx, redaction_rows):
    """Return redacted block; append rows (no values) to redaction_rows."""
    out = []
    last = 0
    for m in TAG_RE.finditer(block):
        tag, val = m.group(1), m.group(2)
        if val == "":
            continue
        if tag == "username" and val in GENERIC_USERNAMES:
            continue
        placeholder = {"password": PLACEHOLDER_PW,
                       "passPhrase": PLACEHOLDER_PP,
                       "username": PLACEHOLDER_UN}[tag]
        out.append(block[last:m.start()])
        out.append("<%s>%s</%s>" % (tag, placeholder, tag))
        last = m.end()
        redaction_rows.append({
            "instance": ctx["instance"],
            "source_file": ctx["source_file"],
            "channel_id": ctx["channel_id"],
            "channel_name": ctx["channel_name"],
            "connector_context": nearest_preceding_name(block, m.start()),
            "secret_type": tag,
            "placeholder": placeholder,
            "orig_value_length": len(val),
        })
    out.append(block[last:])
    return "".join(out)


def blank_samples(block: str, ctx, redaction_rows) -> str:
    """Blank non-empty inbound/outboundTemplate sample-message fields; log each."""
    hits = []
    for kind, rx in SAMPLE_RES:
        for m in rx.finditer(block):
            if m.group(2):  # non-empty content only
                hits.append((m.start(), m.end(), m.group(1), m.group(3), len(m.group(2)), kind))
    if not hits:
        return block
    hits.sort()
    out = []
    last = 0
    for start, end, open_t, close_t, length, kind in hits:
        out.append(block[last:start])
        out.append(open_t + close_t)
        last = end
        redaction_rows.append({
            "instance": ctx["instance"],
            "source_file": ctx["source_file"],
            "channel_id": ctx["channel_id"],
            "channel_name": ctx["channel_name"],
            "connector_context": nearest_preceding_name(block, start),
            "secret_type": "sample_message_%s" % kind,
            "placeholder": "(blanked)",
            "orig_value_length": length,
        })
    out.append(block[last:])
    return "".join(out)


def normalise(block: str) -> str:
    """Neutralise pure-noise fields for comparison. IDs are kept (identity-bearing,
    needed for inventory); ID neutralisation is deferred to the Phase 8 diff wave."""
    block = re.sub(r"<time>\d+</time>", "<time>0</time>", block)
    block = re.sub(r"<revision>\d+</revision>", "<revision>0</revision>", block)
    return block


def main():
    manifest_rows = []
    redaction_rows = []
    used_paths = {}  # (instance, sanitized) -> count, for collision suffixing

    files = []
    for root, _dirs, names in os.walk(CORPUS):
        for n in sorted(names):
            if n.endswith(".xml"):
                files.append(os.path.join(root, n))
    files.sort()

    for path in files:
        rel = os.path.relpath(path, CORPUS)
        instance = rel.split(os.sep)[0]
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()

        root_type = "channelGroup" if re.match(r"\s*<channelGroup", text) else "channel"
        group_id = group_name = ""
        if root_type == "channelGroup":
            head = text.split("<channels", 1)[0]
            gid = re.search(r"<id>([^<]*)</id>", head)
            gnm = re.search(r"<name>([^<]*)</name>", head)
            group_id = gid.group(1) if gid else ""
            group_name = gnm.group(1) if gnm else ""

        for block, version in split_channels(text):
            id_m = re.search(r"<id>([^<]*)</id>", block)
            channel_id = id_m.group(1) if id_m else ""
            channel_name = first_after(block, id_m.end() if id_m else 0, "name")

            ctx = {"instance": instance, "source_file": rel,
                   "channel_id": channel_id, "channel_name": channel_name}

            raw_sha = sha256(block)
            red = redact(block, ctx, redaction_rows)
            red = blank_samples(red, ctx, redaction_rows)
            canon = normalise(red)
            canon_sha = sha256(canon)

            base = sanitize(channel_name)
            key = (instance, base)
            used_paths[key] = used_paths.get(key, 0) + 1
            if used_paths[key] > 1:
                base = "%s__%s" % (base, channel_id[:8])
            out_dir = os.path.join(OUT, "canonical", instance)
            os.makedirs(out_dir, exist_ok=True)
            canon_path = os.path.join(out_dir, base + ".xml")
            with open(canon_path, "w", encoding="utf-8") as ofh:
                ofh.write(canon)

            manifest_rows.append({
                "instance": instance,
                "source_file": rel,
                "root_type": root_type,
                "group_id": group_id,
                "group_name": group_name,
                "channel_id": channel_id,
                "channel_name": channel_name,
                "bridgelink_version": version,
                "canonical_path": os.path.relpath(canon_path, OUT),
                "raw_sha256": raw_sha,
                "canon_sha256": canon_sha,
            })

    manifest_rows.sort(key=lambda r: (r["instance"], r["source_file"], r["channel_name"]))
    with open(os.path.join(OUT, "canonical", "_manifest.csv"), "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(manifest_rows[0].keys()))
        w.writeheader()
        w.writerows(manifest_rows)

    redaction_rows.sort(key=lambda r: (r["instance"], r["source_file"],
                                       r["channel_name"], r["secret_type"],
                                       r["connector_context"]))
    with open(os.path.join(OUT, "secrets", "redaction-log.csv"), "w", newline="") as fh:
        cols = ["instance", "source_file", "channel_id", "channel_name",
                "connector_context", "secret_type", "placeholder", "orig_value_length"]
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        w.writerows(redaction_rows)

    print("channels: %d" % len(manifest_rows))
    print("redactions: %d" % len(redaction_rows))
    by_type = {}
    for r in redaction_rows:
        by_type[r["secret_type"]] = by_type.get(r["secret_type"], 0) + 1
    print("redactions by type: %s" % by_type)
    dup = {}
    for r in manifest_rows:
        dup.setdefault(r["canon_sha256"], []).append(r["channel_name"])
    exact = {k: v for k, v in dup.items() if len(v) > 1}
    print("exact-duplicate canon groups: %d" % len(exact))


if __name__ == "__main__":
    sys.exit(main())
