###############################################################################
# calico
###############################################################################

# calico apt repository
default['bcpc']['calico']['repo']['url'] = 'http://ppa.launchpad.net/project-calico/calico-3.6/ubuntu'
default['bcpc']['calico']['repo']['key'] = 'calico/release.key'

# calicoctl
default['bcpc']['calico']['calicoctl']['remote']['file'] = 'calicoctl'
default['bcpc']['calico']['calicoctl']['remote']['source'] = "#{default['bcpc']['web_server']['url']}/calicoctl"
default['bcpc']['calico']['calicoctl']['remote']['checksum'] = 'b17659ca43f8812c6bea3fe30135c1d44857a756b13ed49c83895e74e2761359'
