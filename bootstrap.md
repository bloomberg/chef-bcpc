BCPC Cluster Bootstrap Overview
===============================

This repository contains a set of scripts that is useful to bootstrap a BCPC
cluster with a Cobbler, Chef, DHCP, and gateway server.  Once the
bcpc-bootstrap node is created, all of the other nodes (such as bcpc-vm1,
bcpc-vm2, bcpc-vm3, etc.) can be PXE-booted with a valid image and then
chef-ified with minimal effort.

If you have Vagrant and VirtualBox installed, you can use our included
Vagrantfile and an Ubuntu 12.04 box file to provision a bootstrap node that is
able to act as the provisioning server with minimal interaction.

If you do not wish to use Vagrant or have a bare metal installation and wish to
do a manual install of the bootstrap node, you can use our bootstrap_chef.sh
scripts to bring a bare Ubuntu 12.04 image up as a provisioning server.

Once the bootstrap node is provisioned, then you can PXE-boot the other virtual
machines and enroll them in the cluster as head and worker nodes as you deem
appropriate.

Finally, if you do not wish to use our scripts (we won't be offended), please
refer to the [manual instructions](#manual-setup-notes) at the end of this
document.

About proxies
=============

BCPC can be brought up behind a proxy. An example is given in
proxy_setup.sh in the chef-bcpc directory. To actually use a proxy
uncomment and edit the example lines. The example uses a proxy on the
hypervisor (for example your workstation or laptop) just to keep the
explanation self-contained and simple. The hypervisor is always IP
address 10.0.100.2 from the point of view of the VMs. Your proxy may
well be elsewhere on your network. If you use the hostname, instead of
the IP address of a proxy, you may need to adjust the DNS settings in
./environments/Test-Laptop.json - the default is to use Google's free
DNS servers 8.8.8.8 and 8.8.4.4 but those nameservers will not resolve
a hostname within a private network.

The default proxy setup does not configure a proxy, but it still must
define 'CURL' which is used in the subsequent scripts. The default is
CURL=curl.

If you do configure a proxy at the start of the process, there are a
couple of additional manual steps later in the process. Proxy support
in BCPC is, currently, even more of a work-in-progress than the rest
of the project.

Note also that the proxy settings are only known to work with the 
non-Vagrant method of bringing up the VMs. 

Kicking off the bootstrap process
=================================

To start off, create the VirtualBox images:

```
$ ./vbox_create.sh
```

This will create four VMs:
- bcpc-bootstrap (cobbler and chef server)
- bcpc-vm1
- bcpc-vm2
- bcpc-vm3

If you have vagrant installed, the ``vbox_create.sh`` script will automatically
begin the provisioning of the bcpc-bootstrap node.  This may take 30-45 minutes
to complete successfully.  See below for [notes around the Vagrant
installation](#bcpc-bootstrap-creation-with-vagrant).  Otherwise, you can
provision the bcpc-bootstrap node through included shell scripts - see below
for
[installation notes without Vagrant](#bcpc-bootstrap-creation-without-vagrant).

Once the bcpc-bootstrap node is available, the bcpc-vm images will be able to
be configured and boot via PXE.  Once the initial bootstrap process is complete
and the bcpc-vm machines are
[enrolled in Cobbler](#registering-vms-for-pxe-boot), the bcpc-vm machines
should automatically begin installation upon bootup.

In our testing, VirtualBox guest SMP makes performance significantly worse, so
it is recommended that you keep one CPU per VM.  You may also find that 2GB is
not enough for a BCPC-Headnode and wish to tweak the amount of RAM given to
any head node VM.

bcpc-bootstrap creation with Vagrant
====================================

If vagrant is locally installed, we utilize the
[vagrant box images from Canonical](http://cloud-images.ubuntu.com/vagrant/)
to provision the bcpc-bootstrap node.

If you have a [local repository mirror](#setting-up-a-private-repos-mirror),
you can alter the Vagrantfile to use it when provisioning:

```
$local_mirror = "10.0.100.4"
```

You can log in to your bcpc-bootstrap node from the hypervisor via:

```
$ vagrant ssh
```

After the automatic provisioning is complete, this is a good time to take a
snapshot of your bootstrap node:

```
$ VBoxManage snapshot bcpc-bootstrap take initial-install
```

Please continue to
[Registering VMs for PXE boot](#registering-vms-for-pxe-boot).

bcpc-bootstrap creation without Vagrant
=======================================

If you do not have Vagrant installed, the ``vbox_create.sh`` script will create
the appropriate VMs.  You will then need to bring up the bcpc-bootstrap VM -
which has a virtual CD attached to kick off the Ubuntu install:

```
$ VBoxManage startvm bcpc-bootstrap
```

Manual install notes:

- select eth0 as network interface for DHCP (vbox_create.sh sets it up as NAT)
- bcpc-bootstrap as hostname
- If using a proxy, enter it when prompted, else leave blank
- ubuntu/ubuntu as default user/password
- install OpenSSH server
- install grub to MBR

Login to new VM.

If using NAT, port 22 inbound may be blocked; so, set up the other interfaces
on the hostonlyif ifaces (eth1-3).  Edit /etc/network/interfaces on
bcpc-bootstrap (for example using pico) :

```
$ sudo pico /etc/network/interfaces
```

add the following to the end

```
# Static interfaces
auto eth1
iface eth1 inet static
  address 10.0.100.1
  netmask 255.255.255.0

auto eth2
iface eth2 inet static
  address 172.16.100.1
  netmask 255.255.255.0

auto eth3
iface eth3 inet static
  address 192.168.100.1
  netmask 255.255.255.0
```

After changing the interfaces file:

```
$ sudo service networking restart
```

This is a good time to take a snapshot of your bootstrap node:

```
$ VBoxManage snapshot bcpc-bootstrap take initial-install
```

Provisioning chef-server without Vagrant
----------------------------------------

I *think* you have to fix up the preseed file
(cookbooks/bcpc/templates/default/cobbler.bcpc_ubuntu_host.preseed.erb)
here if using a proxy (for now explained in diff format) :
```
 d-i     mirror/country string manual
 d-i     mirror/http/hostname string <%= @node[:bcpc][:bootstrap][:mirror] %>
 d-i     mirror/http/directory string /ubuntu
-d-i     mirror/http/proxy string
 d-i     apt-setup/security_host <%= @node[:bcpc][:bootstrap][:mirror] %>
 d-i     apt-setup/security_path string /ubuntu
 <% end %>
 
+d-i     mirror/http/proxy string http://10.0.100.2:3128
+
 d-i     debian-installer/allow_unauthenticated  string false
 d-i     pkgsel/upgrade  select safe-upgrade
 d-i     pkgsel/language-packs   multiselect
```

Once you can SSH in to the bcpc-bootstrap node (ssh ubuntu@10.0.100.1 if
following instructions above), you can then run the bootstrap_chef.sh script
from the hypervisor running VirtualBox:

```
$ ./bootstrap_chef.sh ubuntu 10.0.100.1
```

This will bring up the chef-server on http://10.0.100.1:4040.
The Web UI will be at http://10.0.100.1:4000 with defaults admin/p@ssw0rd1

At this point, your bcpc-bootstrap node should be appropriately provisioned.

This is a good time to take a snapshot of your bootstrap node:

```
$ VBoxManage snapshot bcpc-bootstrap take chef-server-provisioned
```

If you see Host key verification failed when testing the ssh connection, you 
have probably recreated the VMs but not updated the SSH key. If this is the 
case you need to manually remove the old key - remove the entry for 
10.0.100.1 from ~/.ssh/known_hosts

Registering VMs for PXE boot
============================

Once you have provisioned the local Chef server (via Vagrant or
bootstrap_chef.sh), you will need to register the bcpc-vm1, bcpc-vm2, and
bcpc-vm3 VMs before they can boot. 

When using vagrant you can register the remaining VMs like this :

```
$ ./enroll_cobbler.sh
```

whereas for the non-Vagrant case you'll have to provide the IP address
of the bootstrap node (we are using 10.0.100.1 in this example) :

```
$ ./enroll_cobbler.sh 10.0.100.1
```

If you have other VMs to register, you need to do it on the bootstrap node :

```
$ ssh ubuntu@10.0.100.1
$ sudo cobbler system add --name=bcpc-vm10 --hostname=bcpc-vm10 --profile=bcpc_host --ip-address=10.0.100.20 --mac=AA:BB:CC:DD:EE:FF
$ sudo cobbler resync
```

Note that if you need to redo these registrations of manual nodes,
you'll need to first remove them before re-adding, so

```
$ ssh ubuntu@10.0.100.1
$ sudo cobbler system remove --name=bcpc-vm1
$ ... modified add command ...
$ sudo cobbler resync
```

You can boot up the other VMs now, for example :

```
$ VBoxManage startvm bcpc-vm1
$ VBoxManage startvm bcpc-vm2
$ VBoxManage startvm bcpc-vm3
```


User account on VM
==================

Upon PXE boot imaging, the bcpc-vm boxes will be imaged with the auto-generated
password for the ubuntu user.  From the bootstrap node, you can retrieve the
password as:

```
ubuntu@bcpc-bootstrap:~/chef-bcpc$ knife data bag show configs Test-Laptop
cobbler-root-password:         abcdefgh
...
ubuntu@bcpc-bootstrap:~/chef-bcpc$ ssh ubuntu@10.0.100.11 uname -a
ubuntu@10.0.100.11's password: <type in abcdefgh>
Linux bcpc-vm1 3.2.0-41-generic #66-Ubuntu SMP Thu Apr 25 03:27:11 UTC 2013 x86_64 x86_64 x86_64 GNU/Linux
```

Assigning roles to VM
=====================

If using a proxy, the bcpc-vm VMs will need some initial configuration
for wget before they can be 'knife bootstrap'ed. To do this, setup a
.wgetrc in the ubuntu home dir on each bcpc-vm to look like this
(using the example of a proxy on the hypervisor) :

http_proxy = http://10.0.100.2:3128/

At this point, from the bootstrap node you can then run:
```
ubuntu@bcpc-bootstrap:~/chef-bcpc$ sudo knife bootstrap -E Test-Laptop -r 'role[BCPC-Headnode]' 10.0.100.11 -x ubuntu --sudo
ubuntu@bcpc-bootstrap:~/chef-bcpc$ sudo knife bootstrap -E Test-Laptop -r 'role[BCPC-Worknode]' 10.0.100.12 -x ubuntu --sudo
ubuntu@bcpc-bootstrap:~/chef-bcpc$ sudo knife bootstrap -E Test-Laptop -r 'role[BCPC-Worknode]' 10.0.100.13 -x ubuntu --sudo
```

Also, after the first run, make the BCPC-Headnode an administrator, or you will get the error:
'''
[...]error: Net::HTTPServerException: 403 "Forbidden"
'''
To make a host an administrator, one can access the Chef web UI via
http://10.0.100.1:4040 and follow:
Clients -> &lt;Host> -> Edit -> Admin (toggle true) -> Save Client
where &lt;Host> is something like bcpc-vm1.local.lan, then re-run the
bootstrap command. 

Note that a clue to the current name and password is on the right-hand side of that page 
and will likely still be the defaults if this is your first time
through. Also note that this will change your password in the
data bag.

If you get a "Tampered with cookie 500" error clear out your cookies
from your browser for 10.0.100.1

Boostrapping these nodes will take quite a long time - as much as an
hour or more. You can monitor progress by logging into the VMs and
using tools such as 'top' or 'ps'.

Using BCPC
==========

If the VIP is configured against 10.0.100.5 (this is the default for the
Test-Laptop environment), then you can go to ``https://10.0.100.5/horizon/`` to
go to the OpenStack interface.  To find the OpenStack credentials, look in the
data bag for your environment under ``keystone-admin-user`` and
``keystone-admin-password``:

```
ubuntu@bcpc-bootstrap:~/chef-bcpc$ knife data bag show configs Test-Laptop | grep keystone-admin
keystone-admin-password:       abcdefgh
keystone-admin-token:          this-is-my-token
keystone-admin-user:           admin

```

To check on ``Ceph``:

```
ubuntu@bcpc-vm1:~$ ceph -s
   health HEALTH_OK
   monmap e1: 1 mons at {bcpc-vm1=172.16.100.11:6789/0}, election epoch 2, quorum 0 bcpc-vm1
   osdmap e94: 12 osds: 12 up, 12 in
    pgmap v705: 2192 pgs: 2192 active+clean; 80333 KB data, 729 MB used, 227 GB / 227 GB avail
   mdsmap e4: 1/1/1 up {0=bcpc-vm1=up:active}
```

Setting up a private repos mirror
=================================

If you do a lot of installations or are on an isolated network, you may wish to
utilize a private mirror.  Currently, this will require about 100GB of local
storage.

```
ubuntu@bcpc-bootstrap:~$ knife node run_list add \`hostname -f\` 'recipe[bcpc::apache-mirror]'
ubuntu@bcpc-bootstrap:~$ knife node run_list add \`hostname -f\` 'recipe[bcpc::apt-mirror]'
ubuntu@bcpc-bootstrap:~$ sudo chef-client
ubuntu@bcpc-bootstrap:~$ sudo apt-mirror /etc/apt/mirror.list
```

After successfully downloading the repository mirrors, you will then need to
edit the local environment - the following patch highlights the necessary
settings:

```
diff --git a/environments/Test-Laptop.json b/environments/Test-Laptop.json
index d844783..9a9e53a 100644
--- a/environments/Test-Laptop.json
+++ b/environments/Test-Laptop.json
@@ -28,12 +28,25 @@
         "interface" : "eth0",
         "pxe_interface" : "eth1",
         "server" : "10.0.100.1",
+        "mirror" : "10.0.100.1",
         "dhcp_subnet" : "10.0.100.0",
         "dhcp_range" : "10.0.100.10 10.0.100.250"
       },
+      "repos": {
+        "ceph": "http://10.0.100.1/ceph-bobtail",
+        "rabbitmq": "http://10.0.100.1/rabbitmq",
+        "mysql": "http://10.0.100.1/percona",
+        "openstack": "http://10.0.100.1/ubuntu-cloud",
+        "hwraid": "http://10.0.100.1/hwraid"
+      },
       "ntp_servers" : [ "0.pool.ntp.org", "1.pool.ntp.org", "2.pool.ntp.org", "3.pool.ntp.org" ],
       "dns_servers" : [ "8.8.8.8", "8.8.4.4" ]
     },
+    "ubuntu": {
+      "archive_url": "http://10.0.100.1/ubuntu",
+      "security_url": "http://10.0.100.1/ubuntu",
+      "include_source_packages": false
+    },
     "chef_client": {
       "server_url": "http://10.0.100.1:4000",
       "cache_path": "/var/chef/cache",
```

Manual setup notes
==================

This records notes if you do not wish to use Vagrant or our included shell
scripts to provision the bootstrap nodes.

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

