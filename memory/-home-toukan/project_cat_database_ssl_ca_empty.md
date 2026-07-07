---
name: cat-database-ssl-ca-empty
description: cat instance has an empty secrets/DATABASE_SSL_CA that breaks all Laravel DB connections; Laravel config is cached at container startup
metadata: 
  node_type: memory
  type: project
  originSessionId: b121674c-328b-40bb-a7b1-c471f12b2219
---

On the `cat` oe-deploy instance (as of 2026-06-11), `~/cat/secrets/DATABASE_SSL_CA` is a 0-byte file while the compose template sets `MYSQL_ATTR_SSL_CA=/run/secrets/DATABASE_SSL_CA` for web/oe-manager. Every Laravel-side DB connection (Laravel migrations in `85-migrate-up.sh`, Horizon, artisan) fails with `SQLSTATE[HY000] [2002] Cannot connect to MySQL using SSL` / `no valid certs found cafile stream` in an error loop. The Yii side connects without SSL, so healthchecks stay green - containers report healthy while Laravel is fully broken.

**Why:** an init script runs `artisan optimize` at container startup, so the env value is baked into `oe-laravel/bootstrap/cache/config.php` - `docker exec -e MYSQL_ATTR_SSL_CA=` or `env -u` cannot override it after boot. Diagnosis: `php -r` direct PDO connect works plain, fails with `PDO::MYSQL_ATTR_SSL_CA => <empty file>`.

**How to apply:** not an image bug - don't chase it in OEImageBuilder. Fix is in the instance: either populate the secret with the real DB CA cert (if DB SSL is wanted) or drop the `MYSQL_ATTR_SSL_CA` env from the recipe, then redeploy so startup re-caches config. Manager also loops on redis 127.0.0.1:6379 (Horizon enabled but recipe `db web ptk` has no redis service) - same pre-existing class. Related: [[node-2416-puppeteer-regression]]
