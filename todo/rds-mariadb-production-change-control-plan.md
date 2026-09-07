# RDS MariaDB production infrastructure change-control plan

## Purpose and scope

This plan covers infrastructure and managed-service changes for the target
production RDS deployment. It is based on read-only AWS inspection performed on
2026-09-01, August 2026 CloudWatch metrics, the available Database Insights
history, and public AWS list prices effective on 2026-08-01.

OpenEyes v26 and MariaDB 11.8 are imminent. Query, index, execution-plan,
transaction-scope, and application connection-pool work are deliberately out of
scope. The new application and engine should settle before infrastructure
results are compared.

No AWS change was made. Customer name, account ID, resource names, endpoints,
network details, tags, and SQL text are omitted because this is a public
repository.

## Executive decision

The evidence does not justify a larger instance, more gp3 IOPS, io2, or a
Dedicated Log Volume. The practical infrastructure sequence is:

1. Keep Database Insights Standard and verify that AWS-managed Performance
   Schema is active after the MariaDB 11.8 change.
2. Buy longer Standard retention, not Advanced, if history is the only need.
   Use Advanced only if its operational analysis features will be used.
3. Complete the planned OpenEyes v26 and MariaDB 11.8 deployment before judging
   infrastructure performance.
4. Trial `db.r8g.4xlarge` in production after the upgrade has a stable baseline.
   It keeps 128 GiB of memory, halves vCPU, and saves about $639.48 per month.
5. Verify Optimized Writes from MariaDB. `AUTO` is configured, but it does not
   prove that the feature is active.
6. Consider Optimized Reads only if post-upgrade measurements show material
   disk temporary work. An 80 percent read workload alone is not evidence for
   it.
7. Reduce paid gp3 throughput in stages after the upgrade. Do not reduce IOPS
   until the isolated IOPS spike is explained.
8. Treat Multi-AZ as a resilience decision. It adds about $2,824.60 per month
   on the current class and storage. ENA Express is a free improvement to the
   replication path once Multi-AZ exists.
9. Do not implement transparent read routing in this change. RDS Proxy cannot
   split reads across this RDS DB instance and its ordinary read replica.

## Live baseline

| Component | Current setting | Infrastructure implication |
|---|---:|---|
| Primary compute | `db.m8g.8xlarge`, 32 vCPU, 128 GiB | Graviton4 general-purpose class |
| Engine | MariaDB 10.6.25 | Planned move to MariaDB 11.8 with OpenEyes v26 |
| Availability | Single-AZ | No native automatic cross-AZ failover |
| Primary storage | 1,000 GiB gp3, 24,000 IOPS, 2,000 MiB/s | Paying above the 12,000 IOPS and 500 MiB/s gp3 baseline |
| Storage autoscaling | Maximum 10,000 GiB | Already enabled |
| Read replica | `db.m8g.large`, 1,000 GiB gp3, 12,000 IOPS, 500 MiB/s | Existing asynchronous copy, not a production-sized standby |
| Database Insights | Standard, seven-day retention | Enabled at no additional charge |
| `performance_schema` parameter | Value `0`, source `system` | AWS says this is automatic management, not a manual disable |
| Enhanced Monitoring | Primary at 60 seconds | Useful OS evidence; replica does not currently have it enabled |
| `rds.optimized_writes` | `AUTO`, source `system` | Allows the feature when engine, class, and storage layout support it |
| Buffer pool | 75 percent of memory | About 96 GiB; preserve memory in the first class trial |
| Backup retention | Seven days | Point-in-time recovery is enabled |
| Reserved DB instances | None active | Do not reserve until class and AZ design are settled |

## Workload evidence relevant to infrastructure

The workload is approximately 80 percent reads and 20 percent writes. About 80
percent of the writes, or roughly 16 percent of all operations, are concentrated
on a small number of tables.

