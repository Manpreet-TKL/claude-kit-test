# Agent contract - Mirth channel analysis

You are a worker in a coordinated analysis of exported Mirth/BridgeLink channels.
Follow these rules exactly.

## Read / write boundaries
- **READ-ONLY**: `/home/toukan/client-mirth-channels` (the original corpus). Never
  write, rename, reformat, or modify anything under it.
- **READ**: `/home/toukan/claude-kit/knowledge/mirth-channel-corpus/canonical/**` - redacted, one channel
  per file. Prefer these for analysis; they are secret-free.
- **WRITE**: only under the path your prompt gives you inside
  `/home/toukan/claude-kit/knowledge/mirth-channel-corpus/`. Emit exactly the structured output your
  prompt specifies - your output IS the return value, not a message to a human.

## Hard rules
- Never run `git add`, `git commit`, or `git push`. The orchestrator stages; the human commits.
- Never copy a secret value into any output. If you encounter one, refer to it by
  placeholder + location (e.g. "Basic-auth password in the `SFTP` connector"), never the value.
- Never invoke external APIs or attempt to reach any host named in the channels.
- Do not invoke any local skills or tools beyond reading files and emitting your output.

## Evidence discipline
- Every technical claim must cite: instance, channel name, channel id, source file,
  and the connector / filter / transformer / script location it came from.
- Never conclude two channels are equivalent from their names or directories alone -
  cite the connector or script evidence. Same channel `id` can appear under different
  names across instances (12 such ids exist); treat name and function as independent.
- Mark each finding confidence: `confirmed` (read it directly) or `inferred` (deduced).

## Corpus facts you can rely on
- 13 instances, 102 channels, BridgeLink 4.4.2 / 4.5.2 / 4.6.1.
- OpenEyes APIs: PASAPI `V1`/`V2`/`V3` (Patient, PatientAppointment, PatientMerge,
  DidNotAttend, AISFlags) and `/api/v1` (Document create/search/update, Patient/Search,
  `request/queue/add` = PayloadProcessor). PASAPI V1 = OE <=8, V2 = OE 9-10, V3 = OE 11+.
- Auth is HTTP Basic preemptive (`api` + a redacted password) in the raw exports.
- Message-scoped `channelMap` is per-message runtime state, not a dependency;
  `configurationMap`/`globalMap`/`globalChannelMap` are deployment/shared state.
