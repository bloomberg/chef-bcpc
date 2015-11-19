# Testing UEFI PxE

This can be somewhat complex. The following steps should allow one to test that
the configured PxE functionality will at least UEFI PXE clients.
In order to do so, we inspect the packet exchanges between the
configured dhcp and tftp servers and the PxE client. There are various
resources online for the particulars of the exchanges. One reasonable such
resource is located at http://www.tcpipguide.com/free/t_BOOTPDetailedOperation.htm

In the inspected packets, it should be noted that the Boot file name should
assume one of two values, dependent upon the value of `Option (93) Client
System Architecture` presented by the PxE client. It should be one of the
following:

- `efi64/syslinux.efi`
- `bios/pxelinux.0`

To accomplish all this, we use Qemu with a custom firmware. Thus, a few steps
are required:

1. Configure cobbler with the PxE client information
2. Build custom firmware
3. Run a packet capture for BOOTP and DHCP traffic
4. Boot a QEMU instance using the custom firmware
5. Analyze capture results

The previous steps can be executed on any one of the VMs except
the bootstrap node. All the example commands assume we are on bcpc-vm1.

## Configure cobbler with the PxE client information
This is on the bootstrap node. For example, adding a fictitous host
uefi-pxe-client, where it will be launched on bcpc-vm1.
```
$ read _ _ dev _ < <(ip route get 10.0.100.11)
$ cobbler system add --name=uefi-pxe-client --profile=bcpc_host
--ip-address=10.0.100.99 --mac=fa:16:3e:28:5d:93 --interface=$dev && cobbler
sync
```

## Build custom firmware
See the following links:
* http://www.linux-kvm.org/downloads/lersek/ovmf-whitepaper-c770f8c.txt
* https://github.com/tianocore/edk2/blob/master/OvmfPkg/README

1. Download prerequisites
  * Build dependencies
  ```
  $ sudo apt-get install -y uuid-dev nasm acpica-tools p7zip-full git
  ```
  * Intel e1000 driver
  The license terms will need to be accepted before the binary can be downloaded.
  Something like:
  ```
  $ sudo apt-get install -y lynx
  $ lynx 'http://downloadcenter.intel.com/Detail_Desc.aspx?agr=Y&DwnldID=17515&lang=eng'
  ...
  ```
  * OVMF Sources
  ```
  $ git clone https://github.com/tianocore/edk2.git
  ```
  * Build OVMF with Intel Driver Support
  ```
  $ cd edk2
  $ 7z x -oIntel3.5 ../PROEFI_v13_5.exe
  $ nice OvmfPkg/build.sh -a X64 -n $(getconf _NPROCESSORS_ONLN) -D E1000_ENABLE -D FD_SIZE_2MB
  ```

## Run a packet capture for BOOTP and DHCP traffic
Run the packet capture on the bootstrap node
```
sudo tshark -i eth1 -p -Otftp,bootp,bootparams port 67 or 68
```

### Configure the networking for QEMU
To access the DHCP server on bcpc-bootstrap, the launched instance of qemu will need
to attach to a bridge that contains an interface that could reach it. Add the following
fragment to a file `/etc/network/interfaces.d/br0.cfg`
```
iface br0 inet static
 address 10.0.100.11
 netmask 255.255.255.0
 gateway 10.0.100.3
 metric 100
 bridge_ports eth1
 bridge_stp off
 bridge_maxwait 0
 bridge_fd 0
 post-up ip link show eth1 | sed -n 's:.*link/ether \([^ ]\+\)\>.*:\1:p' | xargs ip link set dev br0 address
```