| Signal | August 2026 observation | Infrastructure implication |
|---|---:|---|
| CPU | 6.5% average, 14.9% p95, 22.4% maximum | No case for more vCPU; a 16-vCPU trial has credible headroom |
| Freeable memory | 19.0 GiB p5, 18.8 GiB minimum | Preserve about 128 GiB in the first trial |
| Swap | Approximately 0.5 MiB | No memory-pressure signal |
| Connections | 47 average, 72 p95, 633 maximum | Monitor connection recovery around infrastructure changes |
| Read IOPS | 5.8 average, 2.8 p95, 23,884 maximum | One isolated event nearly reached 24,000 IOPS |
| Write IOPS | 79 average, 333 p95, 2,256 maximum | Sustained demand is below the included gp3 baseline |
| Read throughput | 0.025 MiB/s p95, 373 MiB/s maximum | Observed maximum was below the 500 MiB/s included baseline |
| Write throughput | 3.1 MiB/s p95, 36.4 MiB/s maximum | Far below the included baseline |
| Read latency | 0.36 ms average, 1.51 ms p95 | No persistent-storage latency case for io2 |
| Write latency | 0.82 ms average, 1.05 ms p95 | No persistent-storage latency case for io2 or DLV |
| Disk queue depth | 0.08 average, 0.31 p95, 18.85 maximum | Maximum coincided with the isolated read event |
| Free storage | 241.6 GiB minimum | Keep 1,000 GiB because RDS cannot shrink storage in place |
| Replica lag | 0.055 seconds average, 834 seconds maximum | Promotion could lose recent data and needs an explicit RPO |

Database Insights showed about 2.17 average active sessions across 32 vCPUs.
The dominant observed wait was logical table-handler I/O rather than InnoDB
data-file I/O. That supports the conclusion that more persistent-storage
performance is not currently justified. No query change is proposed here.

## Current monthly cost estimate

### Assumptions

- Currency is USD before VAT.
- Region is EU (London).
- A budgeting month is 730 hours.
- Prices are public on-demand list prices effective on 2026-08-01.
- The account has no active RDS Reserved Instances.
- Private discounts, credits, support, data transfer, CloudWatch logs, backup
  storage above the free allocation, manual snapshots, and the separate S3
  backup set are excluded.
- At 1,000 GiB, MariaDB gp3 includes 12,000 IOPS and 500 MiB/s. Only provisioned
  performance above those values is charged.

| Component | Calculation | Approximate monthly cost |
|---|---:|---:|
| Primary compute | $3.120/hour x 730 | $2,277.60 |
| Primary gp3 capacity | 1,000 GiB x $0.133 | $133.00 |
| Primary extra IOPS | 12,000 x $0.023 | $276.00 |
| Primary extra throughput | 1,500 MiB/s x $0.093 | $139.50 |
| Primary subtotal |  | $2,826.10 |
| Replica compute | $0.195/hour x 730 | $142.35 |
| Replica gp3 capacity | 1,000 GiB x $0.133 | $133.00 |
| Replica extra IOPS and throughput | Included baseline | $0.00 |
| Replica subtotal |  | $275.35 |
| Current deployment estimate | Primary plus replica | **$3,101.45** |

Cost Explorer cannot isolate the exact billed amount because resource-level
granularity is not enabled and the project tag includes other database
instances. This list-price estimate is the reproducible change-control
baseline. Finance should replace it with invoice or CUR allocation if exact
billed cost is required.

## Consolidated infrastructure comparison

Monthly totals include the unchanged replica unless stated otherwise. Negative
deltas are savings.

