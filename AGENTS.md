# AGENTS.md — netboot-xyz

netboot.xyz PXE server on blackknight for bare-metal network installs on the OPNsense LAN

This file is canonical for the project. `CLAUDE.md` is generated from it: edit here, not there.
Folder-wide rules (worklog, scope rule, coding standards, future-proofing checks) live in
`/docker/projects/CLAUDE.md` (copy: `docs/standards/root-claude.md`). A project may add rules and may never relax those.

- Worklog project slug: `netboot-xyz` (master Postgres schema `netboot_xyz`; failover `.claude/worklog/`). Write entries with `/docker/projects/marin/scripts/worklog.sh`; never write to either place by hand.
- Standards: `/docker/projects/marin/docs/standards/subfolders.md`. Progress goes in `RESUME.md`; update `project.yaml` when dependencies change.
- No literal secrets anywhere: `op://` references only.
- **Git:** Work on a branch, open a PR, never merge it, never push to `main`. The owner merges. Tests, lint and gitleaks must pass before every push (`scripts/hooks/pre-push` runs gitleaks); never force-push or rewrite history.

## Project rules
- `opnsense_gw` is protected (read-only). Never change OPNsense config; DHCP changes go in `docs/opnsense-dhcp.md` for the owner to apply.
- The admin UI has no auth: bind it to Tailscale or 127.0.0.1, never the LAN IP or 0.0.0.0.
- `config/` and `assets/` are runtime data (gitignored). Menu edits made in the admin UI live there.
- Pin the image tag in `.env.example`; bump it in its own commit after reading upstream release notes.
