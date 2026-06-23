# oe-deploy — build gates (volatile)

`build.sh` runs a chain of checks before it assembles the compose file. The exact list, ordering, and messages drift; this is the **current** snapshot, read straight from `build.sh`. The script is the source of truth — if this disagrees, fix this file.

## Gates, in order

| # | Gate                              | Fail message (gist)                                   | Fix |
|---|---                                |---                                                    |---  |
| 1 | Disk free                         | "Disk usage is above 94%"                             | Free space (threshold is 94% on `/`). |
| 2 | `.oedeploy` sourced, every var non-empty | "Variable 'X' in .oedeploy has no value"       | Fill the blank var (e.g. `appName`). |
| 3 | Prod with running containers (prompt) | asks to type `yes` to continue                    | Only fires when `machineName=prod` and containers are up; pass `-y` to skip. |
| 4 | No loose key files                | "the files below still exist… import them into Keeper" | Remove keeper.csv, private.key, public-key.gpg, `~/.ssh/<client>{,.pub}`. |
| 5 | `.env` exists                     | ".env file not found"                                 | Run `environment-setup.sh` first. |
| 6 | `my.cnf.d/my.cnf` present (if `SERVICES` has `db`) | "no my.cnf in …/my.cnf.d/"            | `cp my.cnf.d/my.cnf.c4m16 my.cnf.d/my.cnf`. |
| 7 | `.env` keys == `templates/<appName>.env` keys | "not found in .env" / "deleted from template" | Sync `.env` against the template (opens `code -d` if `code` is installed). |
| 8 | host mariadb client ≥ `DB_TAG`    | "update the MariaDB client on this machine"           | `bash host-setup.sh -u` or re-add the mariadb apt repo. |
| 9 | OE ≥ 7.0.0 ⇒ `DB_TAG` ≥ 10.6      | "update the MariaDB being used … to at least 10.6"    | Bump `DB_TAG` (and migrate the volume if needed). |
|10 | `-u` only with `DATABASE_HOST=db` | "-u option is only supported when DATABASE_HOST=db"   | Drop `-u` for RDS / external DBs. |
|11 | `TZ` valid and == host timezone   | "Invalid timezone" / "Host timezone does not match"   | `sudo timedatectl set-timezone $TZ` or fix `.env`. |
|12 | `DOMAIN_NAMES` all backtick-quoted (if `SERVICES` has `tfk`) | "is not enclosed in backticks" | Wrap every domain in backticks; non-empty when tfk is used. |

There is no MariaDB "data-volume-creation-tag" gate in `build.sh` — gates 8/9 are about the **client** version on the host and the OE-vs-DB minimum.

## "Type yes" — where it actually is

`build.sh` has exactly one interactive prompt: gate 3 (prod machine with running containers), and it lowercases the reply, so `yes`/`YES`/`Yes` all pass and `-y` skips it entirely. `echo yes | bash build.sh` is harmless but unnecessary on a fresh host. The other scripts:

- `environment-setup.sh -o` (overwrite secrets) gives a 10-second CTRL+C window, not a typed `yes`.
- `db-setup.sh` only prompts `Y/N` if `appName` doesn't match the chosen setup flags.

So there is **no** destructive typed-`yes` gate to memorise.

## When a gate fails

No `--force` flags exist (adding them was rejected in design review). Fix the underlying cause. If a gate is genuinely wrong for a new app, change the gate in `build.sh` (and update this file), don't paper over it.
