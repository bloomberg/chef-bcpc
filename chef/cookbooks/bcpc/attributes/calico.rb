###############################################################################
# calico
###############################################################################

# calico apt repository
default['bcpc']['calico']['repo']['url'] =
 'http://ppa.launchpad.net/project-calico/calico-3.14/ubuntu'
default['bcpc']['calico']['repo']['key'] = 'calico/release.key'

# calicoctl
default['bcpc']['calico']['calicoctl']['remote']['file'] = 'calicoctl'
default['bcpc']['calico']['calicoctl']['remote']['source'] =
 "#{default['bcpc']['web_server']['url']}/calicoctl"
default['bcpc']['calico']['calicoctl']['remote']['checksum'] =
 '4e38c7e81653faf3659b0afddabde4dff736bb1b4cc59ebe238907a9641816a7'
