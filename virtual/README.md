# Virtual

The virtual directory contains everything needed in order to build a virtual
cluster using either VirtualBox or libvirt. A single *network-vm* may be used
instead of the full leaf-spine architecture described [here](network/README.md)
by specifying the environmental variable `BCC_DEPLOY_NETWORK_VM=true`.
Additional information can be found [here](../README.md).

A short description of important directories and files can be found below.

- bin: Various scripts used during the creation and tearing down of the
    specified virtual environment.
- network: See the [README](network/README.md).
- topology: Defines the hardware configuration and topology of the virtual
    environment to be created.
