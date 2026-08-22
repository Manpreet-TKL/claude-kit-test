#!/bin/bash -l
# Manpreet 22/08/2026
set -e
exec docker exec -i codex-chrome playwright-mcp --cdp-endpoint http://127.0.0.1:9222
