# PXE boot from every VLAN

netboot.xyz runs on blackknight (`10.10.10.98`, LAN / VLAN 10). A machine on any other VLAN can PXE
boot from it once three things are true on that VLAN:

1. **DHCP** on that VLAN hands out next-server `10.10.10.98` and a boot file name.
2. **The firewall** passes that VLAN to `10.10.10.98` on UDP 69 (TFTP) and TCP 8080 (asset mirror).
3. **DNS and internet egress** work, for anything the local mirror does not hold (menus fall back to
   `boot.netboot.xyz`, unmirrored assets come from GitHub and distro mirrors).

Nothing changes on blackknight or the netboot container: it already answers any source address, and its
replies go back through the gateway (`10.10.10.1`). Nothing changes on the switch either.

`opnsense_gw` is protected, so every OPNsense step below is done by the owner in the web UI.
Each step says where it is done.

## VLANs

From the switch config. Subnets other than 10, 20, 25, 30 and 99 are assumed to follow the same
`10.10.<vlan>.0/24` pattern: confirm them in **OPNsense > Interfaces > Overview** before step 2.

| VLAN | Name | Subnet | PXE needs |
|---|---|---|---|
| 10 | LAN | 10.10.10.0/24 | DHCP only (same subnet, no rule) |
| 20 | WEBDEV | 10.10.20.0/24 | DHCP + rule |
| 25 | CONTAINERS | 10.10.25.0/24 | DHCP + rule |
| 30 | STORAGE | 10.10.30.0/24 | DHCP + rule |
| 40 | CAMERAS | 10.10.40.0/24 (confirm) | DHCP + rule |
| 50 | IOT | 10.10.50.0/24 (confirm) | DHCP + rule |
| 60 | GUEST | 10.10.60.0/24 (confirm) | DHCP + rule |
| 70 | DMZ | 10.10.70.0/24 (confirm) | DHCP + rule |
| 99 | MGMT | 10.10.99.0/24 | DHCP (already set) + rule |

The rule opens only TFTP and the read-only asset mirror on one host. The admin UI (3001) is not
included. If GUEST, IOT or CAMERAS should not be able to PXE boot, leave them out of the group in step 2.

## Step 1: find the DHCP backend (OPNsense web UI, read-only)

Under **Services**, see which of **ISC DHCPv4**, **Kea DHCP** or **Dnsmasq DNS & DHCP** is enabled on
the VLAN interfaces. Use only that backend's part of step 3.

## Step 2: one firewall rule for all VLANs (OPNsense web UI)

An interface group lets one rule cover every VLAN. OPNsense evaluates group rules after floating rules
and before each interface's own rules, so this pass rule wins over a "block to private networks" rule
on GUEST, IOT or DMZ.

1. **Firewall > Aliases**, add:
   - `NETBOOT_SERVER`, type **Host(s)**, content `10.10.10.98`.
   - `NETBOOT_PORTS`, type **Port(s)**, content `69` and `8080`.
   Apply.
2. **Firewall > Groups**, add group `PXE_VLANS`. Members: every VLAN interface except LAN (MGMT,
   WEBDEV, CONTAINERS, STORAGE, CAMERAS, IOT, GUEST, DMZ). Save.
3. **Firewall > Rules > PXE_VLANS**, add:
   - Action **Pass**, Quick ticked, Direction **in**, TCP/IP version **IPv4**, Protocol **TCP/UDP**
   - Source **PXE_VLANS net**
   - Destination **Single host or alias** `NETBOOT_SERVER`, destination port `NETBOOT_PORTS`
   - Log ticked (untick once everything boots)
   - Description `PXE: TFTP + asset mirror to blackknight`
   Save, then **Apply changes**.
4. **Firewall > Rules > Floating**: check there is no enabled **block** or **reject** rule with
   **Quick** set that matches these VLANs going to `10.10.10.0/24`. A quick floating block beats the group
   rule. If one exists, move or narrow it rather than adding another rule.

Return traffic needs no rule: pf keeps state for the client's request, and blackknight's dnsmasq
answers TFTP from port 69 (single-port mode), so the reply matches that state.

## Step 3: DHCP network boot on every VLAN (OPNsense web UI)

