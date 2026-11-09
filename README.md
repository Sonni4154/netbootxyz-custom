# netboot-xyz

[netboot.xyz](https://netboot.xyz) PXE server on blackknight, so any machine on the OPNsense LAN can
network-boot an installer or live tool without a USB stick.

> **Standards:** this project follows [`docs/standards/subfolders.md`](/docker/projects/marin/docs/standards/subfolders.md).
> Progress lives in `RESUME.md`; identity and dependencies in `project.yaml`.

## Purpose and owner
Owner: sonny. One container (`ghcr.io/netbootxyz/netbootxyz`, pinned tag) serves:

| What | Where | Who reaches it |
|---|---|---|
| TFTP boot loaders (`netboot.xyz.kpxe`, `netboot.xyz.efi`) | `10.10.10.98:69/udp` | PXE clients on LAN |
| Local asset mirror (nginx) | `10.10.10.98:8080` | PXE clients on LAN |
| Admin web UI (menu editing, asset downloads) | `100.115.61.40:3001` | Tailscale only; no login |

OPNsense DHCP hands clients the TFTP server and boot file: [`docs/opnsense-dhcp.md`](docs/opnsense-dhcp.md).

## How to run
```bash
cp .env.example .env     # check NETBOOT_LAN_IP matches blackknight's LAN address
docker compose up -d
scripts/verify.sh        # TFTP, asset mirror and admin UI checks
sudo bash branding/install-branding.sh   # optional graphical boot menu
```

## Boot menu theme
The graphical boot menu (background picture, 1920x1080) lives in [`branding/`](branding/README.md).
Install it with `sudo bash branding/install-branding.sh` after the container is up.

## How to deploy
Runs on blackknight only, from this folder. Not in Ansible yet. The OPNsense DHCP change is a manual
owner step (the gateway is protected).

## Future-proofing checks (root CLAUDE.md, section 4)
1. Security: TFTP and the asset mirror are anonymous read-only and bound to the LAN IP only. The admin UI
   has no authentication, so it binds to the Tailscale IP only; tailnet ACLs are the check. Putting it
   behind Authentik (`@sonni4154/marin-auth` / forward auth) is the next step if more people get tailnet access.
   Anyone on LAN can PXE-boot an installer; that is the point, and it only works with physical/console access to the client.
2. Multi-tenancy: no business data and no tenant-owned rows. Not applicable.
3. Integration independence: netboot.xyz is plain TFTP + HTTP iPXE. If it vanished, swap in any iPXE
   build or a plain `pxelinux` tree in the same container slot; the OPNsense side (next-server + filename) stays.
4. Resale readiness: IPs, ports and the image tag come from `.env`; nothing Marin-specific is in the compose file.
   The IPs in `docs/opnsense-dhcp.md` are this site's values.
5. Operations: the container healthcheck marks it unhealthy if the web app stops; `scripts/verify.sh` checks
   TFTP and HTTP end to end. Nothing alerts yet (no monitoring hook).
