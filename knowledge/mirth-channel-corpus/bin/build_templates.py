#!/usr/bin/env python3
"""Phase 9 template builder (deterministic, re-runnable).

Derives a parameterised channel template from a canonical exemplar by tokenising
exactly the line positions that vary across a clone family (found positionally -
every family member is line-aligned). Emits:
  templates/<family>/channel.template.xml   exemplar with ${TOKEN} placeholders
  templates/<family>/sites.csv               one row of token values per member
  templates/<family>/params.json             token catalogue (name, where, kind)
and self-verifies: rendering each site's row back through the template must
reproduce that site's canonical channel (byte-exact where the family is
byte-aligned; logic-exact where only incidental whitespace differs).

Never touches the read-only corpus; reads canonical/ and writes templates/ only.
"""
import csv, os, re, sys, json, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAN = os.path.join(ROOT, "canonical", "_manifest.csv")

def members(pred):
    rows = [r for r in csv.DictReader(open(MAN)) if pred(r)]
    rows.sort(key=lambda r: r["channel_name"])
    return [(r["channel_name"], r["canonical_path"], open(r["canonical_path"]).read().splitlines(keepends=True)) for r in rows]

UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
# token = (name, [(line_index, regex), ...], kind, note)
# each regex has exactly one group = the per-site value on that line; all
# occurrences of a token must extract the same value.
NEWMEDICA = dict(
    family="pas-inbound-newmedica-local",
    exemplar="PAS In LOCAL-1-0",
    pred=lambda r: r["instance"] == "Newmedica" and r["channel_name"].startswith("PAS In LOCAL"),
    byte_exact=True,
    tokens=[
        ("CHANNEL_ID",   [(1, "(%s)" % UUID), (3480, "(%s)" % UUID)], "uuid",   "channel id (self-referenced in the channelMap)"),
        ("PRACTICE_CODE",[(3, r"<name>PAS In LOCAL-(.*?)-0</name>")],  "string", "practice code in the channel name"),
        ("RESPOND_AFTER_PROCESSING",[(13, r"<respondAfterProcessing>(true|false)</respondAfterProcessing>")], "bool", "source respond-after-processing toggle"),
        ("DEST_ID",      [(3477, "(%s)" % UUID)],                     "uuid",   "destination connector id"),
        ("PRACTICE_NAME",[(3478, r"<name>(.*?)</name>")],             "string", "practice / clinic display name"),
        ("UI_RED",       [(3483, r"<red>(\d+)</red>")],               "int",    "channel list colour (cosmetic)"),
        ("UI_GREEN",     [(3484, r"<green>(\d+)</green>")],           "int",    "channel list colour (cosmetic)"),
        ("UI_BLUE",      [(3485, r"<blue>(\d+)</blue>")],             "int",    "channel list colour (cosmetic)"),
    ],
)
WALES = dict(
    family="pas-query-mpi-wales",
    exemplar="OpenEyes Query - ABUHB",
    pred=lambda r: r["instance"] == "Wales" and r["channel_name"].startswith("OpenEyes Query"),
    byte_exact=False,  # boards carry incidental XSLT whitespace drift (L399, L807)
    tokens=[
        ("CHANNEL_ID",  [(1, "(%s)" % UUID)],                        "uuid",   "channel id"),
        ("BOARD",       [(3, r"<name>OpenEyes Query - (.*?)</name>")], "string", "health board short name"),
        ("LISTEN_PORT", [(17, r"<port>(\d+)</port>")],               "int",    "HTTP listener port"),
        ("BOARD_CODE",  [(77, r"QPD\.3\.2&apos;\] = (\d+)"), (755, r"vSender&quot; select=&quot;(\d+)&quot;")], "int", "MPI assigning-authority code (QPD-3.2 and XSLT vSender)"),
        ("ARCHIVE_ENABLED",[(1038, r"<archiveEnabled>(true|false)</archiveEnabled>")], "bool", "message archive toggle"),
    ],
)

# Mirth transformer sample-message fields (inbound/outboundTemplate) hold a developer
# sample message for the mapping UI - they are NOT used at runtime, and in this corpus
# some carry patient-shaped HL7/HTTP payloads (names, DOBs, hospital numbers). We blank
# their content in every emitted template so no generated file retains message data;
# behaviour is unaffected. Verification applies the same blanking to the original before
# comparing, so the reproduction claim covers channel logic and config, not these
# neutralised sample fields.
_SAMPLE_RX = [re.compile(r'(<%sTemplate(?: encoding="base64")?>)(.*?)(</%sTemplate>)' % (t, t), re.S)
              for t in ("inbound", "outbound")]
