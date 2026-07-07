---
name: oe-v26-resetuserlock-null-institution
description: On OE v26, set_frontend_passwords.sh / yiic resetuserlock cannot reset users whose user_authentication has NULL institution_authentication_id (crash + validation block)
metadata: 
  node_type: memory
  type: project
  originSessionId: c5aa4d89-91f1-4e31-ac53-065c8c9fb6f1
---

On OpenEyes v26.0.0-rc3, `set_frontend_passwords.sh` → `yiic resetuserlock` is doubly broken for `user_authentication` rows with `institution_authentication_id = NULL` (e.g. monkey's `docman_user`, row id 15): `ResetUserLockCommand::actionReset` fatals at line 92 dereferencing the NULL `institutionAuthentication` relation, and even past that, `UserAuthentication.rules()` requires `institution_authentication_id`, so a validating `save()` can never succeed. `isLocalAuth()` treats NULL as local, so such rows are legitimate local accounts.

**Why:** Discovered fixing monkey's dead lightning-image cron (2026-06-09): the user's documented reset path silently can't work on these rows, and naive attempts mask the real error (the failure-branch `Audit::add` throws "Unable to save audit action" when given a long message, because audit_action lookup rows are keyed by the message string).

**How to apply:** Reset such passwords through the model pipeline mimicking the command: load the `UserAuthentication`, set `password`/`password_repeat` (+ `password_status` CURRENT, zero `password_failed_tries`), `validate()`, ignore *only* the `institution_authentication_id` error, then `save(false)` — bcrypt hashing happens in `afterValidate()`. Write the audit row inside try/catch with a short message. Run scripts with `docker exec -i <container> php < file` (container /tmp is tmpfs; `docker cp` writes are shadowed). Related: [[monkey-remote-chrome]].
