Using Windows as your Hypervisor
================================

You can use a suitable Windows box as the hypervisor for your BCPC
cluster. As with other hypervisors the hardware spec should include at
least 16GB and a CPU with virtualisation support (Intel VT-X or
AMD-V). You must ensure that the virtualisation is also enabled in the
BIOS. An SSD is recommended for the filesystem hosting the VMs as bringing 
up a full cluster involves a lot of I/O.

To run the initial scripts which create the VMs, you need a working
bash interpreter and some other standard unix tools must be available
in your path. At a minimum this includes:

- VirtualBox
- bash
- python
- curl
- rsync
- (optional) Vagrant

An easy enough way to put this all together is to install cygwin for
the basic unix command-line tools, Python for Windows and MSYS-GIT for
a nice bash shell, and then include the paths to all of these in your PATH. 
A sample ~/.bash_profile to tie this all together
looks like this:

```
#!/bin/bash
export PATH=$PATH:/c/cygwin/bin
export PATH=$PATH:/c/Python26
export PATH=$PATH:/c/Program\ Files/Oracle/VirtualBox
```

chef-bcpc has been tested on Windows 7 64-bit using VirtualBox 4.2.12, Python 2.6, 
MSysGit 1.8.0, Cygwin 1.7, rsync 3.0.9

Many other combinations will most likely work - most of a chef-bcpc bringup process 
runs inside the VMs and is unaffected by hypervisor setup. The parts that creat and 
initialise the VMs and download some supporting files are nothing unusual or difficult.
