# AWS MCP migration - CLOSED 2026-09-06

**Outcome: the migration was rejected, and the MCP server was removed rather than
replaced.** The kit now reads AWS through the official `aws-cli` container, driven
by `scripts/agent-aws-cli.sh`. Setup, design and limitations live in `docs/aws.md`;
this file is kept only as the record of why the managed server was not adopted.

## What forced a decision

`aws-api-mcp-server` wraps **AWS CLI v1**, which entered maintenance on 15/07/2026
and is **removed on 15/07/2027**. The MCP server inherits both dates exactly, so
staying put had a hard deadline even though the image was still shipping
(v1.5.4, 01/09/2026).

## Why the managed AWS MCP Server was rejected

Verified 2026-09-06 by handshaking both live endpoints, not from the docs - the
upstream MIGRATION.md still claims `aws___call_aws` exists "with the same coverage
as the old call_aws", and it does not.

| Finding | Consequence |
|---|---|
| `aws___call_aws` has been **removed** from both us-east-1 and eu-central-1 | the only remaining estate-read path is `aws___run_script` |
| `run_script` executes arbitrary Python with a generic `call_boto3` binding | strictly wider than the CLI surface it replaces, and unauditable per call |
| `--read-only` strips `run_script` | leaves a documentation server that cannot read the estate at all |
| Endpoints exist only in **us-east-1 and eu-central-1** | every read of a London estate would be processed in Frankfurt |
| New `get_presigned_url` tool | an egress path that did not exist before |
| Headline features (15k APIs, all-region fan-out) | irrelevant to single-region eu-west-2 work |

## What replaced it

`public.ecr.aws/aws-cli/aws-cli:latest` (CLI v2, no EOL), one shared container
`ai-kit-aws-ro`, 8h idle timeout, behind the same one-shot gate. Data stays in
London, no Python sandbox in the path, and the EOL problem is removed rather than
reset. Claude Code and standalone Codex share the script and the container.

## The cost, carried forward

`READ_OPERATIONS_ONLY=true` is gone and was **not** reimplemented - a deliberate
choice. The pre-flight allow-list it enforced is derived from the public AWS
Service Reference (`https://servicereference.us-east-1.amazonaws.com/`, whose
`Annotations.Properties.IsWrite` flag is the actual source of truth, plus a small
`sts`/`iam`/`sso` override list), so it remains reimplementable if the absence ever
bites. **IAM is now the only enforcement.**

Still open, and now the only mitigation left below the IAM policy itself: the
`DenyDataBearingReads` inline policy has never been attached to
`sami-claude-mcp-readonly` (confirmed 2026-09-06: managed `ReadOnlyAccess` only, no
inline policies, no groups). Without it the key can read
`secretsmanager:GetSecretValue`, `ssm:GetParameter`, `s3:GetObject` and
`kms:Decrypt`. Scoped out by decision, not by oversight.

## Re-check triggers

1. AWS ships a managed endpoint in eu-west-2 **and** restores a bounded read tool.
2. `ReadOnlyAccess` stops being sufficient for the reads in use.
3. Anything in the estate needs a write path - it does not get one here; writes are
   printed for a human to run in CloudShell.