Then another file needs to be added to `/usr/local/share/qemu/qemu-ifup`
```
$ cd /tmp && git clone https://gist.github.com/21fabb0221b8a7b82fce.git
$ sudo install -D /etc/qemu-ifup  /usr/local/share/qemu/qemu-ifup
$ sudo bash -c 'cd /usr/local/share/qemu && patch -p2 < /tmp/21fabb0221b8a7b82fce/qemu-ifup.patch'
```
And another to handle the new routing. Add the following to 
`/etc/network/if-up.d/mgmt-br0-routing` and `chmod 755`.
```
#!/bin/bash
# Only do this if br0 is coming up under very specific circumstances

if [[  $IFACE == "br0" ]] ; then
  # Transform the routes, remove the old ones and load the new
  while read oldroute; do
    newroute=${oldroute//eth1/br0}
    ip route del $oldroute table mgmt
    ip route add $newroute table mgmt
  done < <( ip route list table mgmt | grep eth1 )

  # Remove all eth1 routes from main table
  ip route list dev eth1 | xargs ip route del
fi
```

## Boot a QEMU instance using the custom firmware

### UEFI mode
```
$ /usr/bin/qemu-system-x86_64 -serial stdio -boot n -bios \
edk2/Build/OvmfX64/DEBUG_GCC48/FV/OVMF.fd -device \
e1000,netdev=mynet0,id=net0,mac=fa:16:3e:28:5d:93,romfile= -netdev \
tap,ifname=tun2,id=mynet0,script=/usr/local/share/qemu/qemu-ifup -debugcon \
file:debug.log -global isa-debugcon.iobase=0x402 -m 768 -vnc 127.0.0.1:1
```
### Legacy BIOS mode
```
$ /usr/bin/qemu-system-x86_64 -boot n -serial stdio -option-rom \
/chef-bcpc-files/gpxe-1.0.1-80861004.rom -device \
virtio-net-pci,netdev=mynet0,id=net0,mac=fa:16:3e:28:5d:93 -netdev \
tap,ifname=tun2,id=mynet0,script=/usr/local/share/qemu/qemu-ifup -debugcon \
file:debug.log -global isa-debugcon.iobase=0x402 -m 768 -vnc 127.0.0.1:1
 ```

It should be noted that any of the e1000-* nics available as parameters to
-device should work.

## Analyze capture results

Unfortunately, at the time of this writing, both invocations of qemu - one
testing UEFI as well as the other testing Legacy BIOS booting do not result in
a complete PXE boot sequence; i.e, the client does not move on to retrieve and
load the boot image. Either way, from the following captures, it should suffice
to observe that the correct boot filename is returned to the PXE client for
in either case.

