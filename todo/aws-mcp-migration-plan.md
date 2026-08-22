# AWS MCP migration - aws-api-mcp-server to the managed AWS MCP Server

Status: evaluated 2026-08-19 and PARKED. The kit stays on `aws-api-mcp-server`
(still working; upstream says "entering end of development", not switched off).
Migration is blocked on an upstream capability gap, and there is a prerequisite
IAM change worth applying regardless.

## Target

The AWS-managed remote MCP endpoint, reached through the SigV4-signing local
proxy `mcp-proxy-for-aws`, run as a container (image
`public.ecr.aws/mcp-proxy-for-aws/mcp-proxy-for-aws:latest`, v1.6.4 at
evaluation, entrypoint `mcp-proxy-for-aws`, runs as non-root `app`). Managed
endpoints exist only in `us-east-1` and `eu-central-1`; nearest is
`https://aws-mcp.eu-central-1.api.aws/mcp`.

## The blocker

The new server has no equivalent of the old `READ_OPERATIONS_ONLY=true`
(call_aws present, every command validated against a read-only allowlist).
Verified empirically 2026-08-19 by driving the proxy through a real MCP
initialize + tools/list handshake, with and without `--read-only`:

| Tool | readOnlyHint | without --read-only | with --read-only |
|---|---|---|---|
| aws___call_aws | false | yes | no |
| aws___run_script | false | yes | no |
| aws___get_presigned_url | false | yes | no |
| aws___search_documentation | true | yes | yes |
| aws___read_documentation | true | yes | yes |
| aws___retrieve_skill | true | yes | yes |
| aws___list_regions | true | yes | yes |
| aws___get_regional_availability | true | yes | yes |
| aws___get_tasks | true | yes | yes |

`--read-only` is the proxy's only tool-filtering flag (confirmed via --help)
and it removes the one tool the kit actually uses. The choice today is:

1. Without `--read-only`: also gains `aws___run_script` (arbitrary Python with
   a `call_boto3` binding) and `aws___get_presigned_url` (mints S3 GET/PUT
   URLs - a data-egress path). No per-tool off switch exists.
2. With `--read-only`: a documentation-search server; no estate reads at all.

Compounding: `aws___call_aws` describes itself as DEPRECATED in favour of
`run_script`, so the real destination is the Python sandbox, not a renamed
call_aws. The IAM condition keys AWS offers (`aws:ViaAWSMCPService`,
`aws:CalledViaAWSMCP`) act at AWS-API-action level and cannot remove an MCP
tool from the session.

## Prerequisite worth doing now (independent of migration)

The kit's read-only IAM user carries only the AWS-managed `ReadOnlyAccess`
policy - the explicit Deny that docs/aws.md prescribes for data-bearing reads
has never been attached. Human applies (one line):

`aws iam put-user-policy --user-name <kit-readonly-user> --policy-name DenyDataBearingReads --policy-document '{"Version":"2012-10-17","Statement":[{"Sid":"DenyDataBearingReads","Effect":"Deny","Action":["secretsmanager:GetSecretValue","ssm:GetParameter","ssm:GetParameters","ssm:GetParametersByPath","s3:GetObject","s3:GetObjectVersion","kms:Decrypt"],"Resource":"*"}]}'`

This also neutralises presigned-URL downloads: a presigned URL carries only the
signer's permissions.

## Proven mechanics (de-risked, reusable when migration goes ahead)

1. The container path works end to end - no uvx/uv/AWS CLI on the host.
2. Existing credentials work unchanged, passed with
   `--env-file ~/.claude/mcp-env/.aws.env` (the file is never read into model
   context).
3. SigV4 signing to eu-central-1 works; the proxy infers the signing region
   from the endpoint URL, so no explicit `--region` is needed even with
   `AWS_REGION=eu-west-2` in the env file.
4. `--metadata AWS_REGION=eu-west-2` sets the default operations region
   independently of the endpoint region. `--disable-telemetry` is accepted.

## Migration recipe (when unblocked, or if accepted without --read-only)

Precondition: the IAM Deny above is confirmed attached first.

1. `install.sh` applyAws(): swap the image to the proxy; args become the
   endpoint URL + `--metadata AWS_REGION=<region>` + `--disable-telemetry`
   (+ `--read-only` only if upstream ever makes it keep API reads); drop
   `READ_OPERATIONS_ONLY`, `AWS_API_MCP_TELEMETRY` and
   `AWS_API_MCP_ALLOW_UNRESTRICTED_LOCAL_FILE_ACCESS` (server-side concepts
   that no longer exist); keep the env file, the startup gate and the per-PID
   container name unchanged.
2. Permission tiers: keep the `mcp__aws` allow and `Bash(aws *)` deny; add
   explicit denies for `mcp__aws__aws___run_script` and
   `mcp__aws__aws___get_presigned_url` to all four tiers. Client-side guard
   rail only - weaker than the old server-side validation, the same caveat
   docs/github.md makes about deny lists.
3. docs/aws.md: rewrite the wiring and limitations sections (the three-layer
   diagram loses its server-side layer; IAM becomes the only real control).
4. skills/awsmcp/SKILL.md: tool names change (nine `aws___*` tools); rewrite
   "Using it well" - and the deprecation of call_aws means examples move to
   run_script if that is accepted.
5. skills/c-claude-kit/SKILL.md and README.md: update the `-a` description.
6. Verify: tools/list shows the expected set; one narrow read succeeds
   (`sts get-caller-identity`); a write verb is refused at the IAM layer.

## Re-check triggers

1. The proxy gains per-tool filtering, or a read-only mode that keeps API
   reads - re-evaluate immediately.
2. The old `aws-api-mcp-server` image stops being published or breaks - forced
   move; follow the recipe above including the tier denies.
3. A deliberate decision that `run_script` is wanted - same recipe.

Decision record 2026-08-19: option 1 (do not migrate yet) chosen over
(2) tighten IAM then migrate without `--read-only`, and (3) run both servers
(AWS advises against - tool-name conflicts - and the docs-only set is not
useful to the kit).
