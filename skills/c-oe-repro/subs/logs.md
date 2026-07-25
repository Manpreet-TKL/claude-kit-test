# Bracketing a walk - support identifiers, logs, audit, evidence

Everything here runs against a **sample box**, never a clinical instance. `<web>` is the OE web container (`docker ps` -> `<stack>-web-1`); `-w /var/www/openeyes` matters on every command, because the in-tree paths are the only ones present on all images.

## Rung 0 - the support identifier

OE's error page prints a **support identifier** like `E-26.0.0-DMH8Q3-85-1-12D-1-1-0-QWM-YF-K`, which a reporter can quote verbatim from a screenshot. The app decodes it:

```
docker exec -w /var/www/openeyes <web> php protected/yiic decodesupportid E-26.0.0-DMH8Q3-85-1-12D-1-1-0-QWM-YF-K
```

That returns the throwing **file:line** (e.g. `protected/services/ModelService.php:133`) *plus* the user, firm, site, institution and patient ids the fault occurred under - so it gives you both the code location and the reporter's exact configuration, which is usually the whole environment gap, for zero browser cost.

**It ships with the `OEExceptionHandler` module**, not core - `protected/modules/OEExceptionHandler/commands/DecodeSupportIdCommand.php`. Verified 2026-07-25: present in `yiic`'s command list on a 26.0.0 live image, and absent along with the whole module on an older dev sample stack. So check the target before promising a decode; `php protected/yiic` lists it when it's there.

**Ask for it.** If a report doesn't quote one and the symptom is an error page, asking the reporter for that string is cheaper than any walk. It is a hash-plus-context token, not patient data - but the ids it decodes to are, so keep the decoded output out of the ticket body (see *PII*).

## The log inventory (verified on a dev stack and on a 26.0.0 live image)

| Path (relative to `/var/www/openeyes` unless absolute) | What it holds | Present on |
|---|---|---|
| `protected/runtime/application.log` | Yii app log; faults appear as `[error] [exception.*]` lines | always |
| `protected/runtime/OEExceptionHandlerLogs/<support-id>.log` | one JSON file per unhandled exception: `{user, error:{oe_version, error_hash, error:{class,message,line,file,trace}}, request}` | where the `OEExceptionHandler` module is installed |
| `/var/log/php/errors.log` | PHP warnings, notices, fatals | most images |
| `protected/runtime/debug.log` | duplicates `application.log` at higher verbosity | opt-in only |
| Apache `access.log` / `error.log` | 15-34M; only proves a request fired | opt-in only |

**Always use the in-tree `protected/runtime/OEExceptionHandlerLogs` path.** A top-level `/OEExceptionHandlerLogs` symlink exists on the dev image only.

And **presence-check the module, not the directory** - `protected/modules/OEExceptionHandler/` is custom and absent from some checkouts, but `protected/runtime/OEExceptionHandlerLogs/` exists anyway (verified 2026-07-25: dir present, module absent, on a dev sample stack). Checking the dir therefore tells you nothing, and an empty `find` reads as "no exception occurred" when the truth is "nothing was ever going to write here". When the module is missing, fall back to `application.log`'s `[exception.*]` lines, which carry the same class/message/trace in a less convenient shape.

## The bracket - mark before, slice after

Three one-liners. Run the first before the walk, the other two after.

```
docker exec -w /var/www/openeyes <web> sh -c 'date +%s; stat -c "%s %n" protected/runtime/application.log /var/log/php/errors.log 2>/dev/null'
```

```
docker exec -w /var/www/openeyes <web> sh -c 'tail -c +<size+1> protected/runtime/application.log | grep -E "\[(error|warning)\]" -A3'
```

```
docker exec -w /var/www/openeyes <web> sh -c 'find protected/runtime/OEExceptionHandlerLogs -name "*.log" -newermt @<epoch>'
```

Substitute `<size+1>` from the `stat` line and `<epoch>` from the `date +%s` line. Then `docker cp` any file `find` names into the evidence bundle.

**Four ways this bites:**

