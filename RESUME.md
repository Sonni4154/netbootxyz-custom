<!-- marin:header begin (script-owned: do not edit between these markers) -->
id: netboot-xyz
created: 2026-10-28
updated: 2026-10-28
<!-- marin:header end -->

# netboot-xyz: RESUME

## What changed
- 2026-10-28: created from the template (`scripts/new-package.sh`), then added `docker-compose.yml` (netbootxyz `0.7.6-nbxyz26`), `.env.example`, `scripts/verify.sh` and `docs/opnsense-dhcp.md`.

## Current state
Files written and `docker compose config` validates. Container not started. OPNsense DHCP not changed.

## Next step
1. `cp .env.example .env && docker compose up -d && scripts/verify.sh` on blackknight.
2. Owner applies the DHCP settings in `docs/opnsense-dhcp.md` (find which DHCP backend the gateway runs first).
3. PXE-boot a test VM on LAN and confirm the menu loads.
Revisit by: 2026-11-11

## Blockers / open questions
- Worklog schema `netboot_xyz` does not exist in the master worklog DB; entries go to the failover file until it is added (worklog project).
- Not yet in `marin/registry/roster.yaml`.
- No git remote; `repo:` in project.yaml stays null until one exists.

## Entities touched
blackknight (10.10.10.98, 100.115.61.40), opnsense_gw (DHCP, manual), container `netbootxyz`.
