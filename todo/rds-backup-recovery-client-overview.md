# Managed RDS backup and recovery overview

## Backup policy

Production databases use these layers:

1. Amazon RDS automated backups are encrypted and retained for seven days. RDS
   takes a daily storage backup and uploads transaction logs about every five
   minutes. This permits point-in-time recovery to any second within the
   retention window, up to the latest restorable time.
2. A manual RDS snapshot is taken before a planned database upgrade or other
   high-risk database change. It is retained until the change is accepted and
   its review date is reached.
3. An application-level backup job writes database dumps and protected files to
   a versioned, encrypted S3 bucket using an AWS role rather than stored access
   keys. Its execution frequency and object-retention period are recorded in the
   client service schedule.

Backups are encrypted. Access is limited to the production service and the
authorised recovery team. A restore creates a new database instance rather than
rewinding the live one in place.

## What happens in the main failure scenarios

| Scenario | Service effect | Potential data loss | Recovery |
|---|---|---|---|
| Single-AZ database host or instance failure | Database is unavailable while RDS attempts recovery | Normally none if storage is recoverable; if the instance cannot be recovered, the gap to the latest restorable time is at risk, typically up to about five minutes | Allow RDS recovery, or restore point-in-time to a new instance and redirect the application |
| Entire Availability Zone unavailable with Single-AZ RDS | Database remains unavailable because there is no automatic cross-AZ standby | Same point-in-time recovery exposure; an asynchronous replica can also be behind | Restore in an available AZ, or manually promote a healthy cross-AZ read replica if one was commissioned |
| Multi-AZ primary failure or AZ loss | Connections break while RDS automatically promotes the synchronous standby | No committed-data loss is expected from the synchronous standby; in-flight transactions can be rolled back | RDS changes the endpoint target automatically; failover is typically 60 to 120 seconds, then applications reconnect |
| Widespread incorrect data changes | Database remains online but its contents are wrong | Correct writes made after the chosen recovery time must be reconciled if the whole service is rolled back | Restore to a new instance at a time immediately before the incident, validate it, then repair selected data or cut over the whole service |

Restore time is not fixed. It depends on database size, the amount of recovery
work, validation, and application cutover. Planning should use an agreed RPO
for acceptable data loss and RTO for acceptable downtime rather than assuming a
guaranteed duration.

## Returning to one hour before incorrect changes

1. Stop or contain the process making the incorrect changes and record the last
   known-good UTC time.
2. Start an RDS point-in-time restore to a new instance at a time immediately
   before the first incorrect change.
3. Validate database integrity and the affected application journeys on the
   restored copy.
4. If the damage is limited, extract the correct records and apply a controlled,
   audited repair to the live database. If it is widespread, briefly stop
   writes, reconcile legitimate later changes, and direct the application to
   the restored instance.
5. Keep the original instance isolated for audit and rollback until the recovery
   is accepted.

Point-in-time recovery restores the whole RDS instance. It is not an in-place
undo operation and does not restore a single table by itself.

## Availability choices

There is no AWS RDS feature called Single-AZ failover. Single-AZ includes service
recovery and backup restore, but native automatic cross-AZ failover requires
Multi-AZ.

| Pattern | Standing cost | RPO and RTO | Main trade-off |
|---|---:|---|---|
| Single-AZ plus point-in-time recovery | No standby compute | RPO typically up to about five minutes; RTO can be hours | Lowest cost, longest outage |
| Smaller read replica in another AZ | Additional smaller compute and storage | Asynchronous RPO equals replica lag; manual promotion and cutover | Lower cost than a full-size standby, but possible data loss and reduced capacity |
| Full-size read replica in another AZ | Roughly another full database | Asynchronous RPO; manual promotion | Readable capacity, but cost approaches Multi-AZ without automatic failover |
| Multi-AZ DB instance | Roughly doubles primary compute and storage cost | Synchronous standby and automatic failover, typically 60 to 120 seconds | Best native RDS availability; standby is not readable |
| Cross-region replica or backup copy | Destination storage, compute, and transfer | Protects against a regional event; recovery remains a separate cutover | Higher cost and operational complexity |

A lower-cost service can be offered as "Single-AZ with warm cross-AZ recovery",
using a smaller read replica, alarms, a tested promotion runbook, and a stable
DNS name. It must not be described as automatic or zero-data-loss failover.

## Quick, low-cost deployment improvements

1. Put a low-TTL private DNS CNAME in front of the RDS endpoint so a restored or
   promoted database can be selected without editing every application host.
2. Alarm on backup failure, RDS failure and failover events, low storage, high
   CPU, low memory, connection exhaustion, and replica lag where a replica
   exists.
3. Run and record a periodic point-in-time restore drill, including application
   validation and DNS cutover timing.
4. Record an agreed RPO and RTO for Single-AZ, warm-replica, and Multi-AZ service
   levels.
5. Check seven-day retention, deletion protection, encryption, snapshot tagging,
   storage autoscaling, and monitoring as part of every deployment review.
6. Set explicit CloudWatch log retention and review backup and snapshot lifecycle
   dates so evidence is retained without unbounded storage cost.
7. Keep the known-good database after a restore until validation is complete.
   Do not delete it merely to reuse an RDS identifier.

## AWS references

- [RDS point-in-time restore](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html)
- [Restore from an RDS snapshot](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_RestoreFromSnapshot.html)
- [RDS Multi-AZ failover](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.Failover.html)
- [Promote an RDS read replica](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.Promote.html)
- [RDS resilience](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/disaster-recovery-resiliency.html)