1. **`tail -c +N` is 1-indexed.** The offset is the recorded size **plus one**, not the size. Off by one and you re-read the last byte of the pre-walk log or, worse, silently believe an offset that was never applied.
2. **A post-walk size *smaller* than the mark means the log rotated** mid-walk (`maxLogFiles => 30`, 1M default cap). The slice is then meaningless - fall back to reading the whole current file plus `application.log.1`.
3. **The exception dir is a symlink on some images and a real directory on others.** `find` follows neither by default in the same way - if it returns nothing on a stack you know threw, re-run with `find -L`.
4. **`/var/log/php` is absent on some images.** The `2>/dev/null` on the mark hides that; if the slice command errors, drop that path rather than concluding the log was empty.

### Noise filter

`application.log` is chatty. `[error]`/`[warning]` plus three lines of context is the useful slice; ignore `[info]` and `[trace]` entirely. Recurring benign lines on a sample box: session GC notices, `PHP Notice: Undefined index` from legacy views, and asset-publish messages on the first request after a cache clear. If a line appears in the pre-walk tail as well, it is background, not your fault.

### The audit bracket

Cheaper than it looks and often more informative than the logs, because it names the request URIs the walk actually hit and the event ids it created. Needs `c-dblogin` (client is `mariadb`, root password in a file):

```
docker exec <stack>-db-1 bash -c 'mariadb -uroot -p$(cat $MYSQL_ROOT_PASSWORD_FILE) -N openeyes -e "SELECT MAX(id) FROM audit"'
```

```
docker exec <stack>-db-1 bash -c 'mariadb -uroot -p$(cat $MYSQL_ROOT_PASSWORD_FILE) -N openeyes -e "SELECT a.id, ac.name, t.name, a.event_id, a.request_uri FROM audit a JOIN audit_action ac ON ac.id=a.action_id JOIN audit_type t ON t.id=a.type_id WHERE a.id > <N> ORDER BY a.id"'
```

Both joins are needed: `audit` stores `action_id`/`type_id`, not names (verified 2026-07-25 - a query for `action`/`target_type` fails with `Unknown column`). Output is one row per audited request, e.g. `4721 login-successful login NULL /site/login`.

## The load-bearing caveat

**The bracket is a positive-only signal.** It fires on crash-class faults - exceptions, PHP fatals, DB errors, 403/404/500. It is silent on the majority of OE bugs: a wrong value rendered, a missing button, a mis-sorted list, a validation message that should have fired and did not, a save that quietly drops a field.

**A clean bracket proves nothing.** Never report "no log signature, so it could not be reproduced" - that conflates "the app didn't crash" with "the app behaved correctly". The repro's terminal predicate decides (`subs/discovery.md`); the bracket is corroboration when it fires and silence when it doesn't.

## The evidence bundle

One directory per bug, on the host: `~/repro-evidence/<date>-<slug>/`, e.g. `~/repro-evidence/2026-07-25-document-subtype-missing/`. Name it in the Evidence block; attach its files to the ticket. Typical contents:

- `application-slice.log` - the bracketed slice only
- `<support-id>.log` - the exception JSON, `docker cp`'d out
- `php-errors-slice.log` - if the walk produced any
- `audit-slice.txt` - the `id > N` rows
- `screenshot.png` / `walk.gif` - only if a rung-3 walk produced them
- `predicate.txt` - the before and after values of the terminal predicate, verbatim

## PII - attach the slice, never the file

Sample data is disposable, but the log format is not: **`application.log` carries usernames, institution and site names and client IPs; the exception JSON carries `user.name`, `user.email` and `patient_id`; the audit slice carries patient ids.** So:

- Attach the **bracketed slice**, never the whole file.
- Only ever from a **sample box**. Never lift a log off a clinical instance into a ticket.
- Nothing from any of these files goes into the Steps or Environment setup blockquotes - those stay client-agnostic. Decoded support-identifier ids (user/firm/site/institution/patient) are a *hint to you* about the reporter's configuration; translate them into a data *kind* or an admin setup step, and leave the numbers out.
