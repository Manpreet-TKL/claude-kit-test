# OE-18464: remaining unique-code problems and three solution options

Reviewed: 2026-09-08. Scope: OE-18464 as merged into `release/26.0.x`, running on
MariaDB 11.8 with standard RDS parameters. This is a review and design note, not
an implemented fix or a claim that any replacement has passed release testing.

| Source | Pinned revision |
|---|---|
| Merged release reviewed | `29e98ef506159bc730fd5037cc5d0c13f341a858` |
| Original `fix/OE-18464` head | `8defab8b94567853105455453fe6dca498cc1cc5` |

The release was refreshed before writing this note. The findings below concern
its unique-code path, not every problem elsewhere on the branch.

The earlier [unique-code note](oe-unique-codes.md) describes older releases.
Its statements that the repository has no backfill command and no unique index
on the code value must not be applied to this release. The separate
[lock-contention note](oe-event-table-lock-contention.md) covers the wider
event/user locking investigation; those mechanisms are not all allocator bugs.

## 1. What is wrong with the merged implementation?

### What the PR fixes, and what MariaDB 11.8 changes

The old allocator explicitly locked tables. That could commit event work before
the surrounding save had finished and introduced a strong table-lock request
into a heavily connected schema. Removing it is a real improvement: the new
mapping INSERT remains part of the event transaction, and that allocation path
no longer requests those table locks. MariaDB documents the implicit commit in
[LOCK TABLES](https://mariadb.com/docs/server/reference/sql-statements/transactions/lock-tables).

The replacement serialises new allocations through one named lock and chooses
from a small list of apparently free codes. That combination is not reliable
under overlapping event saves.

| Relevant setting | Standard target assumption | Consequence |
|---|---|---|
| Transaction isolation | `REPEATABLE READ` | Ordinary reads can continue seeing the pool as it was earlier in the transaction. |
| `innodb_snapshot_isolation` | `ON` in MariaDB 11.8 | Some stale-view locking/write conflicts abort the transaction with error 1020. |
| `innodb_rollback_on_timeout` | `OFF` | A normal InnoDB row-lock timeout usually rolls back only its statement. |
| `innodb_lock_wait_timeout` | Engine default 50 seconds | The allocator temporarily reduces this to 2 seconds for its INSERT attempts. |
| Binary-log format | RDS family default `MIXED` | This does not turn ordinary pool reads into fresh reads or remove locks. |

These are default-family/engine assumptions, not a reading of a particular
deployment's effective sessions. A missing value in RDS engine-default output
means inheritance, not `OFF`. Confirm actual session overrides before rollout.
See [RDS MariaDB parameters](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.MariaDB.Parameters.html),
[transaction isolation](https://mariadb.com/docs/server/reference/sql-statements/administrative-sql-statements/set-commands/set-transaction),
[InnoDB variables](https://mariadb.com/docs/server/server-usage/storage-engines/innodb/innodb-system-variables),
and [binary-log formats](https://mariadb.com/docs/server/server-management/server-monitoring-logs/binary-log/binary-log-formats).

MariaDB 11.8 therefore does not make the remaining allocation problem go away.
It also makes correct handling of whole-transaction conflicts particularly
important. The deployment's database version, not the branch name, determines
these database behaviours.

### 1.1 An event can miss its code even when plenty are available

Scenario: several clinicians save events at roughly the same time. Each save
has an older picture of which codes are unused. One save takes a code, then
another tries a code that its picture still shows as free. The database correctly
rejects the duplicate. After a few failures, the second save gives up, even
though many different codes remain available elsewhere in the pool.

Exactly what is wrong:

1. The default shortlist contains 10 candidates, with at most 5 claim attempts.
2. The shortlist is read only once. A failed claim does not fetch a genuinely
   fresh list or progress to candidates outside that list.
3. Under the target isolation level, obtaining the named lock does not renew
   the transaction's earlier picture of the mappings.
4. The fallback search runs only if the first shortlist is empty. A nonempty
   but entirely stale shortlist does not trigger it.
5. The named lock is released before the event transaction commits. The next
   allocator can therefore run while the previous mapping is still uncommitted.

The same visibility problem affects the check for an existing event mapping:
another request may already have mapped that event, while the losing request's
ordinary recheck cannot yet see it.

The unique constraints prevent duplicate assignments; the failure is missing
codes and unnecessary retries, not proof of duplicate mappings. Increasing the
window to 50 can reduce failures but does not establish correctness. The relevant
load is all allocations since a save's first read, not just simultaneous calls
inside the allocator. See [allocator selection and claiming][allocator].

### 1.2 One blocked allocation makes unrelated allocations queue behind it

Scenario: a mapping needs to check a referenced event or user row, but another
transaction is modifying that row. The allocator waits while still holding the
single shared allocation lock. Other clinicians saving entirely different
events cannot enter the allocator until that wait ends or their own wait expires.

Exactly what is wrong: the named lock surrounds database work that can itself
wait for row locks, including foreign-key and unique-index checks. The 3-second
`GET_LOCK` timeout limits waiting to enter, not how long the holder may stay
inside. Five INSERT attempts can each wait up to 2 seconds, producing roughly
10 seconds of row-lock waiting inside the shared lock alone. Other statements,
metadata waits and I/O mean this is not a hard 10-second overall deadline.

Waiting web requests also retain locks acquired earlier in their event saves.
The result can spread contention to other work using those rows. This is not
the old explicit table lock and does not establish that the whole database must
freeze. See [allocator timeout and lock scope][allocator] and
[MariaDB named-lock semantics](https://mariadb.com/docs/server/reference/sql-functions/secondary-functions/miscellaneous-functions/get_lock).

### 1.3 Backfill and an edit can wait for each other

Scenario:

1. A clinician edits an older event that has no code. The save holds a write
   lock on that event row.
2. Backfill selects the same event and gets the shared allocation lock.
3. Backfill tries to insert the mapping. Its foreign-key check waits for the
   clinician's event-row lock.
4. The clinician's save reaches allocation and waits for the allocation lock
   held by backfill.

This is a circular wait across a named lock and a database row lock. The current
timeouts can break the cycle, so it need not be a permanent deadlock. However,
the web save can report allocation failure and make unrelated saves wait too.
Backfill may then supply the code after the web save commits.

The backfill's minimum event age does not prevent an old event being edited now.
Its separate command-level lock only prevents two backfills running together;
it does not fix this interaction with web saves. Backfill needs to acquire the
target event non-blockingly before reserving a code, and defer busy events.
See [backfill selection and allocation][backfill].

### 1.4 The proposed repair cannot repair CVI

Scenario: a CVI saves without a code. Support follows the log's instruction to
backfill that specific event. The command reports no missing mappings and leaves
the CVI unchanged.

Exactly what is wrong: the controller allocates for both cataract operation
notes and CVI, but backfill always filters to `OphTrOperationnote` and joins the
cataract element table. Supplying a CVI event ID adds another filter; it does
not replace the operation-note restriction. The two paths need one shared
definition of eligibility. See [controller eligibility][eligibility] and
[backfill filters][backfill].

### 1.5 Backfill can report success after failing to repair events

Scenario: the scheduled repair runs with an empty pool, encounters contention,
or catches a database error. It prints failures but exits successfully. A
scheduler that checks the exit status sees a healthy job while codes remain
missing.

Exactly what is wrong: `$failed` is counted, but the normal completion path
still returns `0`. Return a documented nonzero status for incomplete repair and
expose created, already present, deferred, failed and remaining counts. A targeted
request should distinguish an ineligible/missing event from successful repair.
See [backfill result handling][backfill].

### 1.6 The warning promises a repair that the PR does not arrange

Scenario: a clinician is told the code will be added shortly. No repair job has
been configured, or the event is CVI and excluded by the command. The event
remains without the reference an external workflow expects.

Exactly what is wrong: adding a console command is not scheduling reliable
repair. Topping up the pool only creates spare codes; it does not attach them to
existing events. Saving the event again can attempt allocation, but that is not
automatic recovery. The message must describe the actual recovery service, or
say that support action is required. See [failure messages][warnings].

### 1.7 A repair log can describe an event that never committed

Scenario: allocation fails and emits a repair log. Later work in the event save
fails, so the transaction rolls back. Support now has a missing-code instruction
for an event that was never successfully created.

Exactly what is wrong: the warning shown to the user is deferred until after
commit, but `OELog::log(...)` runs immediately inside `updateUniqueCode()`.
Defer a committed-repair log too, or explicitly label it as a failed allocation
attempt rather than committed repair work. Discard pending repair notifications
on rollback. See [warning/log timing][warnings] and [save boundaries][create-save].

### 1.8 Ordinary deadlocks and MariaDB 11.8 conflicts can still fail the save

Scenario: two transactions need overlapping event/user rows in incompatible
orders, or a transaction tries to lock/modify a row incompatible with its older
snapshot. MariaDB chooses a transaction to roll back. The clinician's save fails
because there is no complete-save retry here.

Exactly what is wrong with treating the PR as a complete concurrency fix:
allocator-local handling covers duplicate keys and some row-lock timeouts. It
rethrows error 1213 and error 1020. That is safer than continuing in a transaction
that MariaDB has already rolled back, but the outer save must handle recovery.
Retrying just the mapping INSERT would not restore the event, elements or audit
writes lost with that transaction.

This is a remaining whole-save limitation, not a claim that OE-18464 introduced
all such conflicts. Version-snapshot lock upgrades on `event` and `user` are
separate paths. Removing allocation locking does not repair them. See
[allocator exception handling][allocator], [update-save rollback][update-save],
the [separate locking note](oe-event-table-lock-contention.md), and the
[snapshot-isolation variable](https://mariadb.com/docs/server/server-usage/storage-engines/innodb/innodb-system-variables#innodb_snapshot_isolation).

### 1.9 Conditional lock-handling defects and missing regression coverage

| Issue | Plain-English consequence | Qualification |
|---|---|---|
| One fixed named-lock name for the database server | Separate application databases on one server can queue behind one another. | Applies only to that hosting topology. |
| `GET_LOCK` result cast to an integer | A database error returning `NULL` is described as ordinary contention. | Handle success, timeout and error separately. |
| Timeout setup is outside the cleanup `try`; restoration precedes unlock in one `finally` | A setup/restoration failure can skip the release attempt on a surviving connection. | Exceptional cleanup defect, not the main steady-state bottleneck. |
| Contention test supplies already-taken IDs through a test subclass | It does not cover real simultaneous connections, old read views, or the edit/backfill cycle. | Existing focused tests do not establish high-concurrency safety. |

See [allocator lock lifecycle][allocator] and [allocator tests][allocator-tests].
If a named lock is retained temporarily, scope its name appropriately, preserve
error distinctions and guarantee an unlock attempt even if timeout restoration
fails. This cleanup does not solve the underlying allocation design.

The release also contains a [unique index on `unique_codes.code`][code-index].
Verify it actually exists as a unique index in the deployed schema: a failed
migration or pre-existing duplicate values cannot be dismissed because the
migration file is present. Historical duplicates require careful reconciliation
of clinical references, not automatic deletion. This is a migration prerequisite,
not a newly demonstrated duplicate-value regression in OE-18464.

## 2. Could a quick hash of the event solve this?

### The unchanged format and eligibility rules

| Rule | Required behaviour |
|---|---|
| Core alphabet | Exactly `ABCDEFGHIJKLMNOPQRSTUVWXYZ23456789`. Letters `I` and `O` are allowed; digits `0` and `1` are not. |
| Core length | Exactly 6 characters, including leading characters. |
| Maximum core namespace | `34^6 = 1,544,804,416` different strings. |
| Current operation-note eligibility | `OphTrOperationnote` with `Element_OphTrOperationnote_Cataract`, not every operation-note subtype. |
| Current CVI eligibility | `OphCoCvi` with `Element_OphCoCvi_EventInfo`. |
| Existing assignment | Keep it unchanged on subsequent saves and during migration. |
| Printed PUC | Preserve the institution prefix, separators and existing check-digit generation. |

The generator and eligibility list are the sources of these rules, not a new
alphabet restriction or blacklist. See [generator][generator] and
[controller eligibility][eligibility]. The printed form is
`institution_code + check_digit_1 + '-' + CORE + '-' + check_digit_2`.
The existing second check digit incorporates date of birth; the first includes
the institution code, and both use the existing configured salt. That wrapper
is distinct from the six-character core and must remain compatible with current
consumers. See [PUC formatting][puc-format].

A normal hash or HMAC shortened into this format is deterministic but is not
one-to-one. Two different event IDs can produce the same six characters, even
when the IDs themselves never repeat. A secret key conceals a hash mapping; it
does not remove collisions caused by compressing its result into this space.

For uniform independent outputs, the approximate probability of at least one
collision after `k` values is `1 - exp(-k * (k - 1) / (2 * 34^6))`.
At 100,000 issued codes this is about 96%. This is a mathematical sizing example,
not a count of duplicates in a deployment. Checking for duplicates and retrying
would work, but turns it into a stateful allocation scheme, not guaranteed
event-only encoding.

Hashing event contents adds another problem: edits can change the code, while
different events can have identical contents. Patient identifiers, date of birth,
clinical details and event timestamps should not be inputs to the core generator.

The viable deterministic alternative is a one-to-one encoding of the immutable
event ID, with a secret-key permutation if concealment is required. That is
option 3 below. It is not an ordinary truncated hash.

## 3. The three solution options

| Option | What chooses a code? | High-concurrency advantage | Main cost |
|---|---|---|---|
| 1. Keep the pool, reserve individual rows | An indexed free-code queue with transactional row claims | Different saves claim different free rows without a global allocation lock. | Supply management, queue consistency and transaction-isolation changes/retries. |
| 2. Generate randomly on demand | A secure random generator plus the unique code-value index | No pool search or common allocation lock; low occupancy means few collision retries. | Finite collision retries and continued dependence on database uniqueness checks. |
| 3. Encode the event ID deterministically | One fixed injective mapping, preferably keyed FF1 for concealment | Code calculation needs no free-code lookup, reservation or collision retry for distinct valid IDs. | Legacy-code migration, fixed configuration/key lifecycle, finite ID range and privacy review. |

All three still write event/mapping rows and obey foreign keys and unique
indexes. None makes the entire event save lock-free or immune to deadlocks.
The shared fixes in section 4 are required whichever option is selected.

### 3.1 Option 1: keep the pool, claim individual free rows

Plain English: put the spare codes in a queue. Each save takes one available
entry, and skips entries another save is already using. Keep the reservation
and the event in the same transaction so cancelling the save returns the entry.

Proposed implementation:

1. Introduce an explicit, indexed free-code queue or claim state. For example,
   a small queue keyed by `unique_code_id` contains only available active codes.
   Do not use the old snapshot-based anti-join as the reservation mechanism.
2. Lock the target event before claiming a code. A newly inserted event is
   already owned by its creating transaction. An existing event must be acquired
   in the agreed save/repair lock order and checked again for eligibility and
   an existing mapping.
3. Select one queue row using `FOR UPDATE SKIP LOCKED`. Remove that queue entry
   and insert its mapping in the same transaction as the event changes.
4. Commit both together. A rollback undoes the queue removal and mapping, making
   the code available again. No global `GET_LOCK` is involved.
5. Update every writer: generation, allocation, repair, deactivation and any
   administrative maintenance must preserve the queue/mapping invariant.

MariaDB supports skipping busy InnoDB rows through
[SKIP LOCKED](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/selecting-data/select#skip-locked).
An empty result means there is no claimable entry now: the queue may be empty,
or its entries may all be locked. Report these appropriately and schedule a
bounded retry; do not declare permanent exhaustion just because rows were skipped.

#### MariaDB 11.8 transaction design is part of this option

Simply adding `FOR UPDATE SKIP LOCKED` to the current query is not the proposed
fix. An old `REPEATABLE READ` snapshot with snapshot isolation enabled can still
conflict with rows changed after that snapshot.

The preferred version of this pool design uses deliberately scoped
`READ COMMITTED` transactions for the relevant event-save paths and short
backfill transactions. Set the isolation for the next outer transaction before
it begins; changing a setting inside the allocator cannot change the transaction
already surrounding the event save. Do not silently change the RDS-wide default.

This changes what repeated reads during a save may observe, so review validation,
version snapshots, audit and event hooks as part of the implementation. Keep
snapshot-isolation conflict handling. `MIXED` logging can support this choice;
do not assume a deployment forced to statement-only logging can do the same.
See [transaction isolation and logging requirements](https://mariadb.com/docs/server/reference/sql-statements/administrative-sql-statements/set-commands/set-transaction).

If retaining default `REPEATABLE READ` for the full save is a hard requirement,
this option needs complete-transaction retries that obtain fresh views, with
progress verified under load. A separately committed reservation service is a
larger alternative requiring leases, crash recovery and reconciliation. It must
not commit an event mapping independently and claim to preserve rollback safety.

#### Why this helps, and remaining limits

Different events normally hold different queue-row locks, so one slow claimant
does not own the gate for every allocator. Busy-entry skipping avoids waiting
behind the first row. A narrow indexed queue avoids repeatedly scanning the
historical pool/mapping join. Inspect the actual query plan and locked records;
`LIMIT 1` alone does not prove a query locks or examines only one row.

Keep backfill transactions to one event each. Acquire that event with `NOWAIT`
before touching a queue entry; defer a busy event without holding a code claim.
This removes the lock-order cycle in section 1.3. Parent/user rows can still cause
ordinary row-lock waits, and all spare codes can temporarily be reserved. These
conditions require bounded handling, not a promise that every first attempt wins.

Supply must cover eligible-event demand, concurrent reservations, repair backlog
and generator outages. Top up and monitor the free queue separately from backfill.
During rollout, migrate the queue consistently and prevent old allocation paths
from bypassing it. Do not delete or reassign existing issued codes.

### 3.2 Option 2: no pool, generate a random code when needed

Plain English: when an eligible event needs its first code, make six random
characters and save them. Let the database reject a code already in use, and
generate another if that rare collision occurs.

Proposed implementation:

1. Establish ownership of the event and recheck its existing mapping, using the
   same event-first policy for web saves and repair.
2. Generate each of the six characters uniformly with a cryptographically secure
   random source using the existing alphabet.
3. Insert a new `unique_codes` row with a normal INSERT. Require the unique index
   on `code`; do not use a prior availability SELECT as the guarantee.
4. Retry with another random code only when the error is specifically a duplicate
   code-value collision. Bound attempts and elapsed work. Do not hide unrelated
   errors with `INSERT IGNORE` or retry every database exception as a collision.
5. Insert the mapping and retain both inserts inside the event transaction. Keep
   existing audit-column values and clinical audit/version behaviour intact.
6. Retire pool generation for new issuance. Retain existing code rows and mappings
   so printed references keep resolving. Repair uses this same on-demand path.

If another process has already assigned the same event, return that assignment;
do not keep creating different codes. A mapping duplicate is not the same error
as a code-value collision. Resolve it using an appropriate fresh/current read
or a complete transaction retry, not the old snapshot-based recheck. If a new
code row was inserted before losing a mapping race, roll back that attempt so
it does not leave unlinked rows behind.

Why it helps: there is no available-code shortlist to become stale, no shared
allocation mutex, and no spare-pool exhaustion. Each save normally inserts its
own code and mapping. For `U` distinct retained code values, the approximate
per-attempt collision probability is `U / 1,544,804,416`. That is about 0.78% at
an illustrative 12 million retained values. Non-code-bearing events do not count
towards `U`; unassigned retained pool rows do.

The database remains the final uniqueness guarantee. Duplicate checks and
foreign keys still take locks, and simultaneous identical candidates can wait
for each other's transaction. Repeated failed INSERTs can retain some locks
until transaction end. Keep retry budgets small and use whole-save recovery for
transaction-aborting errors. As the namespace fills, retries become expensive;
monitor total retained code values, not just currently active mappings.

This option is the simplest migration from the existing random-code model. It
does not guarantee which code a previously unmapped event will receive, nor that
an attempt can never collide. It guarantees committed uniqueness through the
database constraint and correct transaction handling.

### 3.3 Option 3: no pool, deterministic event-ID encoding

Plain English: give every possible event ID its own place in a fixed table of
codes, but calculate that place instead of storing the whole table. A secret
shuffle conceals the event number. Two different IDs have different places,
regardless of which save happens first.

#### Basic construction, before accounting for existing codes

Let `N = 34^6`. For event IDs from `1` through `N`:

1. Set `n = event_id - 1`.
2. Represent `n` as exactly six base-34 digits using the fixed alphabet order.
   The zero digit is `A`, so leading padding is `A`, not `0`.
3. Apply a vetted FF1 format-preserving encryption implementation with radix 34,
   length 6, one stable secret key and one fixed tweak for the shared namespace.
4. Persist the resulting code and mapping in the event transaction. An existing
   stored mapping always wins and must never be silently regenerated.

FF1 is a reversible permutation: with fixed parameters it rearranges possible
strings without merging any two. Therefore distinct in-range IDs have distinct
outputs. Encoding and permutation together are injective. A truncated hash is
not. NIST specifies FF1 in
[SP 800-38G](https://nvlpubs.nist.gov/nistpubs/specialpublications/nist.sp.800-38g.pdf).

Use maintained, reviewed cryptographic code, not a home-made shuffle, affine
formula or truncated AES output. Check radix support, fixed-width encoding,
integer arithmetic and official vectors. The current
[NIST revision page](https://csrc.nist.gov/pubs/sp/800/38/g/r1/2pd) remains labelled
second public draft: it retains FF1, removes FF3 and strengthens implementation
requirements. This note does not treat that draft as a newly final standard or
claim a particular application library has been selected and validated.

The calculation is fixed-size local work with no availability query. FF1 is
more work than a simple base conversion, so measure the chosen library, but its
work does not increase with the number of saved events. Database writes remain.

#### Not every event is an operation note, and CVI needs a code too

The event table is one ID namespace shared by the event types. Use that global
`event.id`, not an operation-note element ID, a CVI element ID, or a separate
counter for each type.

| Illustrative event | Encoding behaviour |
|---|---|
| ID 101, examination | No code is issued because it is ineligible. Its ID still occupies a position in the encoding domain. |
| ID 102, cataract operation note | Issue the encoding of ID 102. |
| ID 103, correspondence | No code is issued. |
| ID 104, CVI with its event-info element | Issue the encoding of ID 104 through the same function as the operation note. |
| An older eligible event repaired later | Calculate from its original ID; allocation order does not matter. |

It is fine that many positions never become issued codes. Nothing needs to
generate or insert those unused positions. However, capacity forecasting for
this raw-ID design must use growth of the whole event counter, not only the
number of operation notes/CVIs. By contrast, pool supply and random-code
occupancy depend on actual code demand.

Do not use different keys or tweaks per event type in the same code namespace:
two independently shuffled code spaces can overlap. Similarly, a future use of
`allocateForUser()` cannot simply encode `user.id` through this event function.
Event ID 102 and user ID 102 would collide. Additional entity types need a proven
disjoint input/output allocation or a shared globally unique identifier domain.

Eligibility can arise later when an element is added. An older ID must still
work then. Do not select an algorithm by wall-clock allocation date or rely on
events arriving in a particular order.

#### Event IDs need uniqueness, not gapless or commit-order numbering

| Situation | What can happen | Effect on encoding |
|---|---|---|
| Concurrent inserts | One transaction gets ID 101 first, but ID 102 commits first. | Safe. Different inputs remain different outputs. |
| Rollback or failed insert | An allocated number can be skipped permanently. | Safe, but the counter can advance faster than successful event counts. |
| Bulk allocation | Reservations can leave gaps; allocation details depend on the INSERT and lock mode. | Safe within range; count counter growth, not only rows. |
| Soft deletion | The event remains in the database but is hidden by normal application rules. | Keep its identity and code reserved; do not recycle it. |
| Explicit import IDs | An unused lower ID can be inserted, or a much higher ID can advance the counter. | Order is irrelevant; uniqueness and range still need enforcement. |
| Different increment/offset settings | A sequence may advance by more than one. | Safe if IDs remain unique; consumes range faster. |
| Backdated clinical dates or imported creation dates | Displayed dates need not follow ID order. | Dates are not inputs to the core code. |
| Restore, clone, manual reseed or destructive rebuild | An ID previously issued externally can be reused in a new history. | Unsafe if it represents a different event: the same deterministic code would be issued again. |

MariaDB documents explicit IDs, gaps and increment/offset controls in
[AUTO_INCREMENT](https://mariadb.com/docs/server/reference/data-types/auto_increment).
Its [InnoDB allocation details](https://mariadb.com/docs/server/server-usage/storage-engines/innodb/auto_increment-handling-in-innodb)
also distinguish persistence from transactional behaviour. Out-of-order commits
are a consequence of allocating IDs before transactions complete, not a claim
that ordinary inserts arbitrarily count backwards.

A routine MariaDB 11.8 restart is not, by itself, an instruction to reuse IDs.
The dangerous cases change the database's history or identity. A restore or
replacement system must preserve the issuance history and prevent reuse of IDs
already exposed externally. A clone must not issue into the same external
namespace independently. Different deployment keys alone do not prove globally
disjoint six-character codes; define the actual routing/uniqueness boundary.

#### Capacity at the scale discussed

The reported scale is comfortably within the raw six-character domain. The
following deliberately illustrative figures avoid storing a deployment's
operational export in this repository.

| Assumption | Raw-ID headroom before legacy-code exclusions |
|---|---|
| Highest ID 12 million | About 1.533 billion further ID positions. |
| Counter grows by 7,000 per day from that point | About 600 years at a constant rate. |
| Counter grows by 10,000 per day from that point | About 420 years at a constant rate. |
| Ten times the 7,000-per-day rate | About 60 years at a constant rate. |

These are arithmetic horizons, not lifetime guarantees. A week's event counts
are not a growth forecast; the current day may also be incomplete. Monitor the
next auto-increment value/high-water mark and its rate of increase, including
gaps and imports. `MAX(id)` and `COUNT(*)` do not fully measure reserved or burned
ID positions. Legacy exclusions below reduce the domain further.

Validate the ID range before encoding. Never silently truncate, wrap
`event_id % N`, or reset the event counter. Those operations would make distinct
events share a code. A separate dense counter for code-bearing events would
use capacity more efficiently, but reintroduces allocation state and is no
longer a pure function of `event.id`.

#### Existing random codes are the important migration obstacle

The one-to-one proof applies among outputs of the new function. It does not
prove those outputs differ from all old random codes. A future deterministic
output may already be printed for a different event, or present in the spare
pool. A unique index would reject it, but a retry-free deterministic allocator
would then have no valid alternative under its original rule.

Keeping old mappings and using plain FF1 only for newer IDs is therefore not
enough. Nor does trying legacy lookup before deterministic decoding resolve
ambiguity if both represent different events. Never reassign an issued code or
silently fall back to a new random code while claiming the same deterministic
guarantee.

One workable design is an immutable exclusion map prepared at a coordinated
cutover. This is a proposed composition requiring implementation review, not a
ready-made capability of FF1:

1. Stop all legacy issuance paths during cutover. Inventory distinct existing
   code strings that must remain reserved, including assigned, printed and
   retained unused codes. Conservatively reserve all retained pool rows. Resolve
   any pre-existing ambiguities separately; do not delete clinical references.
2. Fix the new key, tweak, alphabet and algorithm version. Let `P` be that FF1
   permutation over integers `0` through `N - 1` and their six-character outputs.
3. For every reserved old code, use `P`'s inverse to find its input position.
   Store those positions as a fixed sorted excluded set `B`.
4. For `n = event_id - 1`, choose the zero-based `n`th input position not in `B`.
   Call it `q`, and return `P(q)`. Validate `0 <= n < N - count(B)`.
5. Distribute exactly the same immutable exclusion artifact and version to
   every issuer. It can be loaded locally and searched by rank; no shared
   mutable reservation or per-event availability query is needed.

Why it is unique: different `n` values select different permitted positions;
`P` maps different positions to different codes; excluded positions are exactly
those that would produce reserved old codes. Thus new codes neither collide
with one another nor with the reserved legacy set. This works for old unmapped
eligible events too, not only events created after cutover.

Do not implement this as "start at the event's position and keep skipping until
something is free". Different starting IDs could converge on the same result.
The rank selection above must be one-to-one, use integer arithmetic and have
explicit boundary tests.

This design is deterministic from the event ID plus fixed configuration. It is
not configuration-free: the key and exclusion artifact become permanent system
dependencies. Changing the exclusion set later shifts positions and can change
codes. New legacy-code imports, rollback to an old issuer and key rotation need
a controlled new migration/version with existing assignments preserved, not a
silent configuration edit. Stored mappings remain authoritative across versions.

If that fixed migration artifact is undesirable, an exception registry or a
collision-checked random fallback is possible, but gives up the pure fixed
event-ID-to-code calculation. Simply reserving a prefix is not automatically
safe either: old codes may already use it, and reserving one leading character
reduces the available combinations to `34^5 = 45,435,424` for that prefix.

#### What determinism does, and does not, give away

Determinism itself does not mean patient details must be exposed. The proposed
input is an internal record number, not the patient's name, identifier, birth
date or clinical content. Nevertheless, how that number is encoded matters.

| Construction | What someone can learn or do |
|---|---|
| Plain base-34 event ID | Decode the number, see rough sequencing/volume and calculate neighbouring candidates. Gaps and commit order make the inference imperfect, not private. |
| Public arithmetic scrambling | Obscures appearance but can remain reversible or inferable; it is not a confidentiality guarantee. |
| Reviewed keyed FF1 with protected fixed configuration | Conceals the straightforward ID/sequence relationship from someone without the key. Adjacent IDs should not produce visibly adjacent codes. |
| Any deterministic code | Repeated sightings can be linked as the same reference; known event/code pairs and an accessible lookup service can reveal information. |
| Any six-character code | Has only about 30.5 bits of possible values. It must not be treated as an authentication secret. |

The reasonable claim is "the core does not directly encode readable clinical
information or expose the event counter without the key", not "nothing can ever
be learned". This is a design inference under the cryptographic assumptions,
not a completed security assessment. Small-domain query/codebook attacks,
key compromise, rate limits and the surrounding workflow remain relevant.
NIST explicitly discusses domain-size security concerns in its
[FF1 revision guidance](https://csrc.nist.gov/pubs/sp/800/38/g/r1/2pd).

The full printed PUC already identifies the institution and contains a
patient-dependent check digit. Retaining those rules means the complete printed
string cannot be described as carrying no contextual information. The code
itself is still a link to a clinical record once a permitted lookup resolves it.

Keep the key in the deployment's secret store, with controlled access and tested
recovery. Keep the deployment-derived exclusion artifact outside this repository
too. Do not derive the key from public configuration, place it in source control,
log it, or silently generate a replacement when it is missing. Protect existing
mappings and configuration through backup/restore. A compromised key cannot be
fixed by simply changing a setting while promising unchanged derivations.

Keep persisted lookup and access checks. Do not replace the existing resolver
with "decrypt any supplied code and return that event". A mathematically valid
code can correspond to an event that never received one or is not eligible.
Require a committed assignment and preserve the caller's authentication,
authorisation, deletion handling, auditing and appropriate rate limits. See
[the existing mapping-based resolver][resolver].

#### High-concurrency behaviour

Two saves for different valid event IDs calculate different codes independently.
There is no shared free-code search, claim row or allocation mutex, and no
code-collision retry is needed if the migration and namespace invariants hold.
Two attempts for the same event calculate the same code; event ownership and
unique mapping constraints must still make persistence idempotent.

Normal locks still exist for event ID allocation, inserts, foreign keys and
unique indexes. A conflict on the same event, a busy referenced user, or a
versioned save elsewhere can still wait or abort. This option removes code
selection as a contention source; it does not promise a lock-free database save.
Do not publish the code externally before the event transaction commits.

## 4. Fixes required with every option

1. Share one eligibility definition between save and repair, including cataract
   operation notes and CVI. Honour element presence and deletion rules. A
   targeted CVI repair must be a supported operation.
2. Preserve one committed mapping per event and one owner per code, plus the
   unique constraint on the code string. Preserve existing assignments,
   foreign keys, audit columns, clinical audit and version snapshots. Recheck
   actual deployed constraints before changing issuance.
3. Keep event changes, new code rows where applicable, and mapping creation in
   the same transaction. A validation failure or rollback must not leave a
   committed assignment or a code published to an external consumer.
4. Give repair one short transaction per event. Acquire the event first without
   waiting, recheck eligibility/mapping, then allocate. Defer busy events and
   revisit them without starving later work. Avoid a long batch transaction or
   a broad `INSERT ... SELECT` repair that couples many event rows.
5. Handle transaction-ending errors at the outer save boundary. For 1213 and
   MariaDB 11.8's 1020, use a fresh transaction and freshly loaded application
   state. Replay validation and required database writes safely. Bound retries;
   release transaction locks before backoff. Do not retry only the allocator.
6. Before adding whole-save retries, identify side effects in event hooks,
   attachments, notifications and integrations. Make them idempotent or defer
   irreversible work until commit. Do not create duplicate clinical events or
   external actions when replaying a save. An uncertain COMMIT outcome needs
   idempotent reconciliation, not a blind repeat insert.
7. Decide explicitly what a code-allocation failure means. To retain the PR's
   save-without-code policy, persist a repair obligation in the same successful
   transaction, or provide a reliable scheduled sweep with backlog monitoring.
   If a workflow requires a code immediately, return a clear retryable save
   failure instead. A rolled-back database transaction cannot be reported as a
   successfully saved code-less event.
8. Make repair outcomes machine-readable: incomplete work must not masquerade
   as exit status 0. Emit committed-repair messages after commit, discard them
   on rollback and avoid promising repair before a service exists to perform it.
9. Apply retry and query budgets with observability: allocation latency, failure
   reason, whole-save retries, missing-code backlog and its oldest age. For a
   pool monitor free supply; for random generation monitor namespace occupancy;
   for deterministic generation monitor ID range and configuration consistency.
10. Roll out all issuance paths coherently. Preserve old code lookup and printed
    formatting. Do not allow mixed old/new writers to bypass a queue invariant
    or the deterministic exclusion boundary. Changes to RDS parameters remain
    an explicit operator decision, not an implicit requirement of this note.

These measures target the specific problems above. They do not substitute for
separately addressing version-snapshot lock ordering or other long transactions.
In particular, never remove audit/version writes to make a lock graph simpler.

## 5. Required acceptance checks before implementation is considered complete

| Scenario | Required result |
|---|---|
| Concurrent cataract and CVI creation with adequate capacity | Every successful save follows the chosen immediate-code/repair policy; no duplicate assignment. |
| An old read view after many other allocations | No endless reuse of a stale shortlist; fresh-view recovery is bounded and preserves the whole save. |
| Web edit and backfill target the same unmapped event | Busy repair defers; no shared allocation gate is held while waiting for that event. |
| A referenced user/event is held by another transaction | Unrelated allocations are not all queued behind one allocation mutex. |
| Validation failure or forced rollback after allocation | No committed event/mapping mismatch, leaked claim or premature external publication. |
| Error 1213 or 1020 during the full save | Correct whole-transaction recovery, or clear failure; no duplicate side effects. |
| Targeted and batch CVI repair | Correct eligibility, one stable assignment, truthful exit status and backlog reporting. |
| Pool empty or all queue entries busy | Bounded, correctly classified result; rollback restores any queue claim. |
| Forced random candidate collisions | Code-value collisions alone retry; mapping races are handled separately. |
| Deterministic IDs at both boundaries, with gaps and reversed commit order | Same ID/configuration gives the same code; distinct supported IDs give distinct valid codes. |
| Deterministic legacy exclusion, including old unmapped eligible events | No overlap with retained codes; rank selection is injective and range checked. |
| Existing assigned events edited after migration | Original code and printed-format rules remain unchanged. |
| Key/artifact mismatch, restart, restore and issuer rollback | Fail safely without silently changing codes or reusing an externally issued identity. |
| Lookup of an unissued but mathematically valid deterministic code | No bypass of mapping existence, eligibility or access controls. |

Use the actual MariaDB 11.8 minor version, effective RDS/session settings and
production-shaped schema for release verification. Include multiple connections,
the full event-save transaction, both eligible workflows, real repair scheduling
and audit/version effects. Single-connection allocator tests are not enough.

The present note verifies source behaviour and design arithmetic. It does not
claim these proposed replacements have been implemented, load-certified on RDS,
or security-reviewed. For minimum migration complexity, option 2 is the starting
recommendation. If predicting the code from the event ID is an explicit product
requirement, option 3 is viable at the discussed scale, subject to its legacy
migration, key management and identity-lifecycle requirements.

## Source anchors for the reviewed release

All application links below are pinned to the merged revision, not a moving
branch. The defaults and cryptographic references are linked at the relevant
claims above.

[allocator]: https://github.com/OpenEyes/openeyes/blob/29e98ef506159bc730fd5037cc5d0c13f341a858/protected/components/UniqueCodeAllocator.php#L32
[eligibility]: https://github.com/OpenEyes/openeyes/blob/29e98ef506159bc730fd5037cc5d0c13f341a858/protected/controllers/BaseEventTypeController.php#L79
[warnings]: https://github.com/OpenEyes/openeyes/blob/29e98ef506159bc730fd5037cc5d0c13f341a858/protected/controllers/BaseEventTypeController.php#L2935
[create-save]: https://github.com/OpenEyes/openeyes/blob/29e98ef506159bc730fd5037cc5d0c13f341a858/protected/controllers/BaseEventTypeController.php#L1020
[update-save]: https://github.com/OpenEyes/openeyes/blob/29e98ef506159bc730fd5037cc5d0c13f341a858/protected/controllers/BaseEventTypeController.php#L1299
[backfill]: https://github.com/OpenEyes/openeyes/blob/29e98ef506159bc730fd5037cc5d0c13f341a858/protected/commands/BackfillMissingPucCodesCommand.php#L37
[generator]: https://github.com/OpenEyes/openeyes/blob/29e98ef506159bc730fd5037cc5d0c13f341a858/protected/commands/GenerateUniqueCodeCommand.php#L27
[puc-format]: https://github.com/OpenEyes/openeyes/blob/29e98ef506159bc730fd5037cc5d0c13f341a858/protected/modules/OphTrOperationnote/components/OphTrOperationnote_API.php#L139
[resolver]: https://github.com/OpenEyes/openeyes/blob/29e98ef506159bc730fd5037cc5d0c13f341a858/protected/models/UniqueCodes.php#L123
[code-index]: https://github.com/OpenEyes/openeyes/blob/29e98ef506159bc730fd5037cc5d0c13f341a858/protected/migrations/m260820_095341_index_unique_codes.php#L7
[allocator-tests]: https://github.com/OpenEyes/openeyes/blob/29e98ef506159bc730fd5037cc5d0c13f341a858/protected/tests/unit/components/UniqueCodeAllocatorTest.php#L29
