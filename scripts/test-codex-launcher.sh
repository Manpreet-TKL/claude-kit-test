#!/bin/bash -l
# Manpreet 14/09/2026
# Check launch defaults, explicit overrides, resume and concurrent profile writes.
set -e

kit_root="$(dirname "$(dirname "$(realpath "$0")")")"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT
mkdir -p "${test_root}/kit/scripts" "${test_root}/kit/generated" "${test_root}/bin" "${test_root}/codex"
cp "${kit_root}/codex.sh" "${test_root}/kit/"
cp "${kit_root}/scripts/codex-profile-defaults.sh" "${kit_root}/scripts/codex-mcp-gate.sh" "${test_root}/kit/scripts/"
source "${kit_root}/scripts/codex-profile-defaults.sh"
export CODEX_HOME="${test_root}/codex"
export CODEX_TEST_ARGS="${test_root}/args"
export PATH="${test_root}/bin:${PATH}"
unset CODEX_MODEL CODEX_REASONING_EFFORT
profile="${CODEX_HOME}/claude-kit.config.toml"
cat > "${test_root}/bin/codex" <<'MOCK'
#!/bin/bash
printf '%s\n' "$@" > "${CODEX_TEST_ARGS}"
MOCK
chmod 700 "${test_root}/bin/codex"
cat > "${test_root}/kit/generated/.codex.env" <<'ENV'
CODEX_MODEL=gpt-6-astra
CODEX_REASONING_EFFORT=xhigh
CODEX_PERMISSION_TIER=yolo
CODEX_MODE=auto
ENV
cat > "${profile}" <<'PROFILE'
# Preserve this comment and unrelated settings.
model = "gpt-5.6-sol"
model_reasoning_effort = "low"
model_verbosity = "high"
plan_mode_reasoning_effort = "medium"
[agents]
max_concurrent_threads_per_session = 10
[example]
model = "keep-nested-model"
PROFILE
chmod 600 "${profile}"
sed 's/^model = "gpt-5.6-sol"/model = "gpt-6-astra"/; s/^model_reasoning_effort = "low"/model_reasoning_effort = "xhigh"/' "${profile}" > "${test_root}/expected"

bash "${test_root}/kit/codex.sh"
cmp "${test_root}/expected" "${profile}"
! grep -Eq '^(model|model_reasoning_effort|plan_mode_reasoning_effort)=' "${CODEX_TEST_ARGS}"
[ "$(stat -c '%a' "${profile}")" = 600 ]
grep -qx 'default_permissions=":danger-full-access"' "${CODEX_TEST_ARGS}"

bash "${test_root}/kit/codex.sh" --model gpt-5.6-sol -c 'model_reasoning_effort="high"'
grep -qx 'gpt-5.6-sol' "${CODEX_TEST_ARGS}"
grep -qx 'model_reasoning_effort="high"' "${CODEX_TEST_ARGS}"
[ "$(grep -c '^model_reasoning_effort=' "${CODEX_TEST_ARGS}")" = 1 ]
CODEX_MODEL=gpt-5.6-terra CODEX_REASONING_EFFORT=medium bash "${test_root}/kit/codex.sh"
grep -qx 'model = "gpt-5.6-terra"' "${profile}"
grep -qx 'model_reasoning_effort = "medium"' "${profile}"
cp "${profile}" "${test_root}/saved"
for command in resume fork; do
    bash "${test_root}/kit/codex.sh" -C /tmp "${command}" --last
    cmp "${test_root}/saved" "${profile}"
done
bash "${test_root}/kit/codex.sh" exec resume --last
cmp "${test_root}/saved" "${profile}"
bash "${test_root}/kit/codex.sh" -- resume
cmp "${test_root}/expected" "${profile}"

sed -i 's/CODEX_MODE=auto/CODEX_MODE=bypassPermissions/' "${test_root}/kit/generated/.codex.env"
bash "${test_root}/kit/codex.sh"
grep -qx -- '--dangerously-bypass-approvals-and-sandbox' "${CODEX_TEST_ARGS}"
! grep -Eq '^(model|model_reasoning_effort|plan_mode_reasoning_effort)=' "${CODEX_TEST_ARGS}"

for ((i = 0; i < 12; i++)); do
    setCodexProfileDefaults "${profile}" gpt-6-astra xhigh &
done
wait
cmp "${test_root}/expected" "${profile}"
! compgen -G "${profile}.tmp.*" >/dev/null
! setCodexProfileDefaults "${profile}" 'bad"model' high
cmp "${test_root}/expected" "${profile}"

printf '[agents]\nmax_concurrent_threads_per_session = 10\n' > "${profile}"
setCodexProfileDefaults "${profile}" gpt-6-astra xhigh medium
head -3 "${profile}" > "${test_root}/defaults"
printf 'model = "gpt-6-astra"\nmodel_reasoning_effort = "xhigh"\nmodel_verbosity = "medium"\n' > "${test_root}/expected-defaults"
cmp "${test_root}/expected-defaults" "${test_root}/defaults"
echo "Codex launcher regression checks passed."
