---
name: openmrs-first-boot-long
description: "On the monkey oe-deploy stack, OpenMRS 3 ref-app backend first-boot WAR deployment took ~73 min; expect long initial Liquibase runs, especially when sharing the OE MariaDB."
metadata: 
  node_type: memory
  type: project
  originSessionId: 4fa032d4-fe44-4ce5-b660-811da2ca7318
---

OpenMRS reference-application 3.x backend first-boot deployment on `monkey` took **~73 minutes** end-to-end: Tomcat reported `Server startup in [4413944] ms`. Don't quote "5–10 minutes" — that's wrong.

**Why:** the WAR expands lazily into `/openmrs/data/...`, then Liquibase runs every changeset (~hundreds) against the empty `openmrs` schema, and on monkey the same MariaDB instance is simultaneously serving OE's own migrations / oe-manager seeding. Contention plus a large changeset count = long wall-clock time. Subsequent container restarts (with the WAR already expanded on the data volume) come up in seconds — only the first boot is slow.

**How to apply:** When the user asks "is OpenMRS up yet?" or sees a connection-refused on `:82` shortly after `build.sh`, don't poll-busy-wait or panic. Tail `docker logs -f monkey-omrs-backend-1` and wait for `Deployment of web application archive [...openmrs.war] has finished` followed by `Starting ProtocolHandler ["http-nio-8080"]`. Set expectations: "first boot can take an hour-plus". The legacy UI lives at `/openmrs/login.htm` (bare `/openmrs/` returns `{}` from the REST API root).
