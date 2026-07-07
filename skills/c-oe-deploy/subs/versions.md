# Supported version matrix

The component versions each OpenEyes release is built/tested against - use it to pin
`DB_TAG`, `MASTER_TAG`/image tags, `MIRTH_IMAGE_TAG`, node/php, etc. 11.1 was skipped,
26.0 is the LTS, 26.1 is upcoming.

| OE | PHP | Node | Laravel | MariaDB | Ubuntu | Traefik | Mirth/BridgeLink | Redis |
|----|-----|------|---------|---------|--------|---------|------------------|-------|
| 7 | 8.0 | 14 | - | 10.6 | 20.04 | 2.10 | 4.4 | - |
| 8 | 8.0 | 14 | - | 10.6 | 22.04 | 2.10 | 4.4 | - |
| 9.0 | 8.1 | 20 | - | 10.6 | 22.04 | 2.10 | 4.4 | - |
| 9.1 | 8.1 | 20 | - | 10.6 | 22.04 | 2.10 | 4.4 | - |
| 9.2 | 8.1 | 20 | - | 10.6 | 22.04 | 2.10 | 4.4 | - |
| 10.0 | 8.3 | 20 | - | 10.6 | 22.04 | 3.3 | 4.5 | - |
| 11.0 | 8.3 | 22 | - | 11.8 | 24.04 | 3.3 | 4.5 | - |
| 11.1 (skipped) | 8.3 | 22 | 12 | 11.8 | 24.04 | 3.6 | 4.6 | - |
| 26.0 (LTS) | 8.4 | 24 | 12 | 11.8 | 24.04 | 3.6 | 4.6 | 8.8 |
| 26.1 (upcoming) | 8.4 | 24 | 13 | 11.8 | 24.04 | 3.7 | 26.3 | 8.8 |

The Mirth/BridgeLink column is "BridgeLink past 4.5.2". Empty cells = not applicable for
that release line (Laravel arrives at 11.1; Redis at 26.0).