In the shell running the capture, something similar to the following should appear:
### UEFI mode
```
Frame 31: 389 bytes on wire (3112 bits), 389 bytes captured (3112 bits) on interface 0
Internet Protocol Version 4, Src: 0.0.0.0 (0.0.0.0), Dst: 255.255.255.255 (255.255.255.255)
User Datagram Protocol, Src Port: bootpc (68), Dst Port: bootps (67)
Bootstrap Protocol
    Message type: Boot Request (1)
    Hardware type: Ethernet (0x01)
    Hardware address length: 6
    Hops: 0
    Transaction ID: 0xd46ff1a0
    Seconds elapsed: 0
    Bootp flags: 0x8000 (Broadcast)
        1... .... .... .... = Broadcast flag: Broadcast
        .000 0000 0000 0000 = Reserved flags: 0x0000
    Client IP address: 0.0.0.0 (0.0.0.0)
    Your (client) IP address: 0.0.0.0 (0.0.0.0)
    Next server IP address: 0.0.0.0 (0.0.0.0)
    Relay agent IP address: 0.0.0.0 (0.0.0.0)
    Client MAC address: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
    Client hardware address padding: 00000000000000000000
    Server host name not given
    Boot file name not given
    Magic cookie: DHCP
    Option: (53) DHCP Message Type
        Length: 1
        DHCP: Discover (1)
    Option: (57) Maximum DHCP Message Size
        Length: 2
        Maximum DHCP Message Size: 1472
    Option: (55) Parameter Request List
        Length: 35
        Parameter Request List Item: (1) Subnet Mask
        Parameter Request List Item: (2) Time Offset
        Parameter Request List Item: (3) Router
        Parameter Request List Item: (4) Time Server
        Parameter Request List Item: (5) Name Server
        Parameter Request List Item: (6) Domain Name Server
        Parameter Request List Item: (12) Host Name
        Parameter Request List Item: (13) Boot File Size
        Parameter Request List Item: (15) Domain Name
        Parameter Request List Item: (17) Root Path
        Parameter Request List Item: (18) Extensions Path
        Parameter Request List Item: (22) Maximum Datagram Reassembly Size
        Parameter Request List Item: (23) Default IP Time-to-Live
        Parameter Request List Item: (28) Broadcast Address
        Parameter Request List Item: (40) Network Information Service Domain
        Parameter Request List Item: (41) Network Information Service Servers
        Parameter Request List Item: (42) Network Time Protocol Servers
        Parameter Request List Item: (43) Vendor-Specific Information
        Parameter Request List Item: (50) Requested IP Address
        Parameter Request List Item: (51) IP Address Lease Time
        Parameter Request List Item: (54) DHCP Server Identifier
        Parameter Request List Item: (58) Renewal Time Value
        Parameter Request List Item: (59) Rebinding Time Value
        Parameter Request List Item: (60) Vendor class identifier
        Parameter Request List Item: (66) TFTP Server Name
        Parameter Request List Item: (67) Bootfile name
        Parameter Request List Item: (97) UUID/GUID-based Client Identifier
        Parameter Request List Item: (128) DOCSIS full security server IP [TODO]
        Parameter Request List Item: (129) PXE - undefined (vendor specific)
        Parameter Request List Item: (130) PXE - undefined (vendor specific)
        Parameter Request List Item: (131) PXE - undefined (vendor specific)
        Parameter Request List Item: (132) PXE - undefined (vendor specific)
        Parameter Request List Item: (133) PXE - undefined (vendor specific)
        Parameter Request List Item: (134) PXE - undefined (vendor specific)
        Parameter Request List Item: (135) PXE - undefined (vendor specific)
    Option: (97) UUID/GUID-based Client Identifier
        Length: 17
        Client Identifier (UUID): 00000000-0000-0000-0000-000000000000
    Option: (94) Client Network Device Interface
        Length: 3
        Major Version: 3
        Minor Version: 16
    Option: (93) Client System Architecture
        Length: 2
        Client System Architecture: EFI BC (7)
    Option: (60) Vendor class identifier
        Length: 32
        Vendor class identifier: PXEClient:Arch:00007:UNDI:003016
    Option: (255) End
        Option End: 255

31 Frame 32: 342 bytes on wire (2736 bits), 342 bytes captured (2736 bits) on interface 0
Ethernet II, Src: CadmusCo_cf:9f:11 (08:00:27:cf:9f:11), Dst: Broadcast (ff:ff:ff:ff:ff:ff)
Internet Protocol Version 4, Src: 10.0.100.3 (10.0.100.3), Dst: 255.255.255.255 (255.255.255.255)
User Datagram Protocol, Src Port: bootps (67), Dst Port: bootpc (68)
Bootstrap Protocol
    Message type: Boot Reply (2)
    Hardware type: Ethernet (0x01)
    Hardware address length: 6
    Hops: 0
    Transaction ID: 0xd46ff1a0
    Seconds elapsed: 0
    Bootp flags: 0x8000 (Broadcast)
        1... .... .... .... = Broadcast flag: Broadcast
        .000 0000 0000 0000 = Reserved flags: 0x0000
    Client IP address: 0.0.0.0 (0.0.0.0)
    Your (client) IP address: 10.0.100.99 (10.0.100.99)
    Next server IP address: 10.0.100.3 (10.0.100.3)
    Relay agent IP address: 0.0.0.0 (0.0.0.0)
    Client MAC address: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
    Client hardware address padding: 00000000000000000000
    Server host name not given
    Boot file name: efi64/syslinux.efi
    Magic cookie: DHCP
    Option: (53) DHCP Message Type
        Length: 1
        DHCP: Offer (2)
    Option: (54) DHCP Server Identifier
        Length: 4
        DHCP Server Identifier: 10.0.100.3 (10.0.100.3)
    Option: (51) IP Address Lease Time
        Length: 4
        IP Address Lease Time: (21600s) 6 hours
    Option: (1) Subnet Mask
        Length: 4
        Subnet Mask: 255.255.255.0 (255.255.255.0)
    Option: (3) Router
        Length: 4
        Router: 10.0.100.3 (10.0.100.3)
    Option: (6) Domain Name Server
        Length: 8
        Domain Name Server: 8.8.8.8 (8.8.8.8)
        Domain Name Server: 8.8.4.4 (8.8.4.4)
    Option: (255) End
        Option End: 255
    Padding
    
32 Frame 33: 401 bytes on wire (3208 bits), 401 bytes captured (3208 bits) on interface 0
Ethernet II, Src: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93), Dst: Broadcast (ff:ff:ff:ff:ff:ff)
Internet Protocol Version 4, Src: 0.0.0.0 (0.0.0.0), Dst: 255.255.255.255 (255.255.255.255)
User Datagram Protocol, Src Port: bootpc (68), Dst Port: bootps (67)
Bootstrap Protocol
    Message type: Boot Request (1)
    Hardware type: Ethernet (0x01)
    Hardware address length: 6
    Hops: 0
    Transaction ID: 0xd46ff1a0
    Seconds elapsed: 0
    Bootp flags: 0x8000 (Broadcast)
        1... .... .... .... = Broadcast flag: Broadcast
        .000 0000 0000 0000 = Reserved flags: 0x0000
    Client IP address: 0.0.0.0 (0.0.0.0)
    Your (client) IP address: 0.0.0.0 (0.0.0.0)
    Next server IP address: 0.0.0.0 (0.0.0.0)
    Relay agent IP address: 0.0.0.0 (0.0.0.0)
    Client MAC address: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
    Client hardware address padding: 00000000000000000000
    Server host name not given
    Boot file name not given
    Magic cookie: DHCP
    Option: (53) DHCP Message Type
        Length: 1
        DHCP: Request (3)
    Option: (54) DHCP Server Identifier
        Length: 4
        DHCP Server Identifier: 10.0.100.3 (10.0.100.3)
    Option: (50) Requested IP Address
        Length: 4
        Requested IP Address: 10.0.100.99 (10.0.100.99)
    Option: (57) Maximum DHCP Message Size
        Length: 2
        Maximum DHCP Message Size: 1472
    Option: (55) Parameter Request List
        Length: 35
        Parameter Request List Item: (1) Subnet Mask
        Parameter Request List Item: (2) Time Offset
        Parameter Request List Item: (3) Router
        Parameter Request List Item: (4) Time Server
        Parameter Request List Item: (5) Name Server
        Parameter Request List Item: (6) Domain Name Server
        Parameter Request List Item: (12) Host Name
        Parameter Request List Item: (13) Boot File Size
        Parameter Request List Item: (15) Domain Name
        Parameter Request List Item: (17) Root Path
        Parameter Request List Item: (18) Extensions Path
        Parameter Request List Item: (22) Maximum Datagram Reassembly Size
        Parameter Request List Item: (23) Default IP Time-to-Live
        Parameter Request List Item: (28) Broadcast Address
        Parameter Request List Item: (40) Network Information Service Domain
        Parameter Request List Item: (41) Network Information Service Servers
        Parameter Request List Item: (42) Network Time Protocol Servers
        Parameter Request List Item: (43) Vendor-Specific Information
        Parameter Request List Item: (50) Requested IP Address
        Parameter Request List Item: (51) IP Address Lease Time
        Parameter Request List Item: (54) DHCP Server Identifier
        Parameter Request List Item: (58) Renewal Time Value
        Parameter Request List Item: (59) Rebinding Time Value
        Parameter Request List Item: (60) Vendor class identifier
        Parameter Request List Item: (66) TFTP Server Name
        Parameter Request List Item: (67) Bootfile name
        Parameter Request List Item: (97) UUID/GUID-based Client Identifier
        Parameter Request List Item: (128) DOCSIS full security server IP [TODO]
        Parameter Request List Item: (129) PXE - undefined (vendor specific)
        Parameter Request List Item: (130) PXE - undefined (vendor specific)
        Parameter Request List Item: (131) PXE - undefined (vendor specific)
        Parameter Request List Item: (132) PXE - undefined (vendor specific)
        Parameter Request List Item: (133) PXE - undefined (vendor specific)
        Parameter Request List Item: (134) PXE - undefined (vendor specific)
        Parameter Request List Item: (135) PXE - undefined (vendor specific)
    Option: (97) UUID/GUID-based Client Identifier
        Length: 17
        Client Identifier (UUID): 00000000-0000-0000-0000-000000000000
    Option: (94) Client Network Device Interface
        Length: 3
        Major Version: 3
        Minor Version: 16
    Option: (93) Client System Architecture
        Length: 2
        Client System Architecture: EFI BC (7)
    Option: (60) Vendor class identifier
        Length: 32
        Vendor class identifier: PXEClient:Arch:00007:UNDI:003016
    Option: (255) End
        Option End: 255
        
33 Frame 34: 342 bytes on wire (2736 bits), 342 bytes captured (2736 bits) on interface 0
Ethernet II, Src: CadmusCo_cf:9f:11 (08:00:27:cf:9f:11), Dst: Broadcast (ff:ff:ff:ff:ff:ff)
Internet Protocol Version 4, Src: 10.0.100.3 (10.0.100.3), Dst: 255.255.255.255 (255.255.255.255)
User Datagram Protocol, Src Port: bootps (67), Dst Port: bootpc (68)
Bootstrap Protocol
    Message type: Boot Reply (2)
    Hardware type: Ethernet (0x01)
    Hardware address length: 6
    Hops: 0
    Transaction ID: 0xd46ff1a0
    Seconds elapsed: 0
    Bootp flags: 0x8000 (Broadcast)
        1... .... .... .... = Broadcast flag: Broadcast
        .000 0000 0000 0000 = Reserved flags: 0x0000
    Client IP address: 0.0.0.0 (0.0.0.0)
    Your (client) IP address: 10.0.100.99 (10.0.100.99)
    Next server IP address: 10.0.100.3 (10.0.100.3)
    Relay agent IP address: 0.0.0.0 (0.0.0.0)
    Client MAC address: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
    Client hardware address padding: 00000000000000000000
    Server host name not given
    Boot file name: efi64/syslinux.efi
    Magic cookie: DHCP
    Option: (53) DHCP Message Type
        Length: 1
        DHCP: ACK (5)
    Option: (54) DHCP Server Identifier
        Length: 4
        DHCP Server Identifier: 10.0.100.3 (10.0.100.3)
    Option: (51) IP Address Lease Time
        Length: 4
        IP Address Lease Time: (21600s) 6 hours
    Option: (1) Subnet Mask
        Length: 4
        Subnet Mask: 255.255.255.0 (255.255.255.0)
    Option: (3) Router
        Length: 4
        Router: 10.0.100.3 (10.0.100.3)
    Option: (6) Domain Name Server
        Length: 8
        Domain Name Server: 8.8.8.8 (8.8.8.8)
        Domain Name Server: 8.8.4.4 (8.8.4.4)
    Option: (255) End
        Option End: 255
    Padding
```
### Legacy BIOS Mode
```
Frame 1: 440 bytes on wire (3520 bits), 440 bytes captured (3520 bits) on interface 0
Ethernet II, Src: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93), Dst: Broadcast (ff:ff:ff:ff:ff:ff)
Internet Protocol Version 4, Src: 0.0.0.0 (0.0.0.0), Dst: 255.255.255.255 (255.255.255.255)
User Datagram Protocol, Src Port: bootpc (68), Dst Port: bootps (67)
Bootstrap Protocol
    Message type: Boot Request (1)
    Hardware type: Ethernet (0x01)
    Hardware address length: 6
    Hops: 0
    Transaction ID: 0xa046c403
    Seconds elapsed: 4
    Bootp flags: 0x0000 (Unicast)
        0... .... .... .... = Broadcast flag: Unicast
        .000 0000 0000 0000 = Reserved flags: 0x0000
    Client IP address: 0.0.0.0 (0.0.0.0)
    Your (client) IP address: 0.0.0.0 (0.0.0.0)
    Next server IP address: 0.0.0.0 (0.0.0.0)
    Relay agent IP address: 0.0.0.0 (0.0.0.0)
    Client MAC address: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
    Client hardware address padding: 00000000000000000000
    Server host name not given
    Boot file name not given
    Magic cookie: DHCP
    Option: (53) DHCP Message Type
        Length: 1
        DHCP: Discover (1)
    Option: (57) Maximum DHCP Message Size
        Length: 2
        Maximum DHCP Message Size: 1472
    Option: (93) Client System Architecture
        Length: 2
        Client System Architecture: IA x86 PC (0)
    Option: (94) Client Network Device Interface
        Length: 3
        Major Version: 2
        Minor Version: 1
    Option: (60) Vendor class identifier
        Length: 32
        Vendor class identifier: PXEClient:Arch:00000:UNDI:002001
    Option: (77) User Class Information
        Length: 4
        Instance of User Class: [0]
            User Class Length: 105
            [Expert Info (Error/Protocol): User Class Information: malformed option]
                [Message: User Class Information: malformed option]
                [Severity level: Error]
                [Group: Protocol]
    Option: (55) Parameter Request List
        Length: 21
        Parameter Request List Item: (1) Subnet Mask
        Parameter Request List Item: (3) Router
        Parameter Request List Item: (6) Domain Name Server
        Parameter Request List Item: (7) Log Server
        Parameter Request List Item: (12) Host Name
        Parameter Request List Item: (15) Domain Name
        Parameter Request List Item: (17) Root Path
        Parameter Request List Item: (43) Vendor-Specific Information
        Parameter Request List Item: (60) Vendor class identifier
        Parameter Request List Item: (66) TFTP Server Name
        Parameter Request List Item: (67) Bootfile name
        Parameter Request List Item: (128) DOCSIS full security server IP [TODO]
        Parameter Request List Item: (129) PXE - undefined (vendor specific)
        Parameter Request List Item: (130) PXE - undefined (vendor specific)
        Parameter Request List Item: (131) PXE - undefined (vendor specific)
        Parameter Request List Item: (132) PXE - undefined (vendor specific)
        Parameter Request List Item: (133) PXE - undefined (vendor specific)
        Parameter Request List Item: (134) PXE - undefined (vendor specific)
        Parameter Request List Item: (135) PXE - undefined (vendor specific)
        Parameter Request List Item: (175) Etherboot
        Parameter Request List Item: (203) Unassigned
    Option: (175) Etherboot
        Length: 48
        Value: b105018086100e180101220101190101210101100102eb03...
    Option: (61) Client identifier
        Length: 7
        Hardware type: Ethernet (0x01)
        Client MAC address: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
    Option: (97) UUID/GUID-based Client Identifier
        Length: 17
        Client Identifier (UUID): 00000000-0000-0000-0000-000000000000
    Option: (255) End
        Option End: 255

1 Frame 2: 342 bytes on wire (2736 bits), 342 bytes captured (2736 bits) on interface 0
Ethernet II, Src: CadmusCo_b3:f9:c0 (08:00:27:b3:f9:c0), Dst: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
Internet Protocol Version 4, Src: 10.0.100.3 (10.0.100.3), Dst: 10.0.100.99 (10.0.100.99)
User Datagram Protocol, Src Port: bootps (67), Dst Port: bootpc (68)
Bootstrap Protocol
    Message type: Boot Reply (2)
    Hardware type: Ethernet (0x01)
    Hardware address length: 6
    Hops: 0
    Transaction ID: 0xa046c403
    Seconds elapsed: 4
    Bootp flags: 0x0000 (Unicast)
        0... .... .... .... = Broadcast flag: Unicast
        .000 0000 0000 0000 = Reserved flags: 0x0000
    Client IP address: 0.0.0.0 (0.0.0.0)
    Your (client) IP address: 10.0.100.99 (10.0.100.99)
    Next server IP address: 10.0.100.3 (10.0.100.3)
    Relay agent IP address: 0.0.0.0 (0.0.0.0)
    Client MAC address: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
    Client hardware address padding: 00000000000000000000
    Server host name not given
    Boot file name: bios/pxelinux.0
    Magic cookie: DHCP
    Option: (53) DHCP Message Type
        Length: 1
        DHCP: Offer (2)
    Option: (54) DHCP Server Identifier
        Length: 4
        DHCP Server Identifier: 10.0.100.3 (10.0.100.3)
    Option: (51) IP Address Lease Time
        Length: 4
        IP Address Lease Time: (21600s) 6 hours
    Option: (1) Subnet Mask
        Length: 4
        Subnet Mask: 255.255.255.0 (255.255.255.0)
    Option: (3) Router
        Length: 4
        Router: 10.0.100.3 (10.0.100.3)
    Option: (6) Domain Name Server
        Length: 8
        Domain Name Server: 8.8.8.8 (8.8.8.8)
        Domain Name Server: 8.8.4.4 (8.8.4.4)
    Option: (255) End
        Option End: 255
    Padding

2 Frame 3: 440 bytes on wire (3520 bits), 440 bytes captured (3520 bits) on interface 0
Ethernet II, Src: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93), Dst: Broadcast (ff:ff:ff:ff:ff:ff)
Internet Protocol Version 4, Src: 0.0.0.0 (0.0.0.0), Dst: 255.255.255.255 (255.255.255.255)
User Datagram Protocol, Src Port: bootpc (68), Dst Port: bootps (67)
Bootstrap Protocol
    Message type: Boot Request (1)
    Hardware type: Ethernet (0x01)
    Hardware address length: 6
    Hops: 0
    Transaction ID: 0xa046c403
    Seconds elapsed: 8
    Bootp flags: 0x0000 (Unicast)
        0... .... .... .... = Broadcast flag: Unicast
        .000 0000 0000 0000 = Reserved flags: 0x0000
    Client IP address: 0.0.0.0 (0.0.0.0)
    Your (client) IP address: 0.0.0.0 (0.0.0.0)
    Next server IP address: 0.0.0.0 (0.0.0.0)
    Relay agent IP address: 0.0.0.0 (0.0.0.0)
    Client MAC address: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
    Client hardware address padding: 00000000000000000000
    Server host name not given
    Boot file name not given
    Magic cookie: DHCP
    Option: (53) DHCP Message Type
        Length: 1
        DHCP: Discover (1)
    Option: (57) Maximum DHCP Message Size
        Length: 2
        Maximum DHCP Message Size: 1472
    Option: (93) Client System Architecture
        Length: 2
        Client System Architecture: IA x86 PC (0)
    Option: (94) Client Network Device Interface
        Length: 3
        Major Version: 2
        Minor Version: 1
    Option: (60) Vendor class identifier
        Length: 32
        Vendor class identifier: PXEClient:Arch:00000:UNDI:002001
    Option: (77) User Class Information
        Length: 4
        Instance of User Class: [0]
            User Class Length: 105
            [Expert Info (Error/Protocol): User Class Information: malformed option]
                [Message: User Class Information: malformed option]
                [Severity level: Error]
                [Group: Protocol]
    Option: (55) Parameter Request List
        Length: 21
        Parameter Request List Item: (1) Subnet Mask
        Parameter Request List Item: (3) Router
        Parameter Request List Item: (6) Domain Name Server
        Parameter Request List Item: (7) Log Server
        Parameter Request List Item: (12) Host Name
        Parameter Request List Item: (15) Domain Name
        Parameter Request List Item: (17) Root Path
        Parameter Request List Item: (43) Vendor-Specific Information
        Parameter Request List Item: (60) Vendor class identifier
        Parameter Request List Item: (66) TFTP Server Name
        Parameter Request List Item: (67) Bootfile name
        Parameter Request List Item: (128) DOCSIS full security server IP [TODO]
        Parameter Request List Item: (129) PXE - undefined (vendor specific)
        Parameter Request List Item: (130) PXE - undefined (vendor specific)
        Parameter Request List Item: (131) PXE - undefined (vendor specific)
        Parameter Request List Item: (132) PXE - undefined (vendor specific)
        Parameter Request List Item: (133) PXE - undefined (vendor specific)
        Parameter Request List Item: (134) PXE - undefined (vendor specific)
        Parameter Request List Item: (135) PXE - undefined (vendor specific)
        Parameter Request List Item: (175) Etherboot
        Parameter Request List Item: (203) Unassigned
    Option: (175) Etherboot
        Length: 48
        Value: b105018086100e180101220101190101210101100102eb03...
    Option: (61) Client identifier
        Length: 7
        Hardware type: Ethernet (0x01)
        Client MAC address: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
    Option: (97) UUID/GUID-based Client Identifier
        Length: 17
        Client Identifier (UUID): 00000000-0000-0000-0000-000000000000
    Option: (255) End
        Option End: 255

Frame 4: 342 bytes on wire (2736 bits), 342 bytes captured (2736 bits) on interface 0
Ethernet II, Src: CadmusCo_b3:f9:c0 (08:00:27:b3:f9:c0), Dst: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
Internet Protocol Version 4, Src: 10.0.100.3 (10.0.100.3), Dst: 10.0.100.99 (10.0.100.99)
User Datagram Protocol, Src Port: bootps (67), Dst Port: bootpc (68)
Bootstrap Protocol
    Message type: Boot Reply (2)
    Hardware type: Ethernet (0x01)
    Hardware address length: 6
    Hops: 0
    Transaction ID: 0xa046c403
    Seconds elapsed: 8
    Bootp flags: 0x0000 (Unicast)
        0... .... .... .... = Broadcast flag: Unicast
        .000 0000 0000 0000 = Reserved flags: 0x0000
    Client IP address: 0.0.0.0 (0.0.0.0)
    Your (client) IP address: 10.0.100.99 (10.0.100.99)
    Next server IP address: 10.0.100.3 (10.0.100.3)
    Relay agent IP address: 0.0.0.0 (0.0.0.0)
    Client MAC address: fa:16:3e:28:5d:93 (fa:16:3e:28:5d:93)
    Client hardware address padding: 00000000000000000000
    Server host name not given
    Boot file name: bios/pxelinux.0
    Magic cookie: DHCP
    Option: (53) DHCP Message Type
        Length: 1
        DHCP: Offer (2)
    Option: (54) DHCP Server Identifier
        Length: 4
        DHCP Server Identifier: 10.0.100.3 (10.0.100.3)
    Option: (51) IP Address Lease Time
        Length: 4
        IP Address Lease Time: (21600s) 6 hours
    Option: (1) Subnet Mask
        Length: 4
        Subnet Mask: 255.255.255.0 (255.255.255.0)
    Option: (3) Router
        Length: 4
        Router: 10.0.100.3 (10.0.100.3)
    Option: (6) Domain Name Server
        Length: 8
        Domain Name Server: 8.8.8.8 (8.8.8.8)
        Domain Name Server: 8.8.4.4 (8.8.4.4)
    Option: (255) End
        Option End: 255
    Padding
```

As intended, the Boot file name is `efi64/syslinux.efi` when the value of
Option (93) is `EFI BC (7)`, and `bios/pxelinux.0` when `IA x86 PC (0)`

## Tearing down the test setup
Since the host's network configuration has been messed with, the proper settings
should be restored. This can be accomplished fairly easily with:
```
$ sudo ifdown br0 && sudo ifdown eth1 && sudo ifup eth1
```
