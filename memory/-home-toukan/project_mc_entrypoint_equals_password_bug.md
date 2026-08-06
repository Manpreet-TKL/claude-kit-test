---
name: mc-entrypoint-equals-password-bug
description: "The mc image entrypoint's mirth.properties merge splits on '=' and strips trailing '=' from passwords - base64-padded (gpg -ndp) passwords crash-loop Mirth"
metadata: 
  node_type: memory
  type: project
  originSessionId: 26c64ecb-2f0e-4303-92ba-f2135b1b505d
  modified: 2026-08-05T12:34:54.131Z
---

The mc (BridgeLink) image's /opt/scripts/entrypoint.sh merges /run/secrets/mirth_properties into /opt/bridgelink/conf/mirth.properties with `while IFS='=' read -r key value`, which strips trailing '=' characters from the value. Any DB password ending in '=' (every `gpg --gen-random 2 20 | base64` output - base64 padding) reaches Mirth truncated, giving an "Access denied for user 'mirthconnect'" crash-loop while the secret files themselves verify fine.

**Why:** Found 2026-08-05 during oe-deploy rotate_secrets.sh -ndp E2E testing: rotation succeeded, all DB logins verified, yet mc crash-looped; the merged properties value was 27 chars vs the 28-char secret. environment-setup.sh -ndp has the same latent bug on first boot of any env with mc.

**How to apply:** Generated passwords for MIRTH_DB_PASSWORD must never contain '='. rotate_secrets.sh generatePass strips padding (`base64 | tr -d '=\n'`) and blacklists '='; environment-setup.sh -ndp is still unfixed (report, needs same fix). Real fix belongs in the OEImageBuilder entrypoint (split on first '=' only, preserve the remainder). Related: [[oe-v26-resetuserlock-null-institution]].
