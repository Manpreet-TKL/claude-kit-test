#!/bin/bash -l
set -e
secrets="${HOME}/.claude/mcp-env/.aws.env"
[ -f "${secrets}" ] || { echo "Missing ${secrets}" >&2; exit 1; }
set -a
. "${secrets}"
set +a
export READ_OPERATIONS_ONLY=true
export AWS_API_MCP_TELEMETRY=false
export AWS_API_MCP_ALLOW_UNRESTRICTED_LOCAL_FILE_ACCESS=no-access
exec docker run -i --rm --name "codex-mcp-aws-$$" -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_REGION -e READ_OPERATIONS_ONLY -e AWS_API_MCP_TELEMETRY -e AWS_API_MCP_ALLOW_UNRESTRICTED_LOCAL_FILE_ACCESS public.ecr.aws/awslabs-mcp/awslabs/aws-api-mcp-server:latest