def strip_samples(text):
    for rx in _SAMPLE_RX:
        text = rx.sub(lambda m: m.group(1) + m.group(3), text)
    return text
def count_samples(text):  # blocks with non-empty content (i.e. actually neutralised)
    return sum(1 for rx in _SAMPLE_RX for m in rx.finditer(text) if m.group(2))

def build(spec):
    fam = spec["family"]
    outdir = os.path.join(ROOT, "templates", fam)
    os.makedirs(outdir, exist_ok=True)
    ms = members(spec["pred"])
    exemplar = next(m for m in ms if m[0] == spec["exemplar"])
    ex_lines = exemplar[2]

    # extract per-site values (all occurrences of a token must agree)
    sites = []
    for name, path, lines in ms:
        row = {"channel_name": name}
        for tname, occ, kind, note in spec["tokens"]:
            vals = set()
            for idx, rx in occ:
                m = re.search(rx, lines[idx])
                if not m:
                    sys.exit(f"[{fam}] token {tname} not found in {name} line {idx}: {lines[idx]!r}")
                vals.add(m.group(1))
            if len(vals) != 1:
                sys.exit(f"[{fam}] token {tname} disagrees across occurrences in {name}: {vals}")
            row[tname] = vals.pop()
        sites.append(row)

    # build template text from the exemplar, replacing exactly the captured span
    tmpl = list(ex_lines)
    for tname, occ, kind, note in spec["tokens"]:
        for idx, rx in occ:
            m = re.search(rx, tmpl[idx])
            tmpl[idx] = tmpl[idx][:m.start(1)] + "${%s}" % tname + tmpl[idx][m.end(1):]
    n_samples = count_samples("".join(tmpl))
    tmpl_text = strip_samples("".join(tmpl))  # blank runtime-irrelevant sample-message fields

    # write artefacts
    with open(os.path.join(outdir, "channel.template.xml"), "w") as f:
        f.write(tmpl_text)
    cols = ["channel_name"] + [t[0] for t in spec["tokens"]]
    with open(os.path.join(outdir, "sites.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(sites)
    params = [{"name": t[0], "kind": t[2], "occurrences": len(t[1]), "note": t[3]} for t in spec["tokens"]]
    json.dump({"family": fam, "exemplar": spec["exemplar"], "members": len(ms),
               "byte_exact": spec["byte_exact"], "parameters": params},
              open(os.path.join(outdir, "params.json"), "w"), indent=2)

    # verify: render each site back and compare to its canonical file
    def render(row):
        out = tmpl_text
        for t in spec["tokens"]:
            out = out.replace("${%s}" % t[0], row[t[0]])
        return out
    # every site-parameter token must be consumed by render (redaction
    # placeholders like ${REDACTED_PASSWORD} are deliberately left for the
    # deploy-time secret store and are not touched here)
    rendered0 = render(sites[0])
    unfilled = [t[0] for t in spec["tokens"] if "${%s}" % t[0] in rendered0]
    if unfilled:
        sys.exit(f"[{fam}] site tokens not consumed after render: {unfilled}")
    def norm(s):
        # whitespace-equivalence: collapse interior runs and drop trailing
        # spaces/tabs per line (Wales boards carry incidental XSLT indent/trailing
        # drift on L399/L807 - see byte_exact note; applied symmetrically so no
        # non-whitespace difference can be hidden).
        return "\n".join(re.sub(r"[ \t]+", " ", ln).rstrip() for ln in s.split("\n"))
    ok = wsonly = 0
    for name, path, lines in ms:
        row = next(r for r in sites if r["channel_name"] == name)
        # compare against the original with the same sample fields blanked; render()
        # output already has them blank (they were stripped from the template)
        rendered = render(row); original = strip_samples("".join(lines))
        if rendered == original:
            ok += 1
        elif norm(rendered) == norm(original):
            wsonly += 1
        else:
            sys.exit(f"[{fam}] render mismatch (not whitespace-only) for {name}")
    # confirm no sample-message payload survived into the emitted template
    leftover = count_samples(tmpl_text)
    if leftover:
        sys.exit(f"[{fam}] {leftover} sample-message field(s) not neutralised in template")
    print(f"[{fam}] members={len(ms)} tokens={len(spec['tokens'])} "
          f"byte-exact={ok} whitespace-only={wsonly} sample-fields-neutralised={n_samples}  -> OK")
    return len(ms), len(spec["tokens"])

if __name__ == "__main__":
    for spec in (NEWMEDICA, WALES):
        build(spec)
