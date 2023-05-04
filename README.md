# chef-bcpc

chef-bcpc is a set of [Chef](https://www.chef.io/) cookbooks
and [Ansible](https://www.ansible.com/) playbooks that build a
highly-available [OpenStack](http://www.openstack.org/) cloud.

The cloud consists of a variety of head nodes (OpenStack controller
services, Ceph Mons/Mgrs, etcd, RabbitMQ), work nodes (hypervisors)
and storage nodes (Ceph OSDs).

Each type of head node runs its core services in a highly-available
manner and the roles of these nodes can be converged into a smaller set
of hosts. In addition, the roles of work nodes and storage nodes can
also be converged together.


## Getting Started

The following instructions will get chef-bcpc up and running on your local
machine for development and testing purposes.


### Prerequisites

* OS X or Linux
* Quad-core CPU that supports VT-x or AMD-V virtualization extensions
* 32 GB of memory
* 128 GB of free disk space
* Vagrant 2.1+
* VirtualBox 5.2+ *or* KVM + libvirtd
* Packer 1.4+
* git, curl, rsync, ssh, jq, make, ansible

**NOTE**: It is likely possible to build an environment with 16GB of RAM or less
if one is willing to make slight modifications to the
 [virtual topology](virtual/topology/hardware.yml) and/or change some of the
build settings and overrides. However, we've opted to spec the minimum
requirements slightly more aggressively and target hosts with 32GB RAM or more
to provide the best out-of-the-box experience.


### Local Build

* Choose the topology and hardware configuration of your cluster. You can
choose from existing configurations in `virtual/topology`, or build your own.
[hardware.yml](virtual/topology/hardware.yml) and
[topology.yml](virtual/topology/topology.yml) are used by default. To view a
list of tested topologies and hardware configurations please see
[virtual/README](virtual/README.md).
* Set the variables in `virtual/vagrantbox.json`. The variable `vagrant_box` specifies the
Vagrant box we use to build the virtual environment, and `vagrant_box_version` specifies
the version of the Vagrant box. These variables are specified per Ansible inventory group
of hosts, and must have a "default" group as is done in the default `vagrantbox.json`.
* If one would like to build a pre-provisioned custom Packer box and use it as the base box
to create the virtual environment, the steps below should be followed:
  * Create `virtual/packer/config/variables.json` and set the variables. Depends on the
virtual machine provider, an example can be found at
[variables.json.libvirt.example](virtual/packer/config/variables.json.libvirt.example)
or [variables.json.virtualbox.example](virtual/packer/config/variables.json.virtualbox.example).
This step is essential for building a Packer box that's used as a base box image for building
the virtual environment. The variables `bcc_apt_key_url`, `bcc_apt_url` and `vagrant_cacert` are optional,
while others must be set. The variable `kernel_version` specifies the Linux kernel version we'd
like to have for the Packer box. While `base_box`, `base_box_version`, and `base_box_provider`
specify an official Vagrant box we'd like to use as a baseline for the Packer box, upon which
we make further modifications. Last but not least, the variable `output_packer_box_name` specifies
the name we'd like to use when adding the output Packer box to Vagrant.
  * Alternatively, if one has S3 set up and would like to download/upload a packer box, `virtual/packer/config/s3.json`
can be set up to leverage a pre-built packer box. An example can be found at
[s3.json.libvirt.example](virtual/packer/config/s3.json.libvirt.example)
or [s3.json.virtualbox.example](virtual/packer/config/s3.json.virtualbox.example). Run make target `make download-packer-box`
and `make upload-packer-box` to download/upload a packer box.
  * Run make target `make create-packer-box`. This will create a Packer box and add it to Vagrant
with the name specified by `output_packer_box_name`.
  * Set the variables in `virtual/vagrantbox.json` accordingly. When a local custom box built by Packer
is used, the variable `vagrant_box` needs to be set to the name of the Packer box (aka, the same as
`output_packer_box_name` in `virtual/packer/config/variables.json`), and `vagrant_box_version` should be set to 0.
  * After these steps, `make create all` would always use the Packer box, unless `virtual/vagrantbox.json`
is specified otherwise.
  * If the Packer box needs to be updated, we recommend first clean up the old Packer box. To clean up a
Packer box, one must first make sure there's no VM using the Packer box by running `make destroy`, and then
run `make destroy-packer-box` to clean up the Packer box.
* To make changes to the virtual topology without dirtying the tree, copy the
[hardware.yml](virtual/topology/hardware.yml) and
[topology.yml](virtual/topology/topology.yml) to files named
`hardware.overrides.yml` and `topology.overrides.yml`, respectively, and make
changes to them instead.
* If a proxy server is required for internet access, set the variables
`bcc_http_proxy_url` and `bcc_https_proxy_url` respectively in
`virtual/packer/config/variables.json`.
* If additional CA certificates are required (e.g. for a proxy), set the variables TBD
* From the root of the chef-bcpc git repository run the following command:

Download and install the latest version of Packer

```shell
wget https://releases.hashicorp.com/packer/1.6.6/packer_1.6.6_linux_amd64.zip -O ~/packer_1.6.6_linux.zip
sudo apt install unzip
sudo unzip ~/packer_1.6.6_linux.zip -d /usr/local/bin
```


Create a Python virtual environment (virtualenv) and activate it

```shell
python3 -mvenv venv
source venv/bin/activate
pip install 'pip>=19.1.1' wheel
pip install PyYaml ansible netaddr pyOpenSSL 'cryptography>=3.0,<38.0.0'
```

To create a libvirt build (the default), first install the following packages
and plugins:

```shell
sudo apt-get install build-essential dnsmasq libguestfs-tools libvirt-dev pkg-config qemu-utils
vagrant plugin install vagrant-libvirt vagrant-mutate
```

Alternatively, to create a VirtualBox build, install the following plugin and
set the following environment variables:

```shell
vagrant plugin install vagrant-vbguest
export VAGRANT_DEFAULT_PROVIDER=virtualbox
export VAGRANT_VAGRANTFILE=Vagrantfile.virtualbox
```

Use the following commands to create a virtual build:

```shell
make generate-chef-databags
make create-packer-box
make create all
```

To clean up the build:
```shell
make destroy
make destroy-packer-box
```


You may also want to change CPU model from `qemu64` to `kvm64` in
`ansible/playbooks/roles/common/defaults/main/chef.yml`

```
chef_environment:
  name: virtual
  override_attributes:
    bcpc:
       nova:
         cpu_config:
           cpu_mode: custom
           cpu_model: kvm64
```

To switch from the default libvirt provider to the virtualbox provider, as
far as the build is concerned, you can just remove the mutated libvirt
box and then set VAGRANT_DEFAULT_PROVIDER and VAGRANT_VAGRANTFILE
environment variables as described above. However since you must also
make sure that the different hypervisors don't both try to control the
CPU virtualization facilities, it is best to remove the mutated box and
then simply reboot your development host.

This would look something like this:

```shell
$ rm -rf ~/.vagrant.d/boxes/bento-VAGRANTSLASH-ubuntu-20.04/202206.03.0/libvirt/
$ rm -rf ~/.vagrant.d/boxes/bento-VAGRANTSLASH-ubuntu-22.04/202206.13.0/libvirt/
$ sudo reboot
```

## Hardware Deployment

TBD


## Contributing

Currently, most development is done by a team at Bloomberg L.P. but we would
like to build a community around this project. PRs and issues are welcomed. If
you are interested in joining the team at Bloomberg L.P. please see available
opportunities at the [Bloomberg L.P. careers site](https://careers.bloomberg.com/job/search?qf=cloud).


## License

This project is licensed under the Apache 2.0 License - see the
[LICENSE](LICENSE) file for details.


## Built With

chef-bcpc is built with the following open source software:

 - [Ansible](https://www.ansible.com/)
 - [Apache HTTP Server](http://httpd.apache.org/)
 - [BIRD](https://bird.network.cz)
 - [Calico](https://www.projectcalico.org)
 - [Ceph](http://ceph.com/)
 - [Chef Infra Server](https://www.chef.io/)
 - [Cinc Client](https://cinc.sh/)
 - [Consul](https://www.consul.io)
 - [etcd](https://etcd.io)
 - [HAProxy](http://haproxy.1wt.eu/)
 - [Memcached](http://memcached.org)
 - [OpenStack](http://www.openstack.org/)
 - [Packer](https://www.packer.io/)
 - [Percona XtraDB Cluster](http://www.percona.com/software/percona-xtradb-cluster)
 - [PowerDNS](https://www.powerdns.com/)
 - [RabbitMQ](http://www.rabbitmq.com/)
 - [Ubuntu](http://www.ubuntu.com/)
 - [Unbound](https://nlnetlabs.nl/projects/unbound/about/)
 - [Vagrant](http://www.vagrantup.com/)
 - [VirtualBox](https://www.virtualbox.org/)

Thanks to all of these communities for producing this software!
