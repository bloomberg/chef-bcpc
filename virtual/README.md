# Virtual

The virtual directory contains everything needed in order to build a virtual
cluster using either VirtualBox or libvirt. A single *network-vm* may be used
instead of the full leaf-spine architecture described [here](network/README.md)
by specifying the environmental variable `BCC_DEPLOY_NETWORK_VM=true`.
Instructions on how how build a virtual cluster can be found
[here](../README.md).

## Directories

- bin: Various scripts used during the creation and tearing down of the
    specified virtual environment.
- network: See the [README](network/README.md).
- topology: Defines the hardware configuration and topology of the virtual
    environment to be created.

## Tested Configurations

The Bloomberg chef-bcpc team periodically tests various cluster configurations
as part of their internal CI/CD process. The following table details those
configurations, as well as certain details regarding the tests. Note, however,
that these tests are **not** performed on a pure chef-bcpc cluster but instead
on a cluster comprised of a combination of chef-bcpc and various closed-source
components internal to Bloomberg, so your millage may vary.

| Topology | Hardware Configuration | Network VM | Branch | Frequency |
|---|---|---|---|---|
| [1h1w](topology/1h1w.yml) | [hardware](topology/hardware.yml) | Yes | development | daily |
| [3h3w](topology/3h3w.yml) | [hardware](topology/hardware.yml) | Yes | development | daily |
| [3h3w3r](topology/3h3w3r.yml) | [hardware](topology/hardware.yml) | Yes | development | weekly |
| [3h3w3r](topology/3h3w3r.yml) | [hardware](topology/hardware.yml) | Yes | master | weekly |

Periodic testing of the pure chef-bcpc component is planned. And as always,
contributions from the community are also very welcome.