| Change | New monthly estimate | Delta from $3,101.45 | Main risk or gain | Decision |
|---|---:|---:|---|---|
| Keep Standard Insights at seven days | $3,101.45 | $0.00 | Free DB load, wait, dimension, graph, and alarm evidence | Keep |
| Standard Insights with one-month retention | $3,157.63 | +$56.18 | Longer evidence only | Prefer if history is the requirement |
| Standard Insights with three-month retention | $3,162.35 | +$60.90 | Longer evidence only | Good value around the upgrade |
| Standard Insights with twelve-month retention | $3,183.58 | +$82.13 | Long comparison window | Consider for annual evidence |
| Advanced Insights on primary | $3,393.45 | +$292.00 | OS processes, per-query statistics, slow SQL integration, fleet views, events, and on-demand analysis | Trial only if these will be used |
| Verify AWS-managed Performance Schema | $3,101.45 | $0.00 | Read-only verification | Do after the 11.8 reboot |
| Reset Performance Schema to system default if modified | $3,101.45 | $0.00 | Reboot and small instrumentation overhead | Only if runtime verification fails |
| MariaDB 11.8 through Blue/Green | $3,101.45 steady state | +$4.2486/hour while copied topology exists | High compatibility risk; supports the planned application version | Planned |
| Trial `db.r8g.4xlarge` | $2,461.97 | -$639.48 | Same memory, half vCPU; capacity and restart risk | Recommended measured trial |
| Use `db.r8g.8xlarge` | $4,100.09 | +$998.64 | Same vCPU, double memory with no current need | Not justified |
| Use `db.m8gd.8xlarge` Optimized Reads | $3,632.16 | +$530.71 | Local NVMe for temporary work; local-storage exhaustion risk | Conditional |
| Use `db.r8gd.4xlarge` Optimized Reads | $2,694.40 | -$407.05 | Same RAM class, half vCPU, about 950 GB local NVMe | Conditional higher-risk trial |
| Reduce gp3 throughput to 1,000 MiB/s | $3,008.45 | -$93.00 | Retains substantial observed headroom | Staged cost reduction |
| Reduce gp3 throughput to 500 MiB/s | $2,961.95 | -$139.50 | Observed maximum used about 75 percent of limit | Second stage only |
| Reduce gp3 IOPS to 12,000 | $2,825.45 | -$276.00 | Isolated event would have exceeded the limit | Do not approve yet |
| Multi-AZ on current primary | $5,926.05 | +$2,824.60 | Automatic cross-AZ failover and synchronous standby | Business resilience decision |
| Multi-AZ plus `db.r8g.4xlarge` primary | $4,647.09 | +$1,545.64 | Lower-cost HA if the class trial passes | Do not combine the first changes |
| ENA Express on eligible Multi-AZ class | Same as chosen Multi-AZ total | $0.00 feature charge | Better replication bandwidth and latency consistency | Use with Multi-AZ |
| Replace current replica with one in another AZ | $3,101.45 steady state | About +$0.3772/hour during overlap | Manual asynchronous recovery copy, possible lag and reduced capacity | Low-cost resilience improvement |

## 1. Performance Schema and Database Insights

### Exact Performance Schema action

The live parameter group reports `performance_schema=0` with source `system`.
AWS documents that exact combination as automatic Performance Insights or
Database Insights management. It must not be changed to a manually modified
value of `1` merely because the console displays `0`.

Use this sequence:

1. After the MariaDB 11.8 reboot, run `SHOW GLOBAL VARIABLES LIKE 'performance_schema';` through the normal DBA route.
2. If the result is `ON`, make no parameter change.
3. If the result is `OFF`, open the attached parameter group, select
   `performance_schema`, choose `Set to default value`, save, and reboot.
4. Verify that the parameter source is `system` or `System default`, the stored
   value is `0`, and the runtime SQL value is `ON`.
5. Do not manually change `setup_consumers`, `setup_instruments`, sizing
   parameters, or history-table sizes for ordinary Database Insights use. AWS
   automatic management selects and sizes the instrumentation. A manual
   instrument change needs a separate diagnostic reason and bounded test.

Cost is $0. Runtime verification is read-only. The fallback reset is a static
parameter change and requires a reboot, so it carries low instrumentation risk
and medium operational risk from the interruption. The MariaDB 11.8 reboot is
the natural point to activate and verify it without adding another outage.

With AWS-managed Performance Schema active, the main free gains are detailed
wait events, per-SQL and per-user or host DB load dimensions, and one-second
active-session sampling. Without it, the view falls back to less useful generic
states and five-second sampling.

### What Standard provides for free

| Standard feature | Operational use |
|---|---|
| Seven days of detailed database and per-query metrics | Compare current incidents and recent changes |
| DB load by top contributor and dimension | Locate the database, host, user, wait, or SQL family driving load |
| Metric graphing and alarms | Put thresholds around DB load and database metrics |
| Fine-grained access control | Restrict sensitive dimensions such as SQL text |
| First 1 million Performance Insights API calls per month | Automated evidence collection without an API charge at normal use |

