BCPC Cluster Bootstrap Overview
===============================

To install a BCPC cluster, a bootstrap node is required that has network
connectivity to the remaining woker nodes.  Once the bootstrap node is
available and has the [Chef](http://www.getchef.com/chef/) server installed,
Chef can provision the bootstrap node with the the
[Cobbler](http://www.cobblerd.org/) and a DHCP server.  Cobbler and the DHCP
server are used to PXE boot the remaining worker nodes with a valid image.
Once properly imaged, the worker nodes can be managed by the Chef Server.

If you have VirtualBox installed, you can use our included scripts to create
and provision a bootstrap node.  This bootstrap node is able to act as the
provisioning serer with minimal interaction.

If you have a bare metal installation and a bootstrape node readily available,
you can use `bootstrap_chef.sh` to bring a bare Ubuntu 12.04 image up as a
provisioning serer.

Once the bootstrap node is provisioned, the remaining worker nodes may be
brought up to be PXE-booted and managed by Chef to be either a head or worker
node - whatever you deem appropriate.

Finally, if you do not wish to use our scripts (we won't be offended), please
refer to the [manual instructions](#manual-setup-notes) at the end of this
document.

About hypervisor hosts
======================

BCPC has been successfully tested on the following hosts:

* Mac OS X 10.9.3
* Ubuntu 12.04 (Precise)

Currently, the scripts are undergoing a fair amount of churn.  Windows 7
support has been temporarily suspended until some work is done to properly
support Windows in a platform agnostic way.  In addition to VirtualBox you need
a working bash interpreter and rsync available in your PATH. More information
about using chef-bcpc on Windows is provided in [Using Windows as your
Hypervisor](https://github.com/bloomberg/chef-bcpc/blob/master/windows.md).

About proxies
=============

BCPC can be brought up behind a proxy. An example is given in
`proxy_setup.sh` in the chef-bcpc directory. To actually use a proxy
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

The initial bootstrap node image
================================

The bcpc-bootstrap VM node needs to start with an initial image.  BCPC uses
[Packer](http://packer.io) for building boxes to be used by VirtualBox.  You
will need `packer` available in your system PATH and details regarindg BCPC
usagse of packer may be found [here](images/README.md).

Kicking off the bootstrap process
=================================

To start off, create the VirtualBox VMs:

```bash
$ ./vbox_create.sh [chef-environment]
```

This will create four VMs:
- bcpc-bootstrap (cobbler and chef server)
- bcpc-vm1
- bcpc-vm2
- bcpc-vm3

The `[chef-environment]` variable is optional and will default to `Test-Laptop`
if unspecfied. This is useful if you need to create the bootstrap node with
non-default settings such as a a local APT mirror
(`node[:bcpc][:bootstrap][:mirror]`) or a local internet proxy
(`node[:bcpc][:bootstrap][:proxy]`).

Once the bcpc-bootstrap node is available, the bcpc-vm images will be able to
be configured and boot via PXE.  Once the initial bootstrap process is complete
and the bcpc-vm machines are
[enrolled in Cobbler](#registering-vms-for-pxe-boot), the bcpc-vm machines
should automatically begin installation upon bootup.

In our testing, VirtualBox guest SMP makes performance significantly worse, so
it is recommended that you keep one CPU per VM.  You may also find that 2GB is
not enough for a BCPC-Headnode and wish to tweak the amount of RAM given to
any head node VM.

Provisioning the bootstrap node
-------------------------------

By running `vbox_create.sh`, you should already have a running and provisioned
bcpc-bootstrap node.  If you would like to use an apt-mirror and/or proxy,

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


This is a good time to take a snapshot of your bootstrap node:

```
$ VBoxManage snapshot bcpc-bootstrap take chef-server-provisioned
```

Registering VMs for PXE boot
============================

Once you have provisioned the local Chef server, you will need to register the
bcpc-vm1, bcpc-vm2, and bcpc-vm3 VMs before they can boot.

You can register the remaining VMs like this :

```bash
$ ./enroll_cobbler.sh .cache/dev/ssh_config
```

If you have other VMs to register, you need to do it on the bootstrap node :

```bash
$ ssh -F .cache/dev/ssh_config bcpc-bootstrap
$ sudo cobbler system add --name=bcpc-vm10 --hostname=bcpc-vm10 --profile=bcpc_host --ip-address=10.0.100.20 --mac=AA:BB:CC:DD:EE:FF
$ sudo cobbler sync
```

Note that if you need to redo these registrations of manual nodes,
you'll need to first remove them before re-adding, so

```bash
$ ssh -F .cache/dev/ssh_config bcpc-bootstrap
$ sudo cobbler system remove --name=bcpc-vm1
$ #... modified add command ...
$ sudo cobbler sync
```

Imaging BCPC Nodes
==================

Once the BCPC bootstrap VM is created and the node VMs are registered in
Cobbler, you can boot up the other VMs now, for example :

```
$ VBoxManage startvm bcpc-vm1
$ VBoxManage startvm bcpc-vm2
$ VBoxManage startvm bcpc-vm3
```

This should kick off the PXE boot installation of the nodes.  If this
doesn't work, please check that the systems are accessible in cobbler:

```
root@bcpc-bootstrap:~# cobbler system list
   bcpc-vm1
   bcpc-vm2
   bcpc-vm3
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
http://10.0.100.3:4040 and follow:
Clients -> &lt;Host> -> Edit -> Admin (toggle true) -> Save Client
where &lt;Host> is something like bcpc-vm1.local.lan, then re-run the
bootstrap command. 

Note that a clue to the current name and password is on the right-hand side of that page 
and will likely still be the defaults if this is your first time
through. Also note that this will change your password in the
data bag.

If you get a "Tampered with cookie 500" error clear out your cookies
from your browser for 10.0.100.3

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

If you're using a proxy, then create ~ubuntu/.wgetrc something like this:

```
http_proxy = http://proxy.example.com:80
```

and then do this :

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
@@ -28,12 +28,27 @@
         "interface" : "eth0",
         "pxe_interface" : "eth1",
         "server" : "10.0.100.3",
+        "mirror" : "10.0.100.3",
         "dhcp_subnet" : "10.0.100.0",
         "dhcp_range" : "10.0.100.10 10.0.100.250"
       },
+      "repos": {
+        "ceph": "http://10.0.100.3/ceph-dumpling",
+        "ceph-extras": "http://10.0.100.3/ceph-extras",
+        "rabbitmq": "http://10.0.100.3/rabbitmq",
+        "mysql": "http://10.0.100.3/percona",
+        "openstack": "http://10.0.100.3/ubuntu-cloud",
+        "hwraid": "http://10.0.100.3/hwraid",
+        "fluentd": "http://10.0.100.3/fluentd"
+      },
       "ntp_servers" : [ "0.pool.ntp.org", "1.pool.ntp.org", "2.pool.ntp.org", "3.pool.ntp.org" ],
       "dns_servers" : [ "8.8.8.8", "8.8.4.4" ]
     },
+    "ubuntu": {
+      "archive_url": "http://10.0.100.3/ubuntu",
+      "security_url": "http://10.0.100.3/ubuntu",
+      "include_source_packages": false
+    },
     "chef_client": {
       "server_url": "http://10.0.100.3:4000",
       "cache_path": "/var/chef/cache",
```

When you change or add an environment file like this, you only need to rerun the 'knife environment' 
command and then chef-client once again. Scripting this adjustment is TODO. Rerunning the entire bootstrap_chef.sh 
script at this stage is not recommended.

Manual setup notes
==================

This records notes if you do not wish to use our included shell scripts to
provision the bootstrap nodes.

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

