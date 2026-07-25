# Discovery mode - turning a symptom into proven steps

Read this when the input is a *reported symptom* rather than a known fault. The deliverable is unchanged (the two blockquotes in `SKILL.md`), but here you have to earn them: nothing is written down until a replay proves it.

## The loop

1. **Restate the symptom as a predicate.** "Sub-type dropdown is empty on the Document create form" is a predicate; "Documents are broken" is not. If the report can't be reduced to one observable thing that is true-when-broken and false-when-fixed, ask the reporter before spending anything. Everything below hangs off this one sentence.
2. **Rung 0 first, always** - `decodesupportid` if an identifier was quoted, then grep. See `subs/logs.md`. This alone resolves most reports to a file:line plus the reporter's user/firm/site/institution/patient ids, for zero browser cost.
3. **Guess the environment gap.** The sample database is small; a client symptom often needs a configuration the sample box lacks (a second site, an extra role, an enabled event type, a lookup row). Decide *now* whether one is likely - `subs/env-setup.md` - because setting it up is part of the walk, not an afterthought.
4. **Pick the cheapest rung that can possibly find the path** (below), and walk it **bracketed** (`subs/logs.md`): mark the logs, walk, slice.
5. **Terminate on the predicate.** Not on a screenshot, not on "looks wrong". See *The predicate*.
6. **Write the steps, then replay them** - R1, then R2. Only a passing pair earns the blockquote.
7. **Bundle the evidence** into `~/repro-evidence/<date>-<slug>/` and name it in the Evidence block.

If step 6 fails, you do not have a repro. Go back to step 4; do not write steps that were never replayed.

## Which rung - and the three gates before Chrome

The ladder is in `SKILL.md`. What decides it:

- **Rung 0** when the report names screen + action + expected/actual, or quotes a support identifier. Try this on every report.
- **Rung 1** whenever the click path is *derivable offline* - the atlas, `page-index.md` and the form tables between them give you every selector and label you need. This is the default lane, and it is the **only** lane for a confirmation replay.
- **Rung 2** only when rung 1's target image has no bundled Puppeteer (dev/debug images, remote-chrome stacks).
- **Rung 3** only when the path genuinely cannot be scripted: a gesture (drag, EyeDraw canvas, hover-only control), an autosave/modal flow whose timing matters, a report too vague to turn into an action list, a fault that needs a human watching, or a GIF as the ticket evidence.

**Three gates, all three checked, before paying for rung 3:**

1. `ls ~/claude-kit/skills/c-oe-nav/subs/canned/` - has this journey already been walked? Replay the file instead.
2. `grep '<screen>' ~/claude-kit/skills/c-oe-nav/subs/page-index.md` - does the screen have a recorded address? If it does, rung 1 can reach it.
3. Do `c-oe-nav`'s `subs/app-forms.md` / `subs/event-forms.md` / `subs/admin-forms.md` already carry the field table? If they do, you don't need a browser to find the labels.

A rung-3 session is scoped to **one job**: find the click path and narrate it. The moment it succeeds, distil it into `c-oe-nav/subs/canned/<journey>.md` (existing format, add it to the index paragraph in `c-oe-nav/SKILL.md`) so the next run of that journey is rung 1. A Chrome walk that isn't canned has been paid for twice.

## The predicate - what "reproduced" means

Every walk terminates in **exactly one** predicate, chosen in cost order:

1. **A DOM read** - `{"read":"<tight selector>"}` through `journey.mjs`. The default, and the only lane that catches the majority of OE bugs.
2. **A JSON endpoint read** - `goto` the endpoint, `read "body"`.
3. **A DB or audit row** - via `c-dblogin`; also the `SELECT MAX(id) FROM audit` bracket in `subs/logs.md`.
4. **A filesystem check** - the `ls -1 /tmp/oe_pdf* | wc -l` shape.
5. **A screenshot or GIF** - last resort. It is *ticket evidence*, never the oracle: an agent cannot reliably assert on a picture.

**The log bracket is a positive-only signal.** It fires on crash-class faults - exceptions, PHP fatals, DB errors, 403/404/500. It is silent on most OE bugs: a wrong value rendered, a missing button, a mis-sorted list, a validation message that should have fired and did not, a save that drops a field. **A clean bracket proves nothing.** Reporting "no log signature, could not reproduce" on a rendering fault is a failure, not a result. Run the bracket on every walk anyway - it costs ~200 tokens and occasionally catches a second, unreported fault - but the predicate is what decides.

