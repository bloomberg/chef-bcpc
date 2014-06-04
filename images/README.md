# BCPC Image Builds

BCPC utilizes [Packer](http://packer.io) for building boxes to be used by VirtualBox.  These boxes
are used to provide machine images similar to that of a PXE-booted bare metal machine.

## Installing Packer

http://www.packer.io/docs/installation.html


## Build Your Own Boxes

First, install [Packer](http://packer.io) and then clone this project.

Inside the `images/packer` directory, a JSON file describes each box that can be built.  You can use
`packer build` to build the boxes.

    $ packer build bcpc-bootstrap.json

Congratluations!  You now have box(es) in the ../build directory that you can import into
VirtualBox and start deploying your own Bloomberg Clustered Private Cloud.

## Import Your Built Box

Inside the `images` directory, you can use `VBoxManage import` the built box.

    $ VBoxManage import build/virtualbox/bcpc-bootstrap/packer-bcpc-bootstrap_ubuntu-12.04-amd64.ova --vsys 0 --vmname bcpc-bootstrap

Alternatively within the VirtualBox Manager, you can import the machine via `File > Import Appliance...`


## Known Issues

* https://bugs.launchpad.net/ubuntu/+source/debian-installer/+bug/568704

    When setting mirror/http/proxy on the command line, it prevents the preseed.cfg being fetched
    due to the http_proxy environment variable set.
