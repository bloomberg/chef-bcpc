cluster tools

chef-bcpc now includes some sample tools for helping install to real
hardware. 

Cluster definition file : cluster.txt

  Defines your hardware (see the sample file provided for an
  example). You can use vm-to-cluster.sh on the hypervisor to make a
  cluster.txt from your running VMs after booting.

  The expected fields are :

  hostname mac-address IP-address ILO-IP-Address domain role

  "ILO" stands for Integrated Lights-Out - a management console on,
  for example, HP servers. It's not important for VMs.

Cluster helper scripts

  The following cluster-*.sh scripts use simple wrappers for ssh and
  scp called "nodessh.sh" and "nodescp" which look up the node
  passwords from the knife data bags for your environment. See the
  'ssh, scp wrappers' section at the end of this file for more
  information on this.

cluster-enroll-cobbler.sh

  Using cluster.txt, this tool enrolls or removes nodes from cobbler. 

cluster-assign-roles.sh

  Using cluster.txt, this tool assigns roles to node using Chef.

cluster-whatsup.sh

  Finds out which nodes are responding on the network. Install fping
  to make this fast.

cluster-check.sh

  Checks nodes list in cluster.txt for being up, having default routes
  on the storage and management networks and running well-known
  services. Pass a role to limit the checks to machines in that
  role. Useful after bringing up a cluster to verify the basic health
  of all nodes.

cluster-vip.sh

  Using your environment file, this tool finds the current VIP
  (virtual IP) on your cluster so you can connect to its services or
  log onto that physical node for maintenance or troubleshooting.

cluster-rechef.sh

  After changing recipes and/or environment files and reloading them
  to the chef server, use this script to instruct all work and head
  nodes to rerun chef-client to pull those updates over to update
  themselves.

ssh, scp wrappers

  The cluster tools rely on the standard tools 'sshpass' and (in many
  cases) 'fping' both of which you should be able to install using
  apt-get. The cluster tools also use nodessh.sh and
  nodescp. nodessh.sh is a simple ssh wrapper that automates looking
  up the encrypted passwords for your environment from the knife data
  bags and then passes it through using sshpass reducing the number of
  times you must supply the sudo passwd. nodescp is a symlink to
  nodessh.sh which is used similarly to scp but leverages the same ssh
  wrapping. 

  examples :

#
# take a look at syslog on VM1
#
ubuntu@bcpc-bootstrap:~/chef-bcpc$ ./nodessh.sh Test-Laptop 10.0.100.11 "cat /var/log/syslog"
[...]
Jul 30 08:37:36 bcpc-vm1 dhclient: DHCPDISCOVER on eth0 to 255.255.255.255 port 67 interval 3
Jul 30 08:37:36 bcpc-vm1 dhclient: DHCPREQUEST of 10.0.100.11 on eth0 to 255.255.255.255 port 67
Jul 30 08:37:36 bcpc-vm1 dhclient: DHCPOFFER of 10.0.100.11 from 10.0.100.1
Jul 30 08:37:36 bcpc-vm1 dhclient: DHCPACK of 10.0.100.11 from 10.0.100.1
Jul 30 08:37:36 bcpc-vm1 dhclient: bound to 10.0.100.11 -- renewal in 8219 seconds.
Jul 30 08:37:36 bcpc-vm1 kernel: [   20.072953] init: failsafe main process (743) killed by TERM signal
Jul 30 08:37:37 bcpc-vm1 kernel: [   20.923986] hrtimer: interrupt took 4165076 ns
Jul 30 08:37:37 bcpc-vm1 cron[919]: (CRON) INFO (pidfile fd = 3)
Jul 30 08:37:37 bcpc-vm1 cron[924]: (CRON) STARTUP (fork ok)
Jul 30 08:37:37 bcpc-vm1 cron[924]: (CRON) INFO (Running @reboot jobs)
Jul 30 12:37:48 bcpc-vm1 kernel: [   30.104054] eth0: no IPv6 routers present
Jul 30 12:38:58 bcpc-vm1 ntpdate[852]: name server cannot be used: Temporary failure in name resolution (-3)
Jul 30 13:17:01 bcpc-vm1 CRON[1001]: (root) CMD (   cd / && run-parts --report /etc/cron.hourly)
ubuntu@bcpc-bootstrap:~/chef-bcpc$ 

#
# perform a privileged operation  
#
ubuntu@bcpc-bootstrap:~/chef-bcpc$ ./nodessh.sh Test-Laptop 10.0.100.11 "service ufw restart" sudo
[sudo] password for ubuntu: ufw stop/waiting
ufw start/running
ubuntu@bcpc-bootstrap:~/chef-bcpc$ 

#
# log in interactively
#
$ ./nodessh.sh Test-Laptop 10.0.100.11 -
ubuntu@bcpc-bootstrap:~/chef-bcpc$ ./nodessh.sh Test-Laptop 10.0.100.11 -
Welcome to Ubuntu 12.04.2 LTS (GNU/Linux 3.2.0-51-generic x86_64)

 * Documentation:  https://help.ubuntu.com/
Last login: Tue Jul 30 13:49:55 2013 from 10.0.100.1
ubuntu@bcpc-vm1:~$ uptime
 14:11:30 up  1:34,  1 user,  load average: 0.00, 0.01, 0.05
ubuntu@bcpc-vm1:~$ exit
logout
ubuntu@bcpc-bootstrap:~/chef-bcpc$ 

#
# use of nodescp
#
ubuntu@bcpc-bootstrap:~/chef-bcpc$ echo test > somefile.txt
ubuntu@bcpc-bootstrap:~/chef-bcpc$ ./nodescp Test-Laptop 10.0.100.11 somefile.txt ubuntu@10.0.100.11:/home/ubuntu
ubuntu@bcpc-bootstrap:~/chef-bcpc$ ./nodessh.sh Test-Laptop 10.0.100.11 'more somefile.txt'
test
ubuntu@bcpc-bootstrap:~/chef-bcpc$ 
