---
name: project-oe-host-checkout-lags-container
description: "The host ~/openeyes clone can be days behind the running web container; verify OE behaviour against the container's own git and the live DB, never the host clone."
metadata: 
  node_type: memory
  type: project
  originSessionId: f84adcb3-d9b5-4ddc-ac2d-5cf16466a2c7
  modified: 2026-08-05T06:17:05.560Z
---

`~/openeyes` on the host is a convenience clone and drifts behind the running stack.
On 2026-08-05 the host sat at `04c938c0a4` (2026-07-29) while the web container ran
`53b077c089` (2026-08-04), and the database had two migrations applied that the host
checkout did not contain - so a column the host code still referenced
(`ophciexamination_clinicoutcome_status.rtt_clock_state_option_group_id`) was already
dropped in the live system.

Consequence: documentation or analysis derived from the host clone can describe
screens, columns and fields that no longer exist. The web container carries its own
working `.git`, so `docker exec <web> sh -c 'cd /var/www/openeyes && git log --oneline -1'`
is the authoritative version, and the live DB is the authoritative schema.

Two container gotchas that go with this: `docker cp` cannot read the web container's
`/tmp` (tmpfs - it reports "Could not find the file" even though `ls` shows it), so
stream files out with `docker exec <c> cat /tmp/x > host`; and a Node script placed in
`/tmp` cannot `require('puppeteer')` because module resolution walks up from the
script's own directory - put it under the app root instead.

Related: [[project-oeimagebuilder-build-gotchas]], [[project-monkey-environment]].
