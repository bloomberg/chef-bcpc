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
* VirtualBox 5.2+
* git, curl, rsync, ssh, jq, make, ansible

**NOTE**: It is likely possible to build an environment with 16GB of RAM or less
if one is willing to make slight modifications to the
 [virtual topology](virtual/topology/hardware.yml) and/or change some of the
build settings and overrides.  However, we've opted to spec the minimum
requirements slightly more aggressively and target hosts with 32GB RAM or more
to provide the best out-of-the-box experience.


### Local Build

* Review `virtual/topology/topology.yml` for the topology you will build and
make changes as required, e.g. assign more or less RAM based on your topology
and your build environment. Other topologies exist in the same directory.
* To make changes to the virtual topology without dirtying the tree, copy the
[hardware.yml](virtual/topology/hardware.yml) and
[topology.yml](virtual/topology/topology.yml) to files named
`hardware.overrides.yml` and `topology.overrides.yml`, respectively, and make
changes to them instead.
* If a proxy server is required for internet access, set the variables TBD
* If additional CA certificates are required (e.g. for a proxy), set the variables TBD
* From the root of the chef-bcpc git repository run the following command:

Create a Python virtual environment (virtualenv) and activate it

```shell
python3 -mvenv venv
source venv/bin/activate
pip install PyYaml ansible netaddr pyOpenSSL pycryptodome
```

To create a virtualbox build (the default):

```shell
make generate-chef-databags
make create all
```

To create a libvirt build:

```shell
sudo apt-get install build-essential libvirt-dev qemu-utils
vagrant plugin install vagrant-libvirt vagrant-mutate
vagrant box add bento/ubuntu-18.04 --box-version 202005.21.0 --provider virtualbox
vagrant mutate bento/ubuntu-18.04 libvirt
export VAGRANT_DEFAULT_PROVIDER=libvirt VAGRANT_VAGRANTFILE=Vagrantfile.libvirt
make generate-chef-databags
make create all
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

To revert to the default virtualbox provider, you can just remove the
mutated libvirt box and then unset VAGRANT_DEFAULT_PROVIDER and
VAGRANT_VAGRANTFILE environment variables, however since you must also
make sure that the different hypervisors don't both try to control the
CPU virtualisation facilities, it is best to remove the mutated box
and then simply reboot your development host.

This would look something ike this:

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
 - [Percona XtraDB Cluster](http://www.percona.com/software/percona-xtradb-cluster)
 - [PowerDNS](https://www.powerdns.com/)
 - [RabbitMQ](http://www.rabbitmq.com/)
 - [Ubuntu](http://www.ubuntu.com/)
 - [Unbound](https://nlnetlabs.nl/projects/unbound/about/)
 - [Vagrant](http://www.vagrantup.com/)
 - [VirtualBox](https://www.virtualbox.org/)

Thanks to all of these communities for producing this software!