## Determinism - the acceptance bar

Steps are deterministic when an **independent replay, from a state the steps themselves establish, produces the same terminal predicate**. "It worked once" is R0 and does not count.

- **R1 - clean replay.** The written steps verbatim, no improvisation, from a clean browser. Free on the Puppeteer lane: `journey.mjs` launches with no `userDataDir`, so every run is already a virgin profile. On rung 3 it is free too - the walker wipes its profile on every start (`docs/chrome-agent.md`).
- **R2 - variation replay.** The same steps with **different free choices** - another patient, another subspecialty, another context, another site, wherever the steps say "any".

| Result | Meaning |
|---|---|
| R1 pass, R2 pass | Ship it. Record both in the Evidence block, naming what R2 varied. |
| R1 pass, R2 fail | The varied dimension is **not free - it is a precondition.** Move it into the Environment setup block (or name it in the step as a data *kind*), then re-run both. |
| R1 fail | Not a repro. Back to the loop; do not write steps. |

R2 is the load-bearing half - R1 alone only proves you can replay yourself.

**Prefer repro paths that create a fresh object each run over paths that consume a one-shot state.** The sample database is 3.7 GB across 2,412 tables and the kit has no snapshot tooling, so a per-replay DB reset is not available. A repro that only works on a pristine row is a repro you can run once.

## Write policy on sample boxes

Discovery needs writes - creating an event, saving a form, adding an admin row. That is fine on a sample box and nowhere else.

**Ask once, at the start, then run free for the rest of the task.** State the target container and the kind of writes intended ("`snail-web-1`, creating Document events and one extra site under Admin"), get one go-ahead, and don't interrupt again. One interruption per bug, never per step. `journey.mjs` needs `OE_ALLOW_WRITE=1` for anything write-shaped, which is the explicit switch that makes this visible.

Never point any of this at a clinical instance.

## Subagent brief - bracketed walk (Haiku, rung 1)

Launch with the Agent tool, model `haiku`. The subagent loads no skills, so paste in what it needs.

```
You are probing a running OpenEyes sample instance to confirm a bug reproduces.
This box is disposable sample data (login admin/admin). Writes are authorised.

Predicate to test: <the one observable thing, stated so it is true when broken>.

Known navigation (trust this, do not rediscover):
<paste the relevant lines from c-oe-nav subs/paths.md / page-index.md / *-forms.md>

Do this in order:
1. Record the log mark: <paste the mark one-liner from c-oe-repro subs/logs.md>
2. Run the walk with the command below, putting the action list in OE_ACTIONS.
   Actions are single-key objects - goto/click/press/wait/read take one string;
   fill/select/upload take ["<sel>","<value>"]; selectors are CSS,
   text="Exact label", or "<sel> >> nth=N". Never wait for network-idle.
   End the list with the read that tests the predicate.
3. Slice the logs: <paste the slice one-liners>

<the docker exec command from c-oe-nav subs/probe.md, container + env adjusted,
 with -e OE_ALLOW_WRITE=1>

Return ONLY:
1. Numbered user steps with exact quoted UI labels, as a human would follow.
2. The predicate's value, quoted verbatim from the read - and whether that means
   the bug reproduced.
3. The log slice output, or the literal words "log bracket clean" if empty. A clean
   bracket is NOT evidence the bug is absent - report the predicate either way.
4. The OE version line the driver printed.
5. Anything that blocked you.
No transcripts, no screenshots unless asked.
```

## Subagent brief - path finding (rung 3, via `oe-probe-chrome`)

Only after all three gates. Invoke the **`oe-probe-chrome`** skill and hand it this shape:

```
Find the click path to <outcome> in the OpenEyes instance already open in Chrome
(already logged in). Expected: <expected>. Actual (reported): <actual>.

Narrate every UI action as a numbered step as you perform it, quoting the exact
on-screen label of each control you use and where it sits on the page. Where a
choice is free (any patient, any subspecialty), say so.

Record a GIF of the full sequence and a screenshot at the point of failure, both
into ~/artifacts.

Finish with: the full numbered steps, the exact on-screen text that shows the
fault, and whether it reproduced. Do this now with tool calls, do not answer
from memory.
```

Then: distil the result into `c-oe-nav/subs/canned/<journey>.md`, replay it once on rung 1 to get R1, vary it for R2, and only then write the blockquote.
