Overview
========

This is a set of [Chef](https://github.com/opscode/chef) cookbooks to bring up
an instance of an [OpenStack](http://www.openstack.org/)-based cluster of head
and worker nodes.

Each head node runs all of the core services in a highly-available manner with
no restriction upon how many head nodes there are.  The cluster is deemed
operational as long as 50%+1 of the head nodes are online.  Otherwise, a
network partition may occur with a split-brain scenario.  In practice,
we currently recommend roughly one head node per rack.

Each worker node runs the relevant services (nova-compute, Ceph OSDs, etc.).
There is no limitation on the number of worker nodes.  In practice, we
currently recommend that the cluster should not grow to more than 200 worker
nodes.

Setup
=====

These recipes are currently intended for building a BCPC cloud on top of
Ubuntu 12.04 servers using Chef 10. When setting this up in VMs, be sure to
add a few dedicated disks (for ceph OSDs) aside from boot volume. In
addition, it's expected that you have three separate NICs per machine, with
the following as defaults (and recommendations for VM settings):
 - ``eth0`` - management traffic (bridged NIC in VM)
 - ``eth1`` - storage traffic (host-only NIC in VM)
 - ``eth2`` - VM traffic (NAT NIC in VM)

You should look at the various settings in ``cookbooks/bcpc/attributes/default.rb``
and tweak accordingly for your setup (by adding them to an environment file).

Step 1 - One-time setup
----------------------

Make sure that you have `rubygems` and `chef` installed. Currently this only works on `chef@10.18` which requires some massaging to install due to a newer version of `net-ssh`.

```
 $ [sudo] gem install net-ssh -v 2.2.2 --no-ri --no-rdoc
 $ [sudo] gem install net-ssh-gateway -v 1.1.0 --no-ri --no-rdoc --ignore-dependencies
 $ [sudo] gem install net-ssh-multi -v 1.1.0 --no-ri --no-rdoc --ignore-dependencies
 $ [sudo] gem install chef --no-ri --no-rdoc -v 10.18
```

These cookbooks assume that you already have the following cookbooks
available:
 - apt
 - ubuntu
 - cron
 - chef-client

You can install these cookbooks via:

```
 $ cd cookbooks/
 $ knife cookbook site download apt  
 $ knife cookbook site download ubuntu  
 $ knife cookbook site download cron
 $ knife cookbook site download chef-client  
```

This will download the cookbooks locally. You need to untar them into `/cookbooks`:

```
 $ tar -zxvf apt*.tar.gz
 $ tar -zxvf ubuntu*.tar.gz
 $ tar -zxvf cron*.tar.gz
 $ tar -zxvf chef-client*.tar.gz
 $ rm apt*.tar.gz ubuntu*.tar.gz rm cron*.tar.gz chef-client*.tar.gz
 $ cd ../
```

You also need to build the installer bins for a number of external
dependencies, and there's a script to help (tested on Ubuntu 12.04)

```
 $ ./cookbooks/bcpc/files/default/build_bins.sh
```

If you're planning to run OpenStack on top of VirtualBox, be sure to build the base VirtualBox images first:

```
 $ cd path/to/chef-bcpc
 $ ./vbox_create.sh
```

Step 2 - Prep the servers
----------------------

After you've set up your own environment file, get everything up to your
chef server:

```
 $ knife environment from file environments/*.json  
 $ knife role from file roles/*.json  
 $ knife cookbook upload -a
```

Now you can bootstrap any number of nodes to get them registered with the
chef server for your environment (with ``Test-Laptop`` used as the env):

```
 $ knife bootstrap -E Test-Laptop <IPAddress>
```

Step 3 - Make a cluster
----------------------

To build a new cluster, you have to start with building a single
head node first. Since the recipes will automatically generate all passwords
and keys for this new cluster, enable the target node as an ``admin`` in the
chef server so that the recipes can write the generated info to a databag.
The databag will be called ``configs`` and the databag item will be the same
name as the environment (``Test-Laptop`` in this example). You only need to
leave the node as an ``admin`` for the first chef-client run. You can also
manually create the databag & item (as per the example in
``data_bags/configs/Example.json``) and manually upload it if you'd rather
not bother with the whole ``admin`` thing for the first run.

So add this first node as the role ``BCPC-Headnode`` and run ``chef-client``
on the target node. After the first one is up, you can add another head
node with:

```
 $ knife bootstrap -E Test-Laptop -r "role[BCPC-Headnode]" <IPAddress>
```

Or enroll a server as a worker node:

```
 $ knife bootstrap -E Test-Laptop -r "role[BCPC-Worknode]" <IPAddress>
```
