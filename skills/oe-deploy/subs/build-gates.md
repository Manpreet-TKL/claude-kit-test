# oe-deploy — build gates (volatile)

`build.sh` runs a chain of gates before it will assemble the compose file. The exact list, ordering, and error messages drift; this is the **current** snapshot.

## Standard gates (in order)

| # | Gate                          | Fail message (gist)                              | Fix |
|---|---                            |---                                               |---  |
| 1 | Disk free                     | "/ is N% full, refusing to build"                | Free space; the threshold is 94%. |
| 2 | `.oedeploy` exists & non-empty| "no .oedeploy file"                              | `cp .oedeploy.example .oedeploy` and edit. |
| 3 | No loose key files            | "found key file on disk: <path>"                 | Move into volumes/secrets dir. |
| 4 | `.env` keys match example     | "missing key: X" / "orphan key: Y"               | Sync against `.env.example`. |
| 5 | MariaDB tag matches volume    | "data volume was created on N, .env pins M"     | Match the tag or migrate the volume. |
| 6 | `TZ` set                      | "TZ unset"                                       | Add `TZ=` to `.env`. |
| 7 | `DOMAIN_NAMES` backtick-quoted| "DOMAIN_NAMES not backtick-quoted"               | Wrap in backticks, even single domains. |

## Disruptive gates

Anything that destroys data (volume wipe, DB reset, image purge) requires typing literal `yes`. The check is:

```bash
read -r CONFIRM
[ "$CONFIRM" = "yes" ] || abort "user did not confirm"
```

So `y`, `YES`, `Y`, and `echo y | ./build.sh` all fail by design — that's the safety. The one allowed shortcut for first-run is `echo yes | ./build.sh` on a known-empty host.

## When a gate fails

Don't bypass with `--force` flags — they don't exist, and adding them was rejected in design review. Fix the underlying cause. If a gate is genuinely wrong for a new app, change the gate (and update this file), don't paper over it.
