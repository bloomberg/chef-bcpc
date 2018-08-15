###############################################################################
# calico/calicoctl
###############################################################################

default['bcpc']['calico']['repo']['enabled'] = true
default['bcpc']['calico']['repo']['url'] = 'http://ppa.launchpad.net/project-calico/calico-3.2/ubuntu'

default['bcpc']['calico']['remote']['file'] = 'calicoctl'
default['bcpc']['calico']['remote']['source'] = "#{default['bcpc']['file_server']['url']}/calicoctl"
default['bcpc']['calico']['remote']['checksum'] = 'b0045e3f235d42618c3f4f6ec3e58715980995e2fab2424b39787cd72986a11d'
