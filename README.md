# chef-bcpc

chef-bcpc is a set of [Chef](https://github.com/opscode/chef) cookbooks that
build a highly-available [OpenStack](http://www.openstack.org/) cloud.

The cloud consists of head nodes (OpenStack controller services, Ceph Mons,
etc.) and work nodes (hypervisors).

Each head node runs all of the core services in a highly-available manner. Each
work node runs the relevant services (nova-compute, Ceph OSDs, etc.).


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
build settings and overrides.  However, we've opted to spec the minimum
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
the version of the Vagrant box.
* If one would like to build a pre-provisioned custom Packer box and use it as the base box
to create the virtual environment, the steps below should be followed:
  * Create `virtual/packer/variables.json` and set the variables. Depends on the
virtual machine provider, an example can be found at
[variables.json.virtualbox.example](virtual/packer/variables.json.virtualbox.example)
or [variables.json.libvirt.example](virtual/packer/variables.json.libvirt.example).
This step is essential for building a Packer box that's used as a base box image for building
the virtual environment. The variables `bcc_apt_key_url` and `bcc_apt_url` are optional,
while others must be set. The variable `kernel_version` specifies the linux kernel version we'd
like to have for the Packer box. While `base_box`, `base_box_version`, and `base_box_provider`
specify an official Vagrant box we'd like to use as a baseline for the Packer box, upon which
we make further modifications. Last but not least, the variable `output_packer_box_name` specifies
the name we'd like to use when adding the output Packer box to Vagrant.
  * Run make target `make create-packer-box`. This will create a Packer box and add it to Vagrant
with the name specified by `output_packer_box_name`.
  * Set the variables in `virtual/vagrantbox.json` accordingly. When a local custom box built by Packer
is used, the variable `vagrant_box` needs to be set to the name of the Packer box (aka, the same as
`output_packer_box_name` in `virtual/packer/variables.json`), and `vagrant_box_version` should be set to 0.
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
* If a proxy server is required for internet access, set the variables TBD
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
pip install PyYaml ansible netaddr pyOpenSSL pycryptodome
```

To create a virtualbox build (the default):

```shell
make generate-chef-databags
make create-packer-box
make create all
```

To create a libvirt build:

```shell
sudo apt-get install build-essential libvirt-dev qemu-utils libguestfs-tools
vagrant plugin install vagrant-libvirt vagrant-mutate
vagrant box add bento/ubuntu-18.04 --box-version 202005.21.0 --provider virtualbox
vagrant mutate bento/ubuntu-18.04 libvirt
export VAGRANT_DEFAULT_PROVIDER=libvirt VAGRANT_VAGRANTFILE=Vagrantfile.libvirt
make generate-chef-databags
make create-packer-box
make create all
```

To clean up the build:
```shell
make destroy
make destroy-packer-box
```


You may also want to change cpu model from `qemu64` to `kvm64` in
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

To revert to the default virtualbox provider, as far as the build is
concerned, you can just remove the mutated libvirt box and then unset
VAGRANT_DEFAULT_PROVIDER and VAGRANT_VAGRANTFILE environment
variables. However since you must also make sure that the different
hypervisors don't both try to control the CPU virtualisation
facilities, it is best to remove the mutated box and then simply
reboot your development host (assuming no scripts reset the VAGRANT
variables).

This would look something like this:

```shell
$ rm -rf ~/.vagrant.d/boxes/bento-VAGRANTSLASH-ubuntu-18.04/202005.21.0/libvirt/
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
[LICENSE.txt](LICENSE.txt) file for details.


## Built With

chef-bcpc is built with the following open source software:

 - [Ansible](https://www.ansible.com/)
 - [Apache HTTP Server](http://httpd.apache.org/)
 - [BIRD](https://bird.network.cz)
 - [Calico](https://www.projectcalico.org)
 - [Ceph](http://ceph.com/)
 - [Chef](http://www.opscode.com/chef/)
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
