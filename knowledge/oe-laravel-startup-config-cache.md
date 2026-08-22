# OE containers: Laravel config is cached at startup - an empty DATABASE_SSL_CA breaks it silently

Archived 2026-08-19 from the `cat` instance memory (instance since retired); the lesson
is generic to every oe-deploy stack.

**Symptom (cat, 2026-06-11):** `secrets/DATABASE_SSL_CA` was a 0-byte file while the
compose template set `MYSQL_ATTR_SSL_CA=/run/secrets/DATABASE_SSL_CA` on web/oe-manager.
Every Laravel-side DB connection (migrations in `85-migrate-up.sh`, Horizon, artisan)
looped on `SQLSTATE[HY000] [2002] Cannot connect to MySQL using SSL` /
`no valid certs found cafile stream`. The Yii side connects without SSL, so healthchecks
stayed green - containers reported healthy while Laravel was fully broken.

**Why:** an init script runs `artisan optimize` at container startup, baking the env into
`oe-laravel/bootstrap/cache/config.php`; `docker exec -e MYSQL_ATTR_SSL_CA=` or `env -u`
cannot override it after boot. Diagnose with a `php -r` direct PDO connect: works plain,
fails with `PDO::MYSQL_ATTR_SSL_CA => <empty file>`.

**Fix:** not an image bug (do not chase it in OEImageBuilder). Either populate the secret
with the real DB CA cert or drop `MYSQL_ATTR_SSL_CA` from the recipe, then redeploy so
startup re-caches config. Same class: oe-manager looping on redis 127.0.0.1:6379 when
Horizon is enabled but the recipe has no redis service.
