# Testing strategy (Phase 12)

How to test the channel estate without a live PAS, a live OpenEyes, or any real patient
data. The strategy is layered: the cheap deterministic layers run on every change and
gate the templates; the integration layers run against **mock** OpenEyes / MPI / file
shares in an ephemeral stack. Everything is grounded in the nine channel archetypes from
`taxonomy/channel-types.md` and reuses the deterministic tooling this project already
built (`bin/build_templates.py` render-back, `bin/build_security_scan.py`).

## Non-negotiable: test data is synthetic, never real

Finding SEC-8 (`security/findings.md`) showed real patient-shaped data had leaked into
transformer sample fields. The testing regime must not re-introduce that risk.

- **No test uses a real HL7 message, a real document, or any production capture.** Not in
  fixtures, not in CI logs, not in a developer's scratch folder.
- Test fixtures are **synthetic** HL7v2 / DICOM / document payloads built from a generator
  with obviously-fake identifiers (e.g. surnames `ZZZTEST*`, NHS numbers from the
  official test range, DOBs like `1900-01-01`). A synthetic-fixture library lives under
  `testing/fixtures/` and is the only sanctioned source of test messages.
- Fixtures are reviewed the same way as code; a lint check (L1 below) rejects any fixture
  whose identifiers fall outside the reserved test ranges, so a real message pasted in by
  mistake fails CI rather than shipping.

## Test layers

| Layer | What it proves | Needs a running Mirth? | Runs in CI on every change? |
|---|---|---|---|
| L0 Template render-back | template + site row reproduces the real channel | no | yes (already implemented) |
| L1 Static config lint | XML valid; no plaintext secret; policy gates (scheme, auth, storage mode) | no | yes |
| L2 Transformer unit test | the JS filter/transformer maps a synthetic input to the expected outbound call | no (JS engine only) | yes |
| L3 Channel integration test | deployed channel makes the expected calls against mock OE/MPI | ephemeral Mirth + mocks | yes (compose stack) |
| L4 End-to-end smoke | a synthetic message traverses a real test OpenEyes | test OE instance | on demand / pre-release |

### L0 - Template render-back (implemented)
`bin/build_templates.py` already renders every site row back through its template and
asserts it reproduces that site's canonical channel (byte-exact for Newmedica, logic-exact
for Wales), aborting on any non-whitespace mismatch or surviving sample payload
(`templates/README.md`). This **is** the template regression test: any edit to a template,
a `sites.csv` row, or a token spec that breaks reproduction fails the build. Wire the
existing script into CI unchanged; a green run is the acceptance gate for template changes.

### L1 - Static configuration lint (deterministic, no runtime)
Promote the Phase 13 scan from a one-off audit to a **CI gate**. `bin/build_security_scan.py`
already extracts the signals; the lint step asserts policy over its CSV plus a few new
checks, failing the build on regression:

- **Secret hygiene:** no channel contains a literal credential - only `${REDACTED_*}`
  placeholders (the redaction contract, `canonical/NORMALISATION-RULESET.md`). A single
  real-looking secret fails CI.
- **Endpoint scheme policy:** flag any new plaintext `http://` endpoint that is not the
  agreed internal `web` host (SEC-1), so a new external plaintext call cannot slip in.
- **Listener auth policy:** flag any HTTP Listener with `authType=NONE` that is not on the
  documented allow-list (SEC-3).
- **Storage-mode policy:** flag `messageStorageMode=DEVELOPMENT` (SEC-7).
- **Reliability policy:** flag asynchronous delivery feeds (PAS-In, Document/DICOM ingest)
  with `queueEnabled=false` or `retryCount=0` (REL-1/REL-2) - a warning, not a hard fail,
  since some are deliberate.
- **XML well-formedness / schema:** each channel parses and matches its BridgeLink
  version's element shape (the corpus spans 4.4.2 / 4.5.2 / 4.6.1).
- **Fixture hygiene:** every file under `testing/fixtures/` uses only reserved test
  identifiers.

These are pure text/XML checks - fast, deterministic, no Mirth required - so they run on
every commit.

### L2 - Transformer / filter unit tests (JS engine, no Mirth)
Each channel's real logic lives in its JavaScript filter and transformer steps. Extract a
channel's transformer script and run it against a synthetic input in a JS engine (Rhino /
Nashorn / Node with a small Mirth `msg`/`channelMap`/`globalMap` shim), asserting the
outbound message and the URL/variables it would build. One test per **distinct transformer
lineage**, not per channel - the shared-lineage table (`taxonomy` 12 recurring ids) means
28 Newmedica PAS-In clones share one script and need one parameterised test, not 28.

Priority transformer tests, by archetype:
- **PAS Inbound (42):** feed a synthetic ADT^A01/A05/A08 and a merge A40; assert the built
  PASAPI URL and body (e.g. `PASAPI/V3/Patient/${HospitalNumber}` populated from PID) and
  that the version token (V1/V2/V3) matches the instance.
- **PAS Query / PDQ (8, Wales):** feed a synthetic query trigger; assert the SOAP PDQ
  request carries the right assigning-authority `BOARD_CODE` (the one real per-board delta,
  `templates/README.md`).
