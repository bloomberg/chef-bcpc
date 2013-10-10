### Updating Information for BCPC clusters

These instructions assume that you basically know what you are doing.  =)

### 20131003

Keystone is now serviced over HTTPS on port 5000.  In particular, a new subjectAltName
field containing the VIP IP address was added to the SSL certificate.

On all headnodes:

```
# service nova-api stop
# service keystone stop
# service apache2 stop
```

On one headnode:
```
# . /root/keystonerc
# keystone service-delete keystone
```

Remove the ``ssl-certificate`` and ``ssl-private-key`` fields from the databag - eg:

```
# EDITOR=vi knife data bag edit configs Test-Laptop
```

Then, you can run ``chef-client`` to regenerate and redeploy the new certs.

### 20131002
To upgrade Power DNS to <vm name>.<tenant name>.<region name>.<domain name>:
Warning: only '&', '_' and <space> are translated for project names to domain names.

Easiest, unless you put custom information in:
* ``pdns.records_static``
* ``pdns.domains``
* The entire ``pdns`` database

Simply run ``DROP DATABASE pdns`` and re-run chef-client.

If you have custom DNS data in your pdns database, you can roughly do the following:

* Migrate MySQL tables and DB to use UTF8 instead of Sweedish collation in the pdns DB:
```
ALTER DATABASE pdns DEFAULT COLLATE utf8_general_ci;
ALTER TABLE records_static CHARACTER SET utf8 COLLATE utf8_general_ci;
ALTER TABLE records_static CONVERT TO CHARACTER SET utf8 COLLATE utf8_general_ci;
ALTER TABLE domains CHARACTER SET utf8 COLLATE utf8_general_ci;
ALTER TABLE domains CONVERT TO CHARACTER SET utf8 COLLATE utf8_general_ci;
ALTER TABLE domains RENAME TO domains_static;
DROP VIEW records;
```

Then re-run chef-client to get the new required MySQL views and function.

#### 20130928

On Ubuntu nodes, network interfaces are now templated rather than hard-coded
upon first-run.  Delete the relevant entries from /etc/network/interfaces and
it will be replaced by the templated files in /etc/network/interfaces.d/

Beaver (on all head/worker nodes) and logstash (head nodes only) has been
replaced by fluentd.  You can safely remove those packages now.

#### 20130824

Automatic boot-from-volumes patches in Grizzly is added back in to the tree.
You must upload RAW images again.  For example, to convert the public
Ubuntu 12.04 QCOW2 image to RAW:

```
$ curl -O http://cloud-images.ubuntu.com/releases/precise/release/ubuntu-12.04-server-cloudimg-amd64-disk1.img
$ qemu-img convert -O raw ubuntu-12.04-server-cloudimg-amd64-disk1.img ubuntu-12.04-server-cloudimg-amd64-disk1.raw
$ glance image-create --name='Ubuntu 12.04 x86_64' --is-public=True --container-format=bare --disk-format=raw --file ubuntu-12.04-server-cloudimg-amd64-disk1.raw
```

Apache httpd site configurations were switched to use the site model rather
than place server vhost definitions in conf.d.  To update an existing cluster,
please run the following on each head node before running ``chef-client``:

```
# rm /etc/apache2/conf.d/openstack-dashboard.conf /etc/apache2/conf.d/zabbix-web.conf /etc/apache2/conf.d/graphite-web.conf /etc/apache2/conf.d/kibana-web.conf
```

#### 20130817

Due to a change in Vagrant 1.2.5+, the default bootstrap node cannot have its
IP end in .1 (ie, 10.0.100.1).  In the current Vagrant scripts, the automated
bootstrap node will be 10.0.100.3.  (The host machine stays at 10.0.100.2.)

The default Ceph version has been upgraded from Cuttlefish (0.61) to Dumpling
(0.67).

Follow rolling upgrade notes described in:
 http://ceph.com/docs/master/release-notes/#v0-67-dumpling

* Upgrade ceph-common on all nodes that will use the command line `ceph` utility.
* Upgrade all monitors (upgrade ceph package, restart ceph-mon daemons). This can happen one daemon or host at a time. Note that because cuttlefish and dumpling monitors can't talk to each other, all monitors should be upgraded in relatively short succession to minimize the risk that an a untimely failure will reduce availability.
* Upgrade all osds (upgrade ceph package, restart ceph-osd daemons). This can happen one daemon or host at a time.
* Upgrade radosgw (upgrade radosgw package, restart radosgw daemons).

In Dumpling, the ``client.bootstrap-osd`` cephx key has new capabilities (see
``ceph auth list``).  Cuttlefish required the following monitor capabilities:

```
mon 'allow command osd create ...; allow command osd crush set ...; allow command auth add * osd allow\\ * mon allow\\ rwx; allow command mon getmap' 
```

In Dumpling, it is now reduced to:
```
mon 'allow profile bootstrap-osd' 
```

BCPC now uses the standard Opscode Community ntp cookbook instead of rolling
our own ntp recipes.  Environments need to be updated from:

```
"bcpc": {
  ...
  "ntp_servers" : [ "0.pool.ntp.org", "1.pool.ntp.org", "2.pool.ntp.org", "3.pool.ntp.org" ],
  ...
}
```

to (at the outer level - akin to ``bcpc``, ``chef_client``, and ``ubuntu``):

```
"ntp": {
   "servers" : [ "0.pool.ntp.org", "1.pool.ntp.org", "2.pool.ntp.org", "3.pool.ntp.org" ]
},
```

#### 20130720
Kibana has been upgraded from version 2 to version 3.
First run `service stop kibana` on each headnode before running
chef-client with the updated recipe.