Values for every VLAN: next-server `10.10.10.98`, BIOS file `netboot.xyz.kpxe`, x64 UEFI file
`netboot.xyz.efi`, arm64 UEFI file `netboot.xyz-arm64.efi`. MGMT already has them (a VLAN 99 VM got
next-server 10.10.10.98 and `netboot.xyz.kpxe` on 2026-11-09). Copy MGMT's settings to the rest.

**ISC DHCPv4:** for each interface under **Services > ISC DHCPv4 > [VLAN]**, open **Network booting**
and fill the fields as in [opnsense-dhcp.md](opnsense-dhcp.md#isc-dhcpv4-services--isc-dhcpv4--lan). Save
and apply on each one. Also check **DNS servers** is empty (hands out the firewall) or the VLAN gateway.

**Kea DHCPv4:** for each subnet under **Services > Kea DHCP > Kea DHCPv4 > Subnets**, set **Next server**
`10.10.10.98` and the boot file name. Kea's GUI takes one file per subnet: use `netboot.xyz.efi`, except on
a subnet whose PXE clients are mostly legacy BIOS (Proxmox VMs on SeaBIOS) where `netboot.xyz.kpxe` fits.

**Dnsmasq:** the tag-based boot entries in [opnsense-dhcp.md](opnsense-dhcp.md#dnsmasq-dns--dhcp-services--dnsmasq-dns--dhcp)
apply to every DHCP range unless an entry is limited to one interface. Check that each VLAN has a DHCP
range and that the boot entries have no interface set.

## Step 4: DNS and egress (OPNsense web UI, read-only check)

On each VLAN, the client needs DNS (Unbound listening on that interface, **Services > Unbound DNS >
General > Network Interfaces**, or "All") and outbound HTTPS to the internet. VLANs that block internet
(often IOT and CAMERAS) still load the local menu over TFTP, but anything not in the local asset mirror
fails. Fill the mirror on blackknight with `scripts/fetch-assets.sh` if those VLANs need offline installs.

## Step 5: check blackknight's return route (on blackknight)

Replies must leave through `eno2` to `10.10.10.1`, not through Tailscale. For every VLAN:

```bash
for v in 20 25 30 40 50 60 70 99; do ip route get 10.10.$v.50 | head -1; done
```

Every line should read `via 10.10.10.1 dev eno2`. If one shows `tailscale0`, run
`sudo tailscale set --accept-routes=false` and check again.

## Step 6: test each VLAN

**On any Linux machine already on the VLAN** (quick check, no reboot):

```bash
curl -sf -o /tmp/nbx.efi tftp://10.10.10.98/netboot.xyz.efi && ls -l /tmp/nbx.efi
curl -s -o /dev/null -w 'mirror HTTP %{http_code}\n' http://10.10.10.98:8080/
```

**On pve (Proxmox shell)**, to PXE boot test VM 888 on another VLAN. Port 24 carries all VLANs tagged,
so this needs no switch change. Read the current NIC line first and keep its MAC:

```bash
qm config 888 | grep ^net0
# e.g. net0: virtio=BC:24:11:xx:xx:xx,bridge=vmbr0,tag=10
qm set 888 --net0 virtio=BC:24:11:xx:xx:xx,bridge=vmbr0,tag=20   # same MAC, new tag
qm reset 888                                                      # or qm start 888
```

Open the VM console and confirm the netboot.xyz menu appears. Put the tag back to 10 when done.
Test MGMT (tag 99) first: it is the VLAN that timed out on 2026-11-09.

## If a VLAN still times out

Run both while the client retries PXE:

- **On blackknight:** `sudo tcpdump -ni eno2 'udp port 69 or tcp port 8080'`
- **OPNsense web UI:** **Firewall > Log Files > Live View**, filter on destination `10.10.10.98`.

| What you see | Cause |
|---|---|
| Red block lines in Live View, nothing on blackknight | A rule above the group rule blocks it (floating quick block), or the interface is not in `PXE_VLANS` |
| Requests and replies on blackknight, client still times out | Return path: check step 5, then LAN outbound rules on OPNsense |
| Nothing in Live View and nothing on blackknight | DHCP on that VLAN is not handing out next-server; check step 3 |
| `netboot.xyz.kpxe` loads, then menu or asset fetch hangs | TCP 8080 blocked, or DNS / internet egress missing (step 4) |
