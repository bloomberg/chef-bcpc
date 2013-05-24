Overview
========

This is a set of [Chef](https://github.com/opscode/chef) cookbooks to bring up
an instance of an [OpenStack](http://www.openstack.org/)-based cluster of head
and worker nodes.  In addition to hosting virtual machines, there are a number
of additional services provided with these cookbooks - such as distributed
storage, DNS, log aggregation/search, and monitoring - see below for a partial
list of services provided by these cookbooks.

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
 - ``eth0`` - management traffic (host-only NIC in VM)
 - ``eth1`` - storage traffic (host-only NIC in VM)
 - ``eth2`` - VM traffic (host-only NIC in VM)

You should look at the various settings in ``cookbooks/bcpc/attributes/default.rb``
and tweak accordingly for your setup (by adding them to an environment file).

Cluster Bootstrap
-----------------

Please refer to the [BCPC Bootstrap Guide](https://github.com/bloomberg/chef-bcpc/blob/master/bootstrap.md)
for more information about getting a BCPC cluster bootstrapped.

There are provided scripts which set up a Chef and Cobbler server via
[Vagrant](http://www.vagrantup.com/) or on bare metal that permit imaging of
the cluster via PXE.

Once the Chef server is set up, you can bootstrap any number of nodes to get
them registered with the chef server for your environment - see the next
section for enrolling the nodes.

Make a cluster
--------------

To build a new BCPC cluster, you have to start with building a single head node
first. (This assumes that you have already completed the bootstrap process and
have a Chef server available.)  Since the recipes will automatically generate
all passwords and keys for this new cluster, enable the target node as an
``admin`` in the chef server so that the recipes can write the generated info
to a databag.  The databag will be called ``configs`` and the databag item will
be the same name as the environment (``Test-Laptop`` in this example). You only
need to leave the node as an ``admin`` for the first chef-client run. You can
also manually create the databag & item (as per the example in
``data_bags/configs/Example.json``) and manually upload it if you'd rather not
bother with the whole ``admin`` thing for the first run.

So add this first node as the role ``BCPC-Headnode`` and run ``chef-client``
on the target node. After the first one is up, you can add another head
node with:

```
 $ knife bootstrap -E Test-Laptop -r "role[BCPC-Headnode]" -x ubuntu --sudo <IPAddress>
```

If you get an error saying ``403 "Forbidden"`` on the initial run, you 
probably forgot to make the initial headnode client an admin user:

```
10.0.100.11 [2013-05-18T13:23:11-04:00] FATAL: Net::HTTPServerException: ruby_block[initialize-ssh-keys] (bcpc::networking line 22) had an error: Net::HTTPServerException: 403 "Forbidden"
```

To enroll a server as a worker node:

```
 $ knife bootstrap -E Test-Laptop -r "role[BCPC-Worknode]" -x ubuntu --sudo <IPAddress>
```

Using a cluster
---------------

Once the nodes are configured and bootstrapped, BCPC services will be
accessible via the floating IP.  (For the Test-Laptop environment, it is
10.0.100.5.)

For example, you can go to ``https://10.0.100.5/horizon/`` for the OpenStack
web interface.  To find the automatically-generated OpenStack credentials, look
in the data bag for your environment under ``keystone-admin-user`` and
``keystone-admin-password``:

```
ubuntu@bcpc-bootstrap:~$ knife data bag show configs Test-Laptop | grep keystone-admin
keystone-admin-password:       abcdefgh
keystone-admin-token:          this-is-my-token
keystone-admin-user:           admin

```

For example, to check on ``Ceph``:

```
ubuntu@bcpc-vm1:~$ ceph -s
   health HEALTH_OK
   monmap e1: 1 mons at {bcpc-vm1=172.16.100.11:6789/0}, election epoch 2, quorum 0 bcpc-vm1
   osdmap e94: 12 osds: 12 up, 12 in
    pgmap v705: 2192 pgs: 2192 active+clean; 80333 KB data, 729 MB used, 227 GB / 227 GB avail
   mdsmap e4: 1/1/1 up {0=bcpc-vm1=up:active}
```

BCPC Services
-------------

BCPC currently relies upon a number of open-source packages:

 - [Apache HTTP Server](http://httpd.apache.org/)
 - [Beaver](https://github.com/josegonzalez/beaver)
 - [Ceph](http://ceph.com/)
 - [Chef](http://www.opscode.com/chef/)
 - [Cobbler](http://www.cobblerd.org/)
 - [Diamond](https://github.com/BrightcoveOS/Diamond)
 - [ElasticSearch](http://www.elasticsearch.org/)
 - [Etherboot](http://etherboot.org/)
 - [Graphite](http://graphite.readthedocs.org/en/latest/)
 - [HAProxy](http://haproxy.1wt.eu/)
 - [Keepalived](http://www.keepalived.org/)
 - [Kibana](http://kibana.org/)
 - [Logstash](http://logstash.net/)
 - [OpenStack](http://www.openstack.org/)
 - [Percona XtraDB Cluster](http://www.percona.com/software/percona-xtradb-cluster)
 - [PowerDNS](https://www.powerdns.com/)
 - [RabbitMQ](http://www.rabbitmq.com/)
 - [Ubuntu](http://www.ubuntu.com/)
 - [Vagrant](http://www.vagrantup.com/) - Verified with version 1.2.2
 - [VirtualBox](https://www.virtualbox.org/) - Verified with version 4.2.12

Thanks to all of these communities for producing this software!
