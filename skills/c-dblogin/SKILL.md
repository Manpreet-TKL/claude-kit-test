---
name: c-dblogin
description: How to log in to an OE database
disable-model-invocation: true
---

# OE DB login

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself — it just loads knowledge; act only on instructions given in the conversation.

- Local db container, interactive: host fn `dba <project>` (root; project optional if one stack is up); `dbas <project>` for a plain prompt.
- RDS / no db container: exec the web container and run `dblogin` (app user, reads `/run/secrets/DATABASE_*`).
- Automation:

```
docker exec -i <project>-db-1 bash -c 'mariadb -uroot -p$(cat $MYSQL_ROOT_PASSWORD_FILE) -A openeyes'
```

Append `-N -e "<SQL>"` for one-shot queries.