### What the $292 Advanced charge buys

Advanced costs $0.0125 per vCPU-hour. The 32-vCPU primary costs about $292 per
730-hour month. If the class changes to the 16-vCPU `db.r8g.4xlarge`, the same
feature would cost about $146 per month.

| Advanced-only feature relevant to MariaDB | Main gain |
|---|---|
| Detailed OS process analysis with Enhanced Monitoring | Correlates DB load with engine and operating-system process activity |
| Saved fleet-wide views | Reusable health views across the RDS estate |
| Per-query statistics | Adds distribution and execution evidence beyond top-contributor load |
| Slow SQL analysis when database logs are exported | Brings slow-log evidence into the same console; log ingestion is billed separately |
| Application Signals integration | Shows which instrumented EKS services call the database |
| Consolidated metrics, logs, events, and application view | Shortens incident correlation across separate consoles |
| RDS events in CloudWatch | Puts service events beside performance evidence |
| On-demand analysis for a chosen period | Produces a bounded analysis around an incident or change window |
| One to twenty-four months retention included | Keeps long history without a separate Standard retention charge |

Advanced does not provide guided execution-plan analysis or guided SQL-lock
analysis for MariaDB. Those advertised features apply only to specified other
engines. It also does not directly accelerate the database.

If retention alone is needed, Standard is much cheaper: about $56.18 for one
month, $60.90 for three months, or $82.13 for twelve months on this primary. A
one-month Advanced trial is justified around the v26 and MariaDB 11.8 change
only if the team will use OS process correlation, per-query statistics,
Application Signals, consolidated telemetry, or on-demand analysis. Otherwise
keep Standard.

## 2. OpenEyes v26 and MariaDB 11.8

The engine change is already planned and should precede infrastructure trials.
Use RDS Blue/Green so the replacement topology can be validated before
switchover. With unchanged class and storage, steady-state infrastructure cost
is unchanged. The copied topology is about $4.25 per hour, $101.97 for one day,
or $305.90 for three days, excluding additional snapshots, logs, backup storage,
and data transfer.

This is a high application-compatibility change. Validate application journeys,
schema migration, authentication, drivers, collations, background work,
replication, backup, restore, and EKS connection recovery. Do not use the same
switchover to resize the class, reduce storage performance, or introduce
Multi-AZ, because attribution and rollback would be unclear.

## 3. Optimized Writes and Optimized Reads

### Optimized Writes

RDS Optimized Writes uses Nitro hardware to make a durable 16 KiB page write
atomic. MariaDB can then write the page once instead of also maintaining the
InnoDB doublewrite buffer. ACID protection remains. AWS quotes up to twice the
write transaction throughput for suitable write-heavy workloads.

Check it with `SHOW GLOBAL VARIABLES LIKE 'innodb_doublewrite';`. `OFF`,
`FALSE`, or `0` means Optimized Writes is active. `ON` or `1` means the normal
doublewrite buffer is active.

The live parameter is correctly set to `rds.optimized_writes=AUTO`, but that is
only permission to use the feature. The current AWS MariaDB documentation does
not list M8g or R8g among its supported Optimized Writes classes, so runtime SQL
must be treated as authoritative. If it is inactive, MariaDB 11.8 by itself
does not prove that it will become active.

There is no feature charge. Moving back to an older supported class only to gain
Optimized Writes is not justified by this workload. Writes are about 20 percent
of operations, and the hot-table writes are about 16 percent of all operations.
Even if every write took half as long and operation share equalled time share,
the simple whole-workload ceiling would be about 11 percent faster. Actual gain
could be lower, especially where hot-table serialization rather than page flush
cost is the limit. Reassess if AWS adds M8g or R8g support.

If a future supported class still reports `innodb_doublewrite=1`, use a
Blue/Green deployment with `Enable Optimized Writes` and `Upgrade storage file
system configuration`. Do not weaken `sync_binlog` or InnoDB durability.

### Optimized Reads

