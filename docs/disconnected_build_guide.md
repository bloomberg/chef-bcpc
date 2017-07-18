Disconnected build guide
===

It is possible to do a build of a BCPC cluster in a completely isolated environment, as long as you are able to provide the following:

* a DNS server (does not necessarily need to be able to resolve anything)
* an NTP server
* full apt mirrors of all required packages, using apt-mirror or aptly
* all source files used by `bootstrap/shared/shared_build_bins.sh`

This guide is tailored towards OS X, since that is what we customarily build on. Where possible, discussion of how to achieve the equivalent on L This guide also assumes that you want to build in complete isolation, like you will be taking a laptop on a flight without any Internet access. If you have any of these services available somewhere, you may of course use them.

Prerequisites
---
Kick off an initial build of the BCPC cluster so that the host-only interfaces `vboxnet0`, `vboxnet1`, and `vboxnet2` are set up with IP addresses (check `ifconfig` on OS X/Linux, or `ip addr show` on Linux). You can terminate the build as soon as the interfaces are set up and have IP addresses (though it will be helpful for testing purposes if you wait for the bootstrap VM to be stood up). This step is necessary because some programs (notably BIND9) cannot or will not bind to `0.0.0.0`, and so you must provide real IP addresses for them to bind to so that they can service requests from the VMs. Further details will be provided in the appropriate section.

On OS X, the application-based firewall can interfere with software installed from Homebrew. If you're trying to figure out why your mirror or DNS aren't accessible from inside a VM, it's probably why. Turning it off is the easiest solution, though it can be made to play nice with software installed from Homebrew with a little convincing. For these cases, the CLI equivalent `/usr/libexec/ApplicationFirewall/socketfilterfw` is a bit more powerful than the Security preference pane.

DNS server
---
On OS X, the easiest way to get DNS up and running is to use [OS X Server](https://itunes.apple.com/us/app/os-x-server/id883878097?mt=12) from the Mac App Store. If this does not appeal to you, `bind` from Homebrew will also get the job done.

Similarly on Linux, you will want to install BIND from the appropriate package (on Ubuntu, it is called `bind9` and the configuration lives in `/etc/bind`.)

To get BIND listening on every network interface, as well as rescanning once per minute for interface changes, add to `/etc/bind/named.conf.options`:

```
listen-on { any; };
interface-interval 1;
```

If you can do a `host blahblah 10.0.100.2` from inside the bootstrap VM and get an immediate failure response back, you're good. If the request times out, it's not working.

(Note: the jury is still out on whether independent DNS resolution is even required, since the only thing this DNS server is doing is allowing for immediate failures on lookups rather than timeouts. It may not be necessary.)

NTP server
---
On OS X, add the below lines to the ntp configuration (either `/etc/ntp.conf` or `/etc/ntp-restrict.conf`) to allow the server to pretend to be a stratum above 16 and serve requests from 10.0.0.0:
```
server 127.127.1.1
fudge 127.127.1.1 stratum 8
restrict 10.0.0.0 mask 255.0.0.0 nomodify notrap
```
Restart ntp with: `sudo kill $(pgrep ntpd)` 

On Mac, launchd will automatically restart the ntp process. 

For Linux the process is nearly identical; on a modern Ubuntu, install the `ntp` and `ntpdate` packages to install the ntp daemon and client utilities, then configure it as described above and restart the ntp daemon with: `sudo service ntp restart`.

Now execute a debug time synchronization from the bootstrap VM with `ntpdate -d 10.0.100.2` 

If everything is working, you should see a message similar to `adjust time server 10.0.100.2 offset -0.000032 sec` after a few seconds. If things are not working correctly, you will see `no server suitable for synchronization found`.


apt mirror
---
A sample apt-mirror configuration is provided [here](https://github.com/bloomberg/chef-bcpc/blob/master/docs/example_apt_mirror_config.list), annotated with comments indicating what each repo is named in the BCPC configuration. Mirroring everything here will require a very large amount of disk space (currently about 188GB), so be sure you have enough local or attached disk space on hand.

You will need to have a web server like Apache or nginx installed on the host to serve up the mirrored content root. The easiest way to set up the content root is to symlink the root of each individual repository (the location with the `dists` and `pool` directories) into a single location, then serve that up, like so:

```
➜  mirror-root  ls -l
total 80
lrwxr-xr-x  1 user  staff  66 Jun 21 01:07 ceph -> /var/apt-mirror/mirror/www.ceph.com/debian-hammer/
lrwxr-xr-x  1 user  staff  91 May 28 10:18 elasticsearch -> /var/spool/apt-mirror/mirror/packages.elasticsearch.org/elasticsearch/1.5/debian/
lrwxr-xr-x  1 user  staff  76 May 28 10:16 erlang -> /var/spool/apt-mirror/mirror/packages.erlang-solutions.com/ubuntu/
lrwxr-xr-x  1 user  staff  74 May 28 10:17 fluentd -> /var/spool/apt-mirror/mirror/packages.treasure-data.com/2/
lrwxr-xr-x  1 user  staff  84 May 28 10:07 haproxy -> /var/spool/apt-mirror/mirror/ppa.launchpad.net/vbernat/haproxy-1.5/ubuntu/
lrwxr-xr-x  1 user  staff  60 May 28 10:17 mysql -> /var/spool/apt-mirror/mirror/repo.percona.com/apt/
lrwxr-xr-x  1 user  staff  81 May 28 10:17 openstack -> /var/spool/apt-mirror/mirror/ubuntu-cloud.archive.canonical.com/ubuntu/
lrwxr-xr-x  1 user  staff  63 May 28 10:08 rabbitmq -> /var/spool/apt-mirror/mirror/www.rabbitmq.com/debian/
lrwxr-xr-x  1 user  staff  61 Jun  3 09:07 ubuntu -> /var/spool/apt-mirror/mirror/mirror.pnl.gov/ubuntu/
```

...and then serve this location up from your web server.

You will need to configure the Chef environment appropriately to use all these repositories; see [the sample JSON](https://github.com/bloomberg/chef-bcpc/blob/master/environments/repository_template.json) for JSON you can modify and insert into your environment.

build_bins source files
---
You will also need all of the files downloaded by `bootstrap/shared/shared_prereqs.sh` in your local cache. By default, these files are downloaded to `$HOME/.bcpc-cache` on your system, which can be overridden by setting the `BOOTSTRAP_CACHE_DIR` environment variable. These are used by the `bootstrap/shared/shared_build_bins.sh` script, which is invoked inside the bootstrap VM to build various binary packages. The source location can be set via the `FILES_ROOT` environment variable, and the destination for the build products can be set with the `BUILD_DEST` environment variable. The build products must go into the `cookbooks/bcpc/files/default/bins` directory and be uploaded to the Chef server using the `knife` command and upload workflow.