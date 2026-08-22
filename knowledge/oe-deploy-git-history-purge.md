# oe-deploy: finding bloat, backing up safely, and purging files from all history

This is a runbook for the `oe-deploy` repo (`git@github.com:ToukanLabs/oe-deploy.git`,
default branch `main`). `oe-deploy` is meant to be a few **kilobytes of templates** — but
its `.git` is currently **~278 MB**. That weight is almost entirely accidentally-committed
generated junk sitting in history: huge `.xlsx` settings dumps, copies of `aws_cron.log`,
and a 25 MB report. This doc shows how to find it, back up so nothing you do is
irreversible, and surgically remove it as though it was never pushed.

> **Read this first — the one thing that makes history-rewriting safe:**
> You cannot "edit" git history in place. You make a *new* history and force-push it over
> the old one. So the only real safety net is **a backup taken before you touch anything**
> (section 2). Do that, and the worst outcome of any command in section 3 is "throw away
> the rewrite and restore from backup". Skip it, and a bad rewrite + force-push is genuinely
> painful to recover.

---

## 0. Context that matters for *this* repo

- There are **~115 remote branches**, the vast majority `client/*` (e.g. `client/Optegra-PROD`,
  `client/Wales-PROD`). These are live per-environment branches.
- Rewriting history rewrites **every commit on every branch and tag**. After a rewrite you
  must force-push *all* of them, and **anyone with a clone (every host running oe-deploy)
  must re-clone or hard-reset** — their old history no longer matches. Coordinate this; don't
  do it silently on a Friday.
- `main` (and possibly some `client/*` branches) may have **branch protection / force-push
  blocks** on GitHub. You will need to temporarily lift those to push the rewrite, then
  re-enable them.
- The junk is **not secret** (settings xlsx, cron logs). If it *were* secret (keys, DB dumps),
  rewriting history is necessary but **not sufficient** — see section 4.

---

## 1. List the top 10 largest files across the whole repo (all branches, all history)

`du` only sees your current checkout. To see what's actually inflating `.git`, you have to
walk every object in every branch/tag. Run from inside the repo:

```bash
cd ~/oe-deploy

git rev-list --objects --all \
  | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \
  | awk '/^blob/ {print $3, $4}' \
  | sort -rn \
  | head -10 \
  | numfmt --to=iec --field=1
```

- `git rev-list --objects --all` — every object reachable from **all refs** (every branch + tag).
- `git cat-file --batch-check` — looks up each object's type, size, and path.
- `awk '/^blob/'` — keep only file contents (drop trees/commits).
- `sort -rn | head -10` — biggest ten; `numfmt` makes bytes human-readable.

For **this repo today** that prints:

```
58M  commands/oe_settings_portsmouth_prod_2024_10_15_14_35_37.xlsx
58M  commands/oe_settings_portsmouth_uat_2024_10_15_17_22_57.xlsx
47M  commands/oe_settings_2024_10_15_13_58_50.xlsx
47M  commands/oe_settings_2024_10_15_13_49_58.xlsx
47M  commands/oe_settings_2024_10_15_14_18_05.xlsx
32M  logs/aws_cron.log
32M  logs/aws_cron.log        # a different historical version of the same path
25M  commands/reports/event_image_report.txt
23M  logs/aws_cron.log
9.2M logs/aws_cron.log
```

The same path appearing several times = multiple historical versions of one file, each a
distinct blob still stored in the pack. **Every one of these contributes to the 278 MB.**

### Variant: collapse to the largest version per path

If you'd rather see "which *paths* are worst" (deduped, summed across versions is overkill —
this shows the single largest blob per path):

```bash
git rev-list --objects --all \
  | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \
  | awk '/^blob/ && $4 {print $3, $4}' \
  | sort -k2 -k1,1rn | sort -u -k2,2 \
  | sort -rn | head -10 \
  | numfmt --to=iec --field=1
```

### Sanity check on overall size

```bash
git count-objects -vH      # size-pack = what the repo actually weighs after packing
```

---

## 2. Back up the entire repo so nothing is irreversible

Take **two** kinds of backup. They protect against different mistakes. Always write them
**outside** `~/oe-deploy` so a bad command in the repo can't touch them.