RDS Optimized Reads places temporary files, on-disk temporary tables, memory
maps, and binary-log cache files on local NVMe instance storage. It does not
accelerate every read, the buffer pool, or ordinary persistent data-file reads.
The current non-`d` M8g class does not have it.

Before considering it, capture rates across comparable post-upgrade periods
with `SHOW GLOBAL STATUS WHERE Variable_name IN ('Created_tmp_tables','Created_tmp_disk_tables');`. A high and sustained increase in disk temporary tables is the relevant signal. The 80/20 read/write ratio alone is not.

Changing to `db.m8gd.8xlarge` enables the feature automatically and adds about
$530.71 per month. `db.r8gd.4xlarge` would save about $407.05 per month versus
today, but also halves vCPU and has about 950 GB of local NVMe. These are
separate production trials, not assumptions that the AWS `up to 2x` claim will
apply.

Monitor `FreeLocalStorage`, local-storage IOPS, latency, and throughput. Local
temporary objects are not included in snapshots. Transactions can fail if
local storage fills because binary-log cache files also use it. This gives the
change medium capacity risk and high failure-impact risk unless storage alarms,
transaction bounds, and retry behavior are proven.

## 4. M8g versus R8g and a production proof

Both are Graviton4 RDS families. Their main difference is memory density, not a
newer CPU generation.

| Candidate | vCPU | Memory | Maximum EBS bandwidth | Maximum network bandwidth | Deployment cost | Difference from current |
|---|---:|---:|---:|---:|---:|---:|
| `db.m8g.8xlarge` current | 32 | 128 GiB | 10,000 Mbps | 15 Gbps | $3,101.45 | $0.00 |
| `db.r8g.4xlarge` | 16 | 128 GiB | Up to 10,000 Mbps | Up to 15 Gbps | $2,461.97 | -$639.48 |
| `db.r8g.8xlarge` | 32 | 256 GiB | 10,000 Mbps | 15 Gbps | $4,100.09 | +$998.64 |

`db.r8g.4xlarge` is attractive because it preserves the observed memory shape
and removes unused CPU. It is not a promise of only a 10 percent difference:
the instance has half the vCPU, so a highly concurrent CPU burst can differ by
much more even though current CPU is low.

R8g is not inherently a faster generation than M8g. Both use Graviton4. The
AWS claim of up to 40 percent better performance and 29 percent better
price-performance compares Graviton4 R8g with the previous Graviton3 R7g, not
R8g with M8g. The equal-memory `r8g.4xlarge` trial is primarily a memory-density
and cost decision.

A production trial without synthetic load testing is reasonable after v26 and
MariaDB 11.8 are stable:

1. Record two to four comparable weeks of application p95 and p99 latency,
   error rate, throughput, DB load, CPU, free memory, connections, EBS metrics,
   replica lag, EKS pod count, and scheduled-work windows.
2. Take the normal pre-change restore point and modify only the primary class to
   `db.r8g.4xlarge` in a low-use window. The RDS endpoint remains the same, but
   the reboot interrupts connections.
3. Confirm that EKS clients reconnect, then keep the trial for at least one
   complete business, reporting, and batch cycle.
4. Compare the same days and workloads. Use deployment markers and exclude the
   immediate cold-cache period.
5. Roll back to `db.m8g.8xlarge` if CPU exceeds the agreed sustained threshold,
   DB load approaches available vCPU, queueing or latency regresses, or batch
   work misses its window.

The database processor architecture is invisible to EKS. No container image,
node architecture, JDBC or MariaDB driver, service, or endpoint change is
required. Only outage recovery and the database's measured capacity matter.

### Very short R8g adoption steps

1. Finish the v26 and MariaDB 11.8 change and establish the baseline.
2. Select `db.r8g.4xlarge` for equal memory and lower cost, or
   `db.r8g.8xlarge` only if twice the memory has a measured use.
3. Make the class-only change in a maintenance window and verify EKS reconnects.
4. Keep or revert it using the before-and-after production thresholds above.

The July 2026 AWS announcement matters because R8g is now orderable for RDS
MariaDB in London. The live API confirms `db.r8g.4xlarge` is orderable with
MariaDB 11.8.8, gp3, read replicas, Enhanced Monitoring, Database Insights,
storage autoscaling, and Multi-AZ.

