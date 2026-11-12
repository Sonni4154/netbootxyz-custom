# OPNsense DHCP settings for netboot.xyz

`opnsense_gw` is `protected: true` in `registry/hosts.yaml` (read-only until approved), so these
changes are made by the owner in the OPNsense web UI, not by an agent or by Ansible.

PXE needs two things from DHCP: the TFTP server address (option 66 / `next-server`) and the boot
file name (option 67). The file depends on the client firmware:

| Client firmware | DHCP option 93 (arch) | Boot file |
|---|---|---|
| Legacy BIOS | 0 | `netboot.xyz.kpxe` |
| UEFI x86_64 | 7 or 9 | `netboot.xyz.efi` |
| UEFI arm64 | 11 | `netboot.xyz-arm64.efi` |

TFTP server: `10.10.10.98` (blackknight, LAN / VLAN 10). These files are iPXE builds with the
netboot.xyz menu embedded, so there is no chainload loop to break.

Only one of the three DHCP backends below is active on the gateway. Use the section for the one in use.

## ISC DHCPv4 (Services > ISC DHCPv4 > LAN)

1. Open **Network booting**, tick **Enable network booting**.
2. **Set next-server IP**: `10.10.10.98`
3. **Set default bios filename**: `netboot.xyz.kpxe`
4. **Set x64 UEFI / EFI64 filename**: `netboot.xyz.efi`
5. **Set ARM64 UEFI filename** (if the field exists on this version): `netboot.xyz-arm64.efi`
6. Leave **Set iPXE boot filename** empty. Save, then apply.

## Kea DHCPv4 (Services > Kea DHCP > Kea DHCPv4 > Subnets)

The GUI gives one boot file per subnet, with no arch matching.
1. Edit the LAN subnet. **Next server**: `10.10.10.98`. **TFTP server / boot file name**: `netboot.xyz.efi`
   (UEFI clients only; legacy-BIOS machines will not boot). Save, then apply.

## Dnsmasq DNS & DHCP (Services > Dnsmasq DNS & DHCP)

Dnsmasq can pick the file by arch with tags. Field names vary between OPNsense releases;
confirm against the UI before applying.
1. **DHCP options**: add a *match* on option `client-arch` (93) value `7` with tag `efi64`; add another for `9`
   with the same tag.
2. **DHCP boot** (or the Boot tab): add an entry, tag `efi64`, filename `netboot.xyz.efi`, server address `10.10.10.98`.
3. Add a second boot entry with no tag, filename `netboot.xyz.kpxe`, server address `10.10.10.98` (the BIOS default).

## Firewall and client checks

- PXE clients on LAN reach blackknight on the same subnet, so no OPNsense rule is needed for TFTP.
  Clients on another VLAN need a pass rule to `10.10.10.98` UDP 69 and TCP 8080, and the boot files
  must be served via a DHCP scope on that VLAN. Step-by-step for every VLAN: [pxe-all-vlans.md](pxe-all-vlans.md).
- After the boot loader starts, menus and most images come from `boot.netboot.xyz` and distro mirrors
  over HTTPS, so the client VLAN needs internet egress (not via the ProtonVPN VLAN unless that is intended).
- Disable Secure Boot on the client; the netboot.xyz EFI loader is not signed.

## Test

From blackknight: `scripts/verify.sh`. Then PXE-boot a test machine (or a Proxmox VM on `vmbr` attached
to LAN with boot order set to network) and confirm the netboot.xyz menu appears.