### 2a. Full mirror (every branch, tag, and ref — the important one)

A mirror clone is a complete, self-contained copy of all history and all refs. This is the
thing you restore from if a rewrite goes wrong.

```bash
cd ~
git clone --mirror git@github.com:ToukanLabs/oe-deploy.git oe-deploy-backup-$(date +%Y%m%d).git

# verify it's intact, then snapshot it as a tarball
git -C oe-deploy-backup-$(date +%Y%m%d).git fsck --full
tar czf oe-deploy-backup-$(date +%Y%m%d).git.tar.gz oe-deploy-backup-$(date +%Y%m%d).git
```

`--mirror` (not a plain clone) is what guarantees **all** `client/*` branches and tags come
along, not just `main`.

**If the rewrite goes wrong, this is your undo:** the mirror still holds the original refs,
so you can force-push them all back:

```bash
git -C oe-deploy-backup-YYYYMMDD.git push --force --mirror git@github.com:ToukanLabs/oe-deploy.git
```

### 2b. Single-file bundle (portable, e.g. to stash off-box)

A bundle packs all history into one file you can copy anywhere and clone from later:

```bash
cd ~/oe-deploy
git bundle create ~/oe-deploy-$(date +%Y%m%d).bundle --all
# restore/inspect later with:  git clone ~/oe-deploy-YYYYMMDD.bundle restored-check
```

### 2c. (Optional) Working-tree snapshot — captures your *uncommitted* and gitignored files too

The mirror and bundle only contain committed history. `oe-deploy` working trees also hold
**gitignored secrets** (`secrets/`, `certs/`, `config/`, `.env`, decrypted gitsecret files).
If this checkout is a live host you care about, also snapshot the directory verbatim:

```bash
cd ~
tar czf oe-deploy-fulldir-$(date +%Y%m%d).tar.gz oe-deploy
```

> Rule of thumb: **2a is mandatory before any history rewrite.** 2b/2c are cheap insurance.

---

## 3. Remove accidentally-pushed logs (and other junk) from the *entire* history

Goal: make `logs/aws_cron.log`, the `commands/*.xlsx` dumps, and the report disappear from
**every commit on every branch**, as if never committed — shrinking `.git` back toward
kilobytes.