## 5. gp3 storage

The primary pays $139.50 per month for throughput above the included 500 MiB/s,
while the observed maximum was about 373 MiB/s. It provisions 2,000 MiB/s, but
the current class has an aggregate EBS bandwidth ceiling of 10,000 Mbps, or
about 1,192 MiB/s before protocol overhead. Some paid throughput therefore
cannot be delivered through this instance class. After the upgrade is stable,
reduce throughput to 1,000 MiB/s first, saving $93 per month. Observe a complete
business and batch cycle. If the margin remains acceptable, test 500 MiB/s and
save the full $139.50.

RDS performs storage optimization after a reduction, and latency can rise while
it runs. Monitor storage-operation status, read and write latency, queue depth,
throughput, replica lag, application latency, and errors.

Do not reduce IOPS yet. A reduction to the included 12,000 IOPS saves $276 per
month, but an isolated event reached 23,884 IOPS and queue depth 18.85. The event
must first be identified as removable or safely throttled. Storage capacity
cannot be reduced in place, and autoscaling is already enabled.

## 6. Multi-AZ and ENA Express

### Cost and effect

| Component | Current Single-AZ | Multi-AZ | Monthly delta |
|---|---:|---:|---:|
| Primary compute | $2,277.60 | $4,555.20 | +$2,277.60 |
| Primary gp3 capacity | $133.00 | $266.00 | +$133.00 |
| Primary extra IOPS | $276.00 | $552.00 | +$276.00 |
| Primary extra throughput | $139.50 | $277.50 | +$138.00 |
| Primary subtotal | $2,826.10 | $5,650.70 | +$2,824.60 |
| Existing replica | $275.35 | $275.35 | $0.00 |
| Deployment total | **$3,101.45** | **$5,926.05** | **+$2,824.60** |

This is a 91.1 percent increase. Multi-AZ synchronously maintains a standby in
another AZ and automatically fails over, typically in 60 to 120 seconds but
longer recovery is possible. The standby is not readable. Multi-AZ can add
commit latency, so compare commit time, error rate, EKS retry behavior, and
failover recovery. It is an availability purchase, not a read-scaling feature.

### Very short ENA Express steps

1. Approve and create or convert to Multi-AZ on an ENA Express eligible class.
2. Newly created eligible Multi-AZ instances receive Cross-AZ ENA Express by
   default. For an older eligible Multi-AZ instance, use one planned stop/start,
   class modification, or Scale Compute action.
3. Compare write and commit latency, latency variation, replication behavior,
   and a controlled failover before and after.

ENA Express has no separate charge. It raises single-flow bandwidth and uses
multi-pathing and congestion control for RDS primary-to-standby replication.
It does not accelerate EKS-to-RDS application traffic. No EKS proxy, CNI,
driver, service, or endpoint change is required. The app may see steadier or
lower commit latency, and its pods must still reconnect after the activation
outage or a failover.

AWS does not document an RDS-visible customer switch or status field for this
feature. Change evidence should record the eligible class and the lifecycle
action. Ask AWS Support for service-side confirmation if audit evidence needs
more than that.

## 7. Read routing and proxy boundary

Transparent safe-read routing is not a built-in AWS option for an ordinary RDS
MariaDB DB instance plus an ordinary read replica. RDS Proxy read-only endpoints
work with Aurora clusters and RDS Multi-AZ DB clusters, not this topology.

| Option | Who operates it | Relevance |
|---|---|---|
| Application uses explicit writer and replica endpoints | Application team | Out of scope because application behavior changes |
| MaxScale or ProxySQL in EKS | Operated and tested by us | Requires HA deployment, routing rules, transaction and session tests, lag controls, observability, upgrades, and failure drills |
| RDS Proxy to the primary | AWS | Connection management only; does not route reads to this ordinary replica |
| Aurora or RDS Multi-AZ DB cluster reader endpoint | AWS | Requires a different database architecture or engine capability |