- **DICOM / IOL ingestion (17):** assert the routing/metadata extraction and the
  PayloadProcessor / file-write target.
- **Document ingestion/outbound (19):** assert the Document API call (`v1`/`v2/Document`)
  and the file-drop path.
- **PayloadProcessor submit (5):** assert the `request/queue/add` job payload.

### L3 - Channel integration tests (ephemeral Mirth + mocks)
Stand up a throwaway Mirth/BridgeLink in a compose stack, deploy the channel under test via
the admin REST API (the same API the deployment pipeline uses,
`deployment/deployment-automation.md`), send a synthetic message at its source connector,
and assert the calls it makes against **mock** downstreams:

- **Mock OpenEyes** - a stub HTTP server accepting the PASAPI / Core / Document routes,
  recording requests and returning canned responses (incl. error responses, to exercise
  REL-1/REL-2 behaviour).
- **Mock MPI** - a stub SOAP endpoint returning a canned PDQ response (Wales).
- **Mock file shares / DICOM** - temp directories and a stub DICOM SCP for the file/imaging
  archetypes.

Integration cases worth having per archetype: happy path (correct downstream call);
downstream-error path (assert what happens when the mock returns 5xx - does the message
error, queue, or retry, per that channel's config); and an auth-header assertion (the
Basic credential is sent, from an injected test secret, never a real one).

### L4 - End-to-end smoke (on demand)
A minimal pre-release check that a single synthetic message traverses a real **test**
OpenEyes and lands (a patient appears, a document is filed). Kept small and manual/gated
because it needs a real OE test instance; the mock-based L3 layer carries the bulk of the
integration confidence.

## Replay safety (idempotency) classification

Whether a message can be safely re-sent matters for both testing (can a test re-run without
polluting state?) and operations (can a failed message be reprocessed?). Classification is
**inferred** from the HTTP verb + endpoint semantics and must be confirmed against
OpenEyes; it is not observed behaviour.

| Archetype / operation | Replay safe? | Rationale | Confidence |
|---|---|---|---|
| PAS Query / PDQ (MPI SOAP) | Yes | read-only demographic query, no state change | inferred, high |
| PASAPI Patient GET | Yes | read | inferred, high |
| PASAPI Patient create/update (by HospitalNumber) | Yes (upsert) | keyed by hospital number, re-apply converges | inferred, med |
| PASAPI PatientAppointment (by VisitID) | Yes (upsert) | keyed by visit id | inferred, med |
| PASAPI DidNotAttend | Likely | sets a DNA state, re-applying is a no-op | inferred, med |
| PASAPI PatientMerge | **No** | merges two records; re-running after the source is gone may error or mis-merge | inferred, low - confirm |
| PayloadProcessor `request/queue/add` | **No** | enqueues a job; replay creates a duplicate job | inferred, med |
| Document create (`v1`/`v2/Document`) | **No** unless dedup | creates a document; replay duplicates unless keyed | inferred, med |
| DICOM / IOL ingestion | Depends | duplicate study handling is downstream-defined | inferred, low - confirm |

Testing implication: integration tests for the "No" rows must either target a mock (which
simply records the call) or reset state between runs; they must never be pointed at a shared
stateful OE. The "confirm" rows are open items for the OE team and are listed in
`unresolved/questions.md` alongside the other OE-semantics questions.

## Mock/stub design notes

- Mocks assert on **requests**, not just return responses: the value of L3 is proving the
  channel builds the right URL, headers, and body from a known input.
- Mock responses include **failure modes** (5xx, timeout, 401) so the reliability config
  (queue/retry, SEC/REL findings) is actually exercised rather than assumed.
- Secrets used in tests are throwaway values injected the same way production secrets are
  (`deployment/deployment-automation.md`) - the test proves the injection path too, and no
  real credential ever enters a fixture or a mock.

## CI wiring

1. On every commit: L0 (template render-back) + L1 (static lint, incl. secret + fixture
   hygiene) + L2 (transformer unit tests). All deterministic, no Mirth, fast.
2. On merge / nightly: L3 (compose stack: ephemeral Mirth + mock OE/MPI/file/DICOM),
   per-archetype integration cases.
3. Pre-release / on demand: L4 smoke against a test OpenEyes.

A change to a template, a channel, or a transformer that breaks reproduction (L0), violates
a policy gate (L1), changes a mapping (L2), or breaks a downstream contract (L3) fails
before deploy. The deployment pipeline (`deployment/deployment-automation.md`) runs the same
render + validate steps as its own pre-deploy gate, so CI and deploy share one definition of
"valid".

## Traceability

- Archetypes and the reusable-vs-client-specific split: `taxonomy/channel-types.md`
  (61 reusable-with-config channels are the L2 parameterised-test candidates).
- Existing executable gates: `bin/build_templates.py` (L0), `bin/build_security_scan.py`
  (L1 source).
- Findings that become L1 policy gates: `security/findings.md` (SEC-1/3/7, REL-1/2).
- Replay-safety and DICOM-duplicate open items: `unresolved/questions.md`.