`git rm` only deletes a file going *forward*; the old blobs stay in history. To erase them
from the past you must **rewrite history**. The right tool is
[`git-filter-repo`](https://github.com/newren/git-filter-repo) — it is the officially
recommended replacement for the slow/dangerous `git filter-branch`.

> **Pre-flight:** you did section 2a, right? Don't proceed otherwise.

### 3.1 Get `git-filter-repo` (it isn't installed on this box)

It's a single Python3 FOSS script. Pick whichever is least intrusive on the host:

```bash
# Option A — pipx (isolated, no system pollution)
pipx install git-filter-repo

# Option B — pip (user-local)
pip install --user git-filter-repo

# Option C — no host install at all: just drop the one script on PATH
curl -fsSL https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo \
  -o ~/.local/bin/git-filter-repo && chmod +x ~/.local/bin/git-filter-repo

# Option D — fully dockerised (no host changes; run against a mirror clone)
#   from inside the directory that contains your mirror clone:
docker run --rm -v "$PWD:/work" -w /work python:3.12-slim bash -c \
  "pip install --quiet git-filter-repo && \
   cd oe-deploy-rewrite.git && git filter-repo --force <YOUR FLAGS HERE>"
```

Verify: `git filter-repo --version`.

### 3.2 Do the rewrite on a *fresh mirror clone* (cleanest, safest)

`git-filter-repo` is happiest on a fresh clone and, by design, **removes the `origin`
remote** afterwards (so you can't accidentally push a half-baked rewrite). Working on a
dedicated mirror keeps your normal `~/oe-deploy` checkout untouched until you're happy.

```bash
cd ~
git clone --mirror git@github.com:ToukanLabs/oe-deploy.git oe-deploy-rewrite.git
cd oe-deploy-rewrite.git
```

### 3.3 Choose what to strip

**By exact path / glob (precise — recommended when you know the culprits):**

```bash
git filter-repo \
  --path logs/aws_cron.log \
  --path-glob 'logs/*.log' \
  --path-glob 'commands/oe_settings_*.xlsx' \
  --path commands/reports/event_image_report.txt \
  --invert-paths
```

`--invert-paths` = "keep everything *except* these". Drop or add `--path*` lines to taste.

**By size (catch-all — nukes every blob over a threshold, regardless of name):**

```bash
git filter-repo --strip-blobs-bigger-than 5M
```

This is the blunt instrument that reliably gets oe-deploy back to template-size, since every
offender in section 1 is multi-megabyte and legitimate templates are tiny. You can combine:
do the size strip, then a path strip for anything smaller you also want gone.

After it runs, re-check:

```bash
git count-objects -vH        # size-pack should have dropped dramatically
git rev-list --objects --all \
  | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \
  | awk '/^blob/ {print $3,$4}' | sort -rn | head -10 | numfmt --to=iec --field=1
```

The xlsx/log/report entries should be gone from the top-10.

### 3.4 Push the rewritten history back

`filter-repo` stripped the remote; re-add it and force-push **all branches and tags**:

```bash
git remote add origin git@github.com:ToukanLabs/oe-deploy.git
git push --force --all origin
git push --force --tags origin
```

> If GitHub rejects the push: a branch (likely `main`, maybe protected `client/*` PROD
> branches) has **force-push protection**. Temporarily disable it in
> *GitHub → repo → Settings → Branches*, push, then re-enable.

### 3.5 Everyone else must re-sync

Every other clone (every host running oe-deploy) now has stale history. They each either
re-clone, or force their local branch to the rewritten remote:

```bash
git fetch origin
git reset --hard origin/<their-branch>
# stale unreachable objects locally:
git reflog expire --expire=now --all && git gc --prune=now --aggressive
```

Do **not** let someone `git pull` and `git push` an old clone afterwards — that reintroduces
the deleted blobs. This is the single most common way a history purge "comes back".

### 3.6 Stop it happening again

`.gitignore` already has `logs/*`, `*.csv`, `*.sql`, etc. — but `logs/aws_cron.log` is still
**tracked** (it was committed before the ignore rule, and ignore rules don't apply to
already-tracked files). After the purge, also untrack it going forward and confirm the rules
cover the junk you just removed:

```bash
cd ~/oe-deploy
git rm --cached logs/aws_cron.log            # stop tracking; .gitignore handles the rest
# add patterns for the dumps if you generate them again:
printf '\ncommands/oe_settings_*.xlsx\ncommands/reports/*.txt\n' >> .gitignore
git add .gitignore
# (commit is yours to make)
```

---

## 4. If any of the purged files were ever secret

The xlsx settings and cron logs here are not credentials, so this section is informational.
But if a future purge targets keys / DB dumps / `.env`:

1. **Rewriting history does not retroactively un-leak anything.** Treat the secret as
   compromised and **rotate it** regardless.
2. On **GitHub specifically**, force-pushing makes old commits *unreachable* but they can
   linger (reachable by SHA, cached in PRs/forks) until GitHub garbage-collects. To force
   immediate purge of sensitive blobs, open a request with **GitHub Support** after your
   force-push.

---

## TL;DR

```bash
# 1. See the bloat
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \
  | awk '/^blob/{print $3,$4}' | sort -rn | head -10 | numfmt --to=iec --field=1

# 2. Back up first (your undo button)
git clone --mirror git@github.com:ToukanLabs/oe-deploy.git ~/oe-deploy-backup.git

# 3. Rewrite on a fresh mirror, then force-push all refs
git clone --mirror git@github.com:ToukanLabs/oe-deploy.git ~/oe-deploy-rewrite.git
cd ~/oe-deploy-rewrite.git
git filter-repo --strip-blobs-bigger-than 5M     # or --path/--path-glob ... --invert-paths
git remote add origin git@github.com:ToukanLabs/oe-deploy.git
git push --force --all origin && git push --force --tags origin

# 4. Everyone re-clones / hard-resets. Don't push from a stale clone.
```