Therefore no read-routing change is recommended for this production change.
If later commissioned, MaxScale or ProxySQL would be an EKS deployment handled
by us, not an automatic RDS feature. Its AWS cost is the EKS compute, load
balancing, logs, and availability footprint; licensing and engineering cost
also need separate assessment. The main risk is stale or misrouted data, not
the proxy's raw throughput.

## 8. Lower-cost resilience before Multi-AZ

RDS does not have a native product called Single-AZ failover. Single-AZ can be
recovered or replaced, but automatic cross-AZ failover is a Multi-AZ feature.

The existing $275.35-per-month read replica can be replaced by a replica in a
different AZ at the same steady list price. Same-region replication has no RDS
data-transfer charge. During replacement overlap, the extra replica costs about
$0.3772 per hour, or $9.05 for one day.

This is a warm, manual recovery path, not equivalent to Multi-AZ:

- Replication is asynchronous, so promotion can lose changes equal to replica
  lag.
- Promotion, application cutover, and creation of a replacement replica are
  manual.
- The current small class cannot be assumed to support the primary workload.
  It might need a class change before or after promotion, increasing downtime.
- The application endpoint changes unless a controlled DNS CNAME is placed in
  front of RDS endpoints.

This pattern can provide a much lower standing cost than a same-size Multi-AZ
standby when a longer RTO and non-zero RPO are contractually accepted. The
generic client explanation is in `rds-backup-recovery-client-overview.md`.

## 9. Quick deployment controls

| Change | Approximate monthly cost | Main gain | Main risk |
|---|---:|---|---|
| Stable private Route 53 name for the database | $0 if an existing private zone is used; otherwise $0.50 per hosted zone, with private-zone queries free | Recovery and promotion do not require edits to every EKS workload | Incorrect target or DNS caching during cutover |
| RDS event subscriptions and standard CloudWatch alarms | Often $0 within the first ten standard alarm metrics; otherwise about $0.10 per alarm metric plus notification delivery | Earlier warning of failure, storage, capacity, and replica-lag conditions | False alerts or an untested notification path |
| Enhanced Monitoring on the recovery replica | No RDS feature charge; CloudWatch Logs ingestion and retention vary with volume | OS evidence before deciding whether the replica can be promoted or resized | Small monitoring overhead and log cost |
| Export the RDS error log with explicit retention | Variable CloudWatch Logs ingestion and storage, normally low for error-only output | Durable failure evidence outside the database host | Unbounded cost if verbose logs are added without retention |
| Periodic point-in-time restore drill | A current-size temporary copy is about $3.87 per hour while retained, plus any logs, backup, and transfer | Proves backup usability, validation time, and EKS cutover | Operational effort; no production effect if isolated correctly |
| Deployment configuration audit | $0 | Detects missing retention, deletion protection, encryption, autoscaling, monitoring, alarms, and lifecycle controls | No runtime risk because the audit is read-only |

The Route 53 and CloudWatch figures are public list prices before account-level
free-tier use, private discounts, tax, and notification delivery. Each control
still needs its own change record because configuring the wrong target or alarm
can create operational risk even when the AWS charge is small.

## 10. Reserved pricing after the design is settled

This is cost control, not performance. Current one-year offers suggest that a
No Upfront reservation for the existing primary and replica classes would
reduce compute by roughly $799 per month. All Upfront is about $895 per month
cheaper on an effective-monthly basis, with about $18,299 paid up front.
Storage, IOPS, throughput, logs, and backups remain on demand.

Do not purchase before deciding Single-AZ versus Multi-AZ and M8g versus R8g.
The risk is financial lock-in to the wrong class, deployment option, engine, or
region.

## Features for other RDS clients

| Feature | Comparable monthly effect | When it can help | Why it is not a target recommendation |
|---|---:|---|---|
| io2 at 1,000 GiB and 24,000 IOPS | About $5,481.95 total, +$2,380.50 | Sustained high IOPS or strict persistent-storage latency | Current sustained I/O and latency are low |
| Dedicated Log Volume on io2 | Adds about $496.48 Single-AZ or $989.96 Multi-AZ | Redo or binary-log I/O is a measured bottleneck | Requires io1/io2 and current write latency is low |
| `db.m8gd.8xlarge` Optimized Reads | About $3,632.16 total, +$530.71 | Material temporary-object workload | Post-upgrade temporary-work evidence is not available |
| `db.r8gd.4xlarge` Optimized Reads | About $2,694.40 total, -$407.05 | Temporary-object work that also fits 16 vCPUs and local-storage limits | Combines two capacity changes |
| Larger memory class | `db.r8g.8xlarge` adds about $998.64 | Measured memory pressure or buffer-pool misses | At least 18.8 GiB was free and swap was negligible |
| Self-managed MaxScale or ProxySQL | Variable EKS, load-balancer, log, licence, and engineering cost | A tested read/write split is required for ordinary RDS replicas | Production semantics and failover testing are out of scope |
| RDS Proxy | About +$397.12 on the current 32-vCPU primary | Managed connection handling or smoother Multi-AZ failover | It cannot provide read routing for this instance-plus-replica topology |
| Cross-region read replica | Replica compute and storage plus cross-region transfer | Regional disaster recovery with an agreed asynchronous RPO | Higher cost and operational complexity than an in-region copy |
| M9g | Not priced because it is not currently orderable for this target in London | Supported future region and engine combinations | M8g and R8g are the orderable Graviton4 choices now |
| Aurora reader endpoint | Requires a separately priced engine migration | Managed reader routing and Aurora availability model | Not a MariaDB infrastructure toggle |

RDS for MariaDB does not provide Aurora Global Database, Aurora-style reader
autoscaling, or the three-instance readable-standby RDS Multi-AZ DB cluster
model. Clients needing those capabilities require a separate engine and
application compatibility assessment.

## Change order and common gates

1. Save configuration, cost, CloudWatch, Database Insights, application, and
   EKS baselines.
2. Deploy OpenEyes v26 and MariaDB 11.8 through Blue/Green, then verify
   Performance Schema and Optimized Writes.
3. Keep free Standard Insights, or buy only the retention or Advanced trial that
   has an identified operational owner and use case.
4. Trial `db.r8g.4xlarge` as a class-only production change.
5. Reduce gp3 throughput to 1,000 MiB/s, observe, then consider 500 MiB/s.
6. Replace the existing replica in a different AZ if the lower-cost manual
   recovery pattern is accepted.
7. Decide Multi-AZ separately, test failover, and record ENA Express activation.
8. Purchase a reservation only after the steady architecture is known.

Each change record should include application p95 and p99 latency, error rate,
throughput, DB load, CPU, free memory, connections, storage metrics, replica
lag, EKS pod count, stop conditions, rollback owner, rollback duration, and
before-and-after monthly cost. One material variable should change at a time.

## Official sources

- [Amazon RDS for MariaDB pricing](https://aws.amazon.com/rds/mariadb/pricing/)
- [Amazon Route 53 pricing](https://aws.amazon.com/route53/pricing/)
- [RDS gp3 storage](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html)
- [RDS instance-class hardware specifications](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.Summary.html)
- [RDS Multi-AZ deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html)
- [RDS Multi-AZ failover](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.Failover.html)
- [Cross-AZ ENA Express](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.CrossAZENAExpress.html)
- [July 2026 R8g and M8g regional expansion](https://aws.amazon.com/about-aws/whats-new/2026/7/amazon-rds-aurora-r8g-m8g-regions/)
- [May 2026 RDS ENA Express announcement](https://aws.amazon.com/about-aws/whats-new/2026/05/amazon-rds-ena-express-multiAZ/)
- [CloudWatch Database Insights modes](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Database-Insights.html)
- [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/)
- [Performance Schema automatic-management state](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.EnableMySQL.determining-status.html)
- [Turn on AWS-managed Performance Schema](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.EnableMySQL.RDS.html)
- [RDS Optimized Writes for MariaDB](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-optimized-writes-mariadb.html)
- [RDS Optimized Reads for MariaDB](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-optimized-reads-mariadb.html)
- [RDS Proxy reader-endpoint limitations](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy-endpoints.html)
- [RDS Blue/Green overview](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments-overview.html)
- [RDS read-replica promotion](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.Promote.html)
- [RDS point-in-time restore](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html)
